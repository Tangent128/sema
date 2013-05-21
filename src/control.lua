
control = {}

function control.main(action, ...)
	print "start client"
	
	-- connect to server
	local clientFd = socket.grabClientSocket()
	
	if not clientFd then
		print "Could not connect to server."
		aux.shutdown()
	end
	
	-- prepare thread to issue command
	local client = script.makeScript()
	local args = {...}
	local actionFunc
	
	-- utility functions
	local function printReplies()
		local message = socket.receiveMessage(clientFd)
	
		--TODO: friendlier printing
		for i=1,#message do
			print("arg", #(message[i]), message[i])
		end
		
		if message[1] == "OK" or message[1] == "ERROR" then
			return
		end
		
		return printReplies()
	end
	
	local function checkScript(file)
		
		local path = aux.absPath(file)
		
		-- ensure file exists
		local handle, err = io.open(path)

		if handle then
			io.close(handle)
		else
			error(err)
		end
		
		return path
	end

	-- select command
	if action == "command" then
		actionFunc = function()
			
			args[1] = checkScript(args[1])
			args[2] = args[2] or "status"
			
			socket.sendMessage(clientFd, args)
			
			printReplies()
			
		end
	elseif action == "debug" then
		actionFunc = function()
			--socket.sendMessage(clientFd, {"dummy", "arg", })
			math.randomseed(os.time())
			local sel = math.random() * 2 + 1
			local dummyScript = ({"dummy", "placeholder"})[math.floor(sel)]
			print(sel,dummyScript)
			socket.sendMessage(clientFd, {dummyScript, "cmd", "1234567890asdfghjkl1234567890poiuytrewq"})

			local message = socket.receiveMessage(clientFd)

			for i=1,#message do
				print("arg", #(message[i]), message[i])
			end

		end
	elseif action == "ls" then
		actionFunc = function()
			socket.sendMessage(clientFd, {"\0", "ls"})
			printReplies()
		end
	elseif action == "killScript" then
		actionFunc = function()
			local scriptPath = checkScript(args[1])
			socket.sendMessage(clientFd, {"\0", "killScript", scriptPath})
			printReplies()
		end
	end
	
	-- execute
	queue.enqueue(client:makeThread(actionFunc, action))

	queue.eventLoopMain()

	aux.shutdown()
end

