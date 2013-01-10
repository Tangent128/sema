
supervise = {}

function supervise.main()
	print "start server"
	
	local signalFd = signal.makeSignalFd();
	poll.addFd(signalFd, "signal")
	
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

	queue.eventLoopMain()
	
	print "done"	

end

