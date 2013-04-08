
control = {}

function control.main()
	print "start client"
	
	local clientFd = socket.grabClientSocket()
	
	if not clientFd then
		print "Could not connect to server."
		exit.shutdown()
	end
	
	local reader = script.makeScript()
	queue.enqueue(reader:makeThread(function()
		socket.sendMessage(clientFd, {"dummy", "arg", "1234567890asdfghjkl1234567890poiuytrewq"})

		local message = socket.receiveMessage(clientFd)

	--	print(#message)

		for i=1,#message do
			print("arg", #(message[i]), message[i])
		end

	end, "read()"))

	queue.eventLoopMain()
	
	print "done client"
end

