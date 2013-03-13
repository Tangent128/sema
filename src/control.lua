
control = {}

function control.main()
	print "start client"
	
	local clientFd = socket.grabClientSocket()
	
	print(socket.readNetworkInt("\0\0\0\x10"));
	print(socket.readNetworkInt("\x40\x41\x42\x43"));
	print(socket.formatNetworkInt(1078018627))
	
	
	if not clientFd then
		print "Could not connect to server."
		exit.shutdown()
	end
	
	--TODO: write test packet to server
	
	print "done client"
end

