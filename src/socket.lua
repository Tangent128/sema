
local socketPath = nil
function socket.getSocketPath()
	if socketPath then
		return socketPath
	end
	--os.getenv("HOME")..
	socketPath = "./sema.socket"
	return socketPath
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
	exit.addHook(socket.serverShutdown)
	return serverFd
end

--to only be run when the fd is readable to avoid process blocking!
function socket.accept(serverFd)
	--TODO: decide if queue.waitFd(serverFd) goes here or is caller's job
	return socket.cAccept(serverFd)
end

--TODO: send/receive messages (message = list of strings)

function socket.serverShutdown()
	if serverFd then
		--TODO: unlink fds
		socket.cUnlink(socket.getSocketPath())
	end
end

