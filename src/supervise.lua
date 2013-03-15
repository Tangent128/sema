
supervise = {}

function supervise.main()
	print "start server"
	
	local serverFd = socket.grabServerSocket()
	
	local signalFd = signal.makeSignalFd();
	poll.addFd(signalFd, "signal")
	poll.addFd(serverFd, "read")
	
	--queue debug threads
	local function test(name, period)
		local script = script.makeScript()
		local _ENV = script.env
		return script:makeThread(function()
			local n = 0
			while true do
				n = n + 1
				run{"echo", threadName()..n}
				local status = run{"sleep", period}
				print("exit status", status)
			end
		end, name)
	end
	queue.enqueue(test("A", 3))
	queue.enqueue(test("B", 5))

	--TODO: write & enqueue worker thread that listens to socket & handles messages
	local accepter = script.makeScript()
	queue.enqueue(accepter:makeThread(function()
		print "server awaiting connections"
		while true do
			--TODO: proper thread creation, not blocking the accept while reading commands
			local accepted = socket.accept(serverFd)
			print("accepted fd "..accepted)
			socket.receiveMessage(accepted)
			socket.close(accepted)
			print("closed fd "..accepted)
		end
	end, "accept()"))

	queue.eventLoopMain()
	
	print "done"	

end

