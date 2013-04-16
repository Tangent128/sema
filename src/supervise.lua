
supervise = {}

function supervise.main()
	print "start server"
	
	local serverFd = socket.grabServerSocket()
	
	-- "script" representing core duties
	local supervisor = script.makeScript()
	
	--queue debug threads
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

	local function connectionHandler(fd)
		return function()
			local message = socket.receiveMessage(fd)
		
			for i=1,#message do
				print("arg", #(message[i]), message[i])
			end

		
			message[#message + 1] = "added echo"
			
			supervisor.env.run{"sleep", 3}
			
			socket.sendMessage(fd, message)
			socket.close(fd)
			print("closed fd "..fd)
		end
	end
	
	local function acceptLoop()
		print "server awaiting connections"
		while true do
			--TODO: proper thread creation, not blocking the accept while reading commands, remember that thread needs to close accepted socket even when an error condition happens
			local accepted = socket.accept(serverFd)
			print("accepted fd "..accepted)
			
			queue.enqueue(supervisor:makeThread(connectionHandler(accepted), "fd "..accepted))
		end
	end
	queue.enqueue(supervisor:makeThread(acceptLoop, "accept()"))

	queue.eventLoopMain()
	
	print "done"	

end

