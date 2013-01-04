
supervise = {}

function supervise.main()
	print "start server"
	
	local signalFd = signal.makeSignalFd();
	poll.addFd(signalFd, "signal")
	
	--queue debug threads
	local function test(name, period)
		local x_ENV = script.makeEnv()
		return script.makeThread(function()
			local n = 0
			while true do
				n = n + 1
				local pid = children.run("echo", x_ENV.threadName()..n)
				queue.waitPid(pid)
				pid = children.run("sleep", period)
				queue.waitPid(pid)
			end
		end, name)
	end
	queue.enqueue(test("A", 3))
	queue.enqueue(test("B", 5))
	
	--loop forever
	while true do
	
		queue.runActive()
	
		local events = poll.events()
		
	--	if events.signals[signal.SIG???] then
	--	end
		
		for pid, status in pairs(events.children) do
			queue.resumePid(pid)
		end
		
	end
end

