
supervise = {}

local scriptMap = {}

local COMMAND_THREAD = {}
local function grabScript(name, startDown)

	if scriptMap[name] then
		return scriptMap[name]
	end
	
	local newScript = script.makeScript()
	
	local func, err = loadfile(name, "bt", newScript.env)

	local mainThread
	if func then
		
		-- remember script
		scriptMap[name] = newScript
		
		mainThread = newScript:makeThread(function()
			
			-- insure service is up
			if not startDown then
				api.setEvent("up")
			end
		
			-- run script chunk
			local ok, err = pcall(func)
			
			mainThread:kill()
			
			if not ok then error(err) end
		end, name)
		
		-- make kill of main thread do cleanup
		local baseKill = mainThread.kill
		function mainThread:kill()
			-- default behavior
			-- runs first to ensure killAll() below does not infinite-recurse into this
			baseKill(self)
			
			-- TODO: remove debug print once script ls is a thing
			print("main done "..name)
			
			-- killall remaining threads in script
			newScript:killAll()
			
			-- cleanup script
			scriptMap[name] = nil
			
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
		print "start server"
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
			pcall(socket.sendMessage, fd, msg)
			
			--TODO: report error, even if writing to broken socket harmless?
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
	
			for name, script in pairs(scriptMap) do
				activeThread.reply {"LS", name}
				
				-- TODO: print child procs
			end
			
		elseif commandName == "killScript" then
			-- killall
		end
		
		activeThread.reply {"OK", "Done."}
		
	end
	
	-- top-level loop for processing client connections
	local function acceptLoop()
		print "server awaiting connections"
		while true do
			local accepted = socket.accept(serverFd)
			
			-- create thread to handle this connection
			queue.enqueue(supervisor:makeThread(function()
			
				local ok, err = pcall(connectionHandler, accepted)
				
				if err then
					socket.sendMessage(accepted, {
						"ERROR",
						tostring(err)
					})
					
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

