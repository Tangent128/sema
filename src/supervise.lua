
supervise = {}

function supervise.main()
	print "start server"
	
	local signalFd = signal.makeSignalFd();
	poll.addFd(signalFd, "signal")
	
	--queue debug thread
	
	--loop forever
	while true do
		local events = poll.events()
		
		if events.signals[signal.SIGCHLD] then
			print "reap"
		end
		
	end
end

