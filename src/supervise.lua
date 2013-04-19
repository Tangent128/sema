
supervise = {}

local scriptMap = {}

local COMMAND_THREAD = {}
local function grabScript(name)
	--TODO: realpath
	if scriptMap[name] then
		return scriptMap[name]
	end
	
	local newScript = script.makeScript()
	
	scriptMap[name] = newScript
	
	local dummyCount = 0
	newScript.env.command.cmd = function()
		local _ENV = newScript.env
		dummyCount = dummyCount + 1
		reply {
			"OK",
			"called "..name.." "..dummyCount.." times"
		}
	end
	
	return newScript
end

function supervise.main()
	print "start server"
	
	local serverFd = socket.grabServerSocket()
	
	-- "script" representing core duties
	local supervisor = script.makeScript()
	
	--[[queue debug threads
	local function debugSuperviseSleep(period)
		local _ENV = supervisor.env
		return function()
			local n = 0
			while true do
				n = n + 1
				run{"echo", threadName()..n}
				local status = run{"sleep", period}
				print("exit status", status)
			end
		end
	end
	local function test(name, period)
		return supervisor:makeThread(debugSuperviseSleep(period), name)
	end
	queue.enqueue(test("A", 3))
	queue.enqueue(test("B", 5))
	--]]
	
	--[[
	     Supervisor control protocol:
	     ============================
	     Client sends command message of form
	     {scriptName, commandName, args...}
	     
	     (special status/debug/global commands use empty string
	      for scriptName, else path to file)
	      
	     Server replies with message of one of following forms:
	     {"OK", informationMessage}
	     {"ERROR", explanationMessage}
	--]]
	local function connectionHandler(fd)
			
		local activeThread = queue.getActive()
		
		local message = socket.receiveMessage(fd)
		activeThread.reply = function(msg) socket.sendMessage(fd, msg) end
		
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
		
		local command = activeScript.env.command and activeScript.env.command[commandName]
		
		if not command then
			activeThread.reply {
				"ERROR",
				"Command handler "..commandName.." undefined for script "..scriptName.." .",
				tostring(command)
			}
		end
		
		command( select(3, unpack(message)) )
		
		activeThread.reply {"OK", "Done."}
		
	end
	
	local function acceptLoop()
		print "server awaiting connections"
		while true do
			local accepted = socket.accept(serverFd)
			print("accepted fd "..accepted)
			
			-- create thread to handle this connection
			queue.enqueue(supervisor:makeThread(function()
			
				local ok, err = pcall(connectionHandler, accepted)
				
				socket.close(accepted)
				print("closed fd "..accepted)
				if not ok then error(err) end
				
			end, "fd "..accepted))
		end
	end
	queue.enqueue(supervisor:makeThread(acceptLoop, "accept()"))

	queue.eventLoopMain()
	
	print "done"	

	aux.shutdown()
end

