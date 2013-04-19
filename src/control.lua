
control = {}

function control.main(...)
	print "start client"
	
	local clientFd = socket.grabClientSocket()
	
	if not clientFd then
		print "Could not connect to server."
		aux.shutdown()
	end
	
	local reader = script.makeScript()
	queue.enqueue(reader:makeThread(function()
		--socket.sendMessage(clientFd, {"dummy", "arg", "1234567890asdfghjkl1234567890poiuytrewq"})
		math.randomseed(os.time())
		local sel = math.random() * 2 + 1
		local dummyScript = ({"dummy", "placeholder"})[math.floor(sel)]
		print(sel,dummyScript)
		socket.sendMessage(clientFd, {dummyScript, "cmd"})

		local message = socket.receiveMessage(clientFd)

		for i=1,#message do
			print("arg", #(message[i]), message[i])
		end

	end, "read()"))

	queue.eventLoopMain()
	
	aux.shutdown()
end

