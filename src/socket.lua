
-- defined below
local close

-- metatable to allow garbage-collecting file descriptors
local fd_mt = {
	__gc = function(wrapper)
		close(wrapper.fd)
		--print("GC: closed "..wrapper.fd)
	end
}

local function wrapFd(fd)
	return setmetatable({fd = fd}, fd_mt)
end

-- Functions to establish sockets

local socketPath = nil
function socket.getSocketPath()
	if socketPath then
		return socketPath
	end

	--TODO: base default off $HOME? or?
	-- $HOME/.sema/control.socket ?
	--error("No control socket path available; try setting either $SEMA_SOCKET or $HOME.")
	socketPath = os.getenv("SEMA_SOCKET") or "./sema.socket"
	
	socketPath = aux.absPath(socketPath)

	return socketPath
end

local clientFd = nil
function socket.grabClientSocket()

	if clientFd then
		return clientFd
	end

	clientFd = wrapFd(socket.cGrabClientSocket(socket.getSocketPath()))

	if clientFd then
		poll.addFd(clientFd.fd, "read")
		socket.buffers[clientFd.fd] = ""
	end

	return clientFd
end

local serverFd = nil
function socket.grabServerSocket()

	if serverFd then
		return serverFd
	end

	serverFd = wrapFd(socket.cGrabServerSocket(socket.getSocketPath()))

	if serverFd then
		poll.addFd(serverFd.fd, "read")
		socket.buffers[serverFd.fd] = ""
		aux.addExitHook(socket.serverShutdown)
	end

	return serverFd
end

--incompletely-received data
socket.buffers = {}

--to only be run from a blockable coroutine!
function socket.accept(wrappedServerFd)
	local serverFd = wrappedServerFd.fd
	queue.fdBlocked:waitOn(serverFd)
	
	-- get connection fd
	local clientFd = socket.cAccept(serverFd)
	
	-- prepare to receive data from it
	poll.addFd(clientFd, "read")
	socket.buffers[clientFd] = ""
	
	return wrapFd(clientFd)
end

function close(fd)
--	if type(fd) == "table" then
--		fd, fd.fd = fd.fd, nil
--	end
	poll.dropFd(fd)
	socket.buffers[fd] = nil
	socket.cClose(fd)
end

-- message = list of strings, {"like", "this", "..."}
--[[ format for message encoding :
     (lengths are unsigned 32-bit
              big-endian integers)
     =============================
     content                #bytes
     -------                 -----
     "sema"                      4
     version byte (0x00)         1
     payload length              4
     <end of 9-byte header>
     first string length         4
     first string             ????
     second string length        4
     second string            ????
     ...
     last string length          4
     last string              ????
--]]
function socket.sendMessage(wrappedFd, message)
	local fd = wrappedFd.fd
	--format message body
	local body = ""
	for i=1,#message do
		local arg = tostring(message[i])
		body = body .. socket.formatNetworkInt(#arg) .. arg
	end
	
	--format message header
	local header = "sema\x00" .. socket.formatNetworkInt(#body)
	socket.cWrite(fd, header .. body);
end

local function readBlock(fd)
	queue.fdBlocked:waitOn(fd)

	local block = socket.cRead(fd)
	
	if #block == 0 then
		error "Connection closed before whole message received."
	end
	
	return block
end

--to only be run from a blockable coroutine!
--assumption: only one coroutine is reading at a time
--- (later fix: "buffer" -> "buffers[fd]" w/ bookkeeping in accept/close?
---  & then extract appropriate chunks)
function socket.receiveMessage(wrappedFd)
	local fd = wrappedFd.fd
	
	local buffers = socket.buffers
	local readBytes = #buffers[fd]
	
	--read message header
	while readBytes < 9 do
		local block = readBlock(fd)
		buffers[fd] = buffers[fd] .. block
		readBytes = readBytes + #block
	end
	
	if buffers[fd]:sub(1,5) ~= "sema\x00" then
		error "Message was not a sema packet."
	end
	
	local messageLength = socket.readNetworkInt(buffers[fd]:sub(6,9))
	
	--discard header and read message body
	buffers[fd] = buffers[fd]:sub(10)
	readBytes = #buffers[fd]
	
	while readBytes < messageLength do
		local block = readBlock(fd)
		buffers[fd] = buffers[fd] .. block
		readBytes = readBytes + #block
	end
	
	--split out the current message while keeping any spare data in the buffer
	local messageBytes = buffers[fd]:sub(1,messageLength)
	buffers[fd] = buffers[fd]:sub(messageLength + 1)
	
	--parse message body
	local message = {}
	
	while #messageBytes >= 4 do
		local argLength = socket.readNetworkInt(messageBytes:sub(1,4))
		message[#message + 1] = messageBytes:sub(5, 4 + argLength)
		messageBytes = messageBytes:sub(5 + argLength)
	end
	
	return message
end

-- prevent client from deleting a socket it created when spawning a server
function socket.detachServer()
	serverFd = nil --triggers GC
end

-- on exit, clean up socket
function socket.serverShutdown()
	if serverFd then
		socket.cUnlink(socket.getSocketPath())
	end
end

