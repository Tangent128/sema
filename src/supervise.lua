
supervise = {}

function supervise.main()
	print "start server"
	
	local signalFd = init.makeSignalFd();
	poll.addFd(signalFd, "signal")
	
	--queue debug thread
	
	--loop forever
	while true do
		local fds = poll.doPoll()
		for k, v in ipairs(fds) do
			print(v.fd, v.type, v.signal)
		end
	end
end

