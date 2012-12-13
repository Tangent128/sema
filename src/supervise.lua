
supervise = {}

function supervise.main()
	print "start server"
	
	local signalFd = signal.makeSignalFd();
	poll.addFd(signalFd, "signal")
	
	--queue debug thread
	
	--loop forever
	while true do
		local fds = poll.doPoll()
		for k, v in ipairs(fds) do
			print(v.fd, v.type, v.signal)
			
			if(v.type == "signal") then
				local sig = signal.readSignal(v.fd)
				print("Signal #" .. sig)
			end
		end
	end
end

