
supervise = {}

local scriptMap = {}

local COMMAND_THREAD = {}
local function grabScript(name)

	if scriptMap[name] then
		return scriptMap[name]
	end
	
	local newScript = script.makeScript()
	scriptMap[name] = newScript
	
	local func, err = loadfile(name, "bt", newScript.env)
	
	local mainThread
	if func then
		mainThread = newScript:makeThread(function()
			local ok, err = pcall(func)
			print("main done "..name)
			
			--TODO: killall threads in script
			scriptMap[name] = nil
			
			if not ok then error(err) end
		end, name)
	else
		error(err)
	end
	
	-- main thread determines script ready status
	newScript.main = mainThread
	
	queue.enqueue(mainThread)
	
	return newScript
end

function supervise.main()
	print "start server"
	
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
	local function connectionHandler(fd)
			
		local activeThread = queue.getActive()
		
		local message = socket.receiveMessage(fd)
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
		local commandName = message[2]
		
		local activeScript = grabScript(scriptName)
		
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
		
		command( select(3, unpack(message)) )
		
		activeThread.reply {"OK", "Done."}
		
	end
	
	local function acceptLoop()
		print "server awaiting connections"
		while true do
			local accepted = socket.accept(serverFd)
			--print("accepted fd "..accepted)
			
			-- create thread to handle this connection
			queue.enqueue(supervisor:makeThread(function()
			
				local ok, err = pcall(connectionHandler, accepted)
				
				socket.close(accepted)
				--print("closed fd "..accepted)
				if not ok then error(err) end
				
			end, "fd "..accepted))
		end
	end
	queue.enqueue(supervisor:makeThread(acceptLoop, "accept()"))

	queue.eventLoopMain()
	
	print "done"	

	aux.shutdown()
end

