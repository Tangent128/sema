
function socket.getSocketPath()
	return "./sema.socket"
	--return os.getenv("HOME")..
end

local clientFd = nil
function socket.grabClientSocket()
	if clientFd then
		return clientFd
	end
	clientFd = socket.cGrabClientSocket(socket.getSocketPath())
	return clientFd
end

local serverFd = nil
function socket.grabServerSocket()
	if serverFd then
		return serverFd
	end
	serverFd = socket.cGrabServerSocket(socket.getSocketPath())
	return serverFd
end

