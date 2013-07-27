
supervise = {}

local scriptMap = {}
local connectionSet = setmetatable({}, aux.weak_k_mt)

local function checkAutoquit()
	-- exit supervisor if spawned and script + connection count dropped to zero
	if autoSpawned
	and not next(scriptMap)
	and not next(connectionSet)
	then
		--print("autoquiting", autoSpawned, next(scriptMap), next(connectionSet))
		aux.shutdown()
	else
		--print("not autoquiting", autoSpawned, next(scriptMap), next(connectionSet))
	end
end

local COMMAND_THREAD = {}
local function grabScript(name, startDown)

	if scriptMap[name] then
		return scriptMap[name]
	end
	
	local newScript = script.makeScript(name)
	
	local func, err = loadfile(name, "bt", newScript.env)

	local mainThread
	if func then
		
		-- remember script
		scriptMap[name] = newScript
		
		mainThread = newScript:makeThread(function()
			
			-- insure service is up
			if not startDown then
				newScript.events:resumeOnAndClear("up")
			end
		
			-- run script chunk
			local ok, err = pcall(func)
			
			mainThread:kill()
			
			if not ok then error(err) end
		end, name)
		
		-- make kill of main thread do cleanup
		-- TODO eventually: "liveThreads" counter on script,
		-- when at zero, call script's kill function, which will be set here
		local baseKill = mainThread.kill
		function mainThread:kill()
			-- default behavior
			-- runs first to ensure killAll() below does not infinite-recurse into this
			baseKill(self)
			
			-- killall remaining threads in script
			newScript:killAll()
			
			-- cleanup script
			scriptMap[name] = nil
			
			checkAutoquit()
			
		end
		
	else
		error(err)
	end
	
	-- main thread determines script ready status
	newScript.main = mainThread
	
	queue.enqueue(mainThread)
	
	return newScript
end

function supervise.main()
	do 
		--print "start server"
	end
	
	local serverFd = socket.grabServerSocket()
	
	-- "script" representing core duties
	local supervisor = script.makeScript()
	
	--[[
	     Supervisor control protocol:
	     ============================
	     Client sends command message of form
	     {scriptName, commandName, args...}
	     
	     (special status/debug/global commands use empty string
	      for scriptName, else path to file)
	      
	     Server replies with message of one of following forms:
	     {"STATUS", informationMessage}
	     {"OK", informationMessage} (ends connection)
	     {"ERROR", explanationMessage} (ends connection)
	--]]
	local doScriptCommand, doSemaCommand
	local function connectionHandler(fd)
			
		local activeThread = queue.getActive()
		
		local message = socket.receiveMessage(fd)
		
		-- setup function to route command results back to client
		activeThread.reply = function(msg)
			local ok, err = pcall(socket.sendMessage, fd, msg)
			
			if not ok then
				print(tostring(err) .. " (fd#" .. fd.fd .. ")")
			end
		end
		
		if #message < 2 then
			activeThread.reply {
				"ERROR",
				"Command message should at least feature \z
				 a script path and command name"
			}
			return
		end
		
		local scriptName = message[1]
		
		if scriptName == "\0" then
			-- null scriptName, call special command handler
			-- handle stuff like killall script, quit server, etc
			doSemaCommand(activeThread, select(2, unpack(message)))
		else
			doScriptCommand(activeThread, unpack(message))
		end
		
	end
	
	-- handle command to be passed to a script
	function doScriptCommand(activeThread, scriptName, commandName, ...)
	
		local activeScript = grabScript(scriptName, commandName == "down")
		
		activeScript:adoptThread(activeThread)
		
		-- wait on script having run long enough to define commands
		queue.threadBlocked:waitOn(activeScript.main)

		-- look up command
		local command = activeScript.env.command and activeScript.env.command[commandName]
		
		if not command then
			activeThread.reply {
				"ERROR",
				"Command handler "..commandName.." undefined for script "..scriptName.." .",
				tostring(command)
			}
			return
		end
		
		command(...)
		
		activeThread.reply {"OK", "Done."}
	end
	
	-- handle global-state command
	function doSemaCommand(activeThread, commandName, ...)
		
		if commandName == "ls" then
			-- print running scripts
			for name, script in pairs(scriptMap) do
				activeThread.reply {"SCRIPT", name}
				
				-- print child procs
				for id, thread in pairs(script.threads) do
					if thread.waitSet == queue.pidBlocked then
						--TODO: scrounge up more information
						activeThread.reply {"PID", thread.waitKey}
					end
				end
			end
			
		elseif commandName == "killScript" then
			
			local scriptName = ...
			local script = scriptMap[scriptName]
			
			if script then
				script:killAll()
				activeThread.reply {"KILLED", scriptName}
			end
		end
		
		activeThread.reply {"OK", "Done."}
		
	end
	
	-- top-level loop for processing client connections
	local function acceptLoop()
		print "server awaiting connections"
		while true do
			local accepted = socket.accept(serverFd)
			
			connectionSet[accepted] = true
			
			-- create thread to handle this connection
			queue.enqueue(supervisor:makeThread(function()
			
				local ok, err = pcall(connectionHandler, accepted)
				connectionSet[accepted] = nil
				
				if err then
					socket.sendMessage(accepted, {
						"ERROR",
						tostring(err)
					})
				end
				
				checkAutoquit()
				
				if err then
					--TODO: sanify error handling/logging so that this error won't be missed on autoclose?
					-- pass error up chain for server-side reporting too
					error(err)
				end
				
				--"accepted" socket will be GC'd
				--print("done with fd "..accepted.fd)
				
			end))
		end
	end
	queue.enqueue(supervisor:makeThread(acceptLoop))

	queue.eventLoopMain()
	
	print "done"

	aux.shutdown()
end

