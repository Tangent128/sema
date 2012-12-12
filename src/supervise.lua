
supervise = {}

function supervise.main()
	print "start server"
	--print (pollSet.addFd(3, "signal"))
	
	local signalFd = init.makeSignalFd();
	pollSet.addFd(signalFd, "signal")
	
	--queue debug thread
	
	--loop forever
	while true do
		local fds = pollSet.doPoll()
		for k, v in ipairs(fds) do
			print(v.fd, v.type, v.signal)
		end
	end
end

