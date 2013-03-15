
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

--to only be run from a blockable coroutine!
function socket.accept(serverFd)
	queue.waitFd(serverFd)
	
	local clientFd = socket.cAccept(serverFd)
	poll.addFd(clientFd, "read")
	
	return clientFd
end

function socket.close(fd)
	poll.dropFd(fd)
	socket.cClose(fd)
end

--TODO: send/receive messages (message = list of strings)
function socket.sendMessage(fd, message)
	--format message body
	--format message header
	socket.cWrite(fd);
end

local function readBlock(fd)
	queue.waitFd(fd)
	
	--TODO: handle nothing to read
	return socket.cRead(fd)
end

--to only be run from a blockable coroutine!
function socket.receiveMessage(fd)
print(readBlock(fd))
	--read message header
	--read message body
	--parse message body
end


function socket.serverShutdown()
	if serverFd then
		socket.cUnlink(socket.getSocketPath())
	end
end

