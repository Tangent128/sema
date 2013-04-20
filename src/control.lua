
control = {}

function control.main(action, ...)
	print "start client"
	
	local clientFd = socket.grabClientSocket()
	
	if not clientFd then
		print "Could not connect to server."
		aux.shutdown()
	end
	
	local client = script.makeScript()
	local actionFunc
	
	if action == "command" then
		error "commands not implemented yet"
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
	end
	
	queue.enqueue(client:makeThread(actionFunc, action))

	queue.eventLoopMain()
	
	aux.shutdown()
end

