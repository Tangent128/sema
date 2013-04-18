
supervise = {}

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

	local function connectionHandler(fd)
			
		local message = socket.receiveMessage(fd)
		
		for i=1,#message do
			print("arg", #(message[i]), message[i])
		end


		message[#message + 1] = "added echo"
	
		supervisor.env.run{"sleep", 3}
	
		socket.sendMessage(fd, message)
		
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

end

