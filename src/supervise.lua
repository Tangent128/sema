
supervise = {}

function supervise.main()
	print "start server"
	
	local signalFd = signal.makeSignalFd();
	poll.addFd(signalFd, "signal")
	
	--queue debug thread
	local falsePid = children.run("false")
	children.run("sleep", "1")
	children.run("sleep", "3")
	local fivePid = children.run("sleep", "5")
	
	--loop forever
	while true do
		local events = poll.events()
		
	--	if events.signals[signal.SIG???] then
	--	end
		
		for pid, status in pairs(events.children) do
			if pid == falsePid then
				print("false exited")
			elseif pid == fivePid then
				print("sleep 5 exited")
			else
				print("reap", pid, status)
			end
		end
		
	end
end

