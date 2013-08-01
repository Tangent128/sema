
-- defined below
local close

-- metatable to allow garbage-collecting file descriptors
local fd_mt = {
	__index = {
		close = function(wrapper)
			close(wrapper.fd)
			wrapper.fd = nil
			--print("Manually closed "..wrapper.fd)
		end
	},
	__gc = function(wrapper)
		close(wrapper.fd)
		--print("GC: closed "..wrapper.fd)
	end
}

local function wrapFd(fd)
	
	-- propagate nil
	if fd == nil then return nil end
	
	return setmetatable({fd = fd}, fd_mt)
end

-- Functions to establish sockets

-- helper to consult an environment variable
local function tryVar(name, suffix)
	local value = os.getenv(name)
	if value then
		return value .. (suffix or "")
	else
		return nil
	end
end

-- decide where we want our socket
local socketPath = nil
function socket.getSocketPath()
	if socketPath then
		return socketPath
	end

	if aux.getUID() == 0 then
		socketPath = tryVar("SEMA_SOCKET")
		or "/run/sema.socket"
	else
		socketPath = tryVar("SEMA_SOCKET")
		or tryVar("XDG_RUNTIME_DIR", "/sema.socket")
		or tryVar("HOME", "/.sema.socket")
		or error("No control socket path available; try setting either $SEMA_SOCKET, $XDG_RUNTIME_DIR, or $HOME.")
	end

	socketPath = aux.absPath(socketPath)
	
	return socketPath
end

-- connect to server if possible,
-- nil means stale socket or no socket, with a second return giving the error
local clientFd = nil
function socket.grabClientSocket()

	if clientFd then
		return clientFd
	end

	local fdNum, err = socket.cGrabClientSocket(socket.getSocketPath())

	clientFd = wrapFd(fdNum)

	if clientFd then
		poll.addFd(clientFd.fd, "read")
		socket.buffers[clientFd.fd] = ""
	end

	return clientFd, err
end

local serverFd = nil
function socket.grabServerSocketSimple()

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
function socket.grabServerSocket()

	local ok, serverFd = pcall(socket.grabServerSocketSimple)
	
	if ok then
		return serverFd
	end
	
	-- check for stale socket or in-use socket
	local clientSocket, err = socket.grabClientSocket()
	
	if clientSocket then
		error "Socket already in use."
	end
	
	if err == "ECONNREFUSED" then
		--grabClientSocket() would hopefully have cleared out the stale socket
		return socket.grabServerSocketSimple()
	end
	
	-- unknown error, propagate initial error
	error(serverFd)
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

-- close function, works for both sockets and pipes
function close(fd)
	if fd then
		poll.dropFd(fd)
		socket.buffers[fd] = nil
		socket.cClose(fd)
	end
end

-- message = list of strings, {"like", "this", "..."}
--[[ format for message encoding :
     (lengths are unsigned 32-bit
              big-endian integers)
     =============================
     content                #bytes
     -------                 -----
     ASCII/UTF-8 "sema"          4
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
	socket.cWrite(fd, header .. body)
end

function socket.write(fd, data)
	socket.cWrite(fd.fd, data)
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
--[[assumption: only one coroutine is reading a given socket at a time,
otherwise concurrency issues can happen (ex, what happens if two
threads see the same header and so deduce the same message length,
and one of them then removes the message from the buffer?)
right choice is probably to refactor this logic onto a per-fd reading
coroutine that receiveMessage() resumes, but the coordination needs design]]
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
	
	-- packet length = 9-byte header + payload
	local packetLength = 9 + socket.readNetworkInt(buffers[fd]:sub(6,9))
	
	-- read message body too
	while readBytes < packetLength do
		local block = readBlock(fd)
		buffers[fd] = buffers[fd] .. block
		readBytes = readBytes + #block
	end
	
	-- discard header and split out the current message,
	-- while keeping any spare data in the buffer
	local messageBytes = buffers[fd]:sub(10,packetLength)
	buffers[fd] = buffers[fd]:sub(packetLength + 1)
	
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
	serverFd = nil --no leak, will trigger GC eventually
end

-- on exit, clean up socket
function socket.serverShutdown()
	if serverFd then
		socket.cUnlink(socket.getSocketPath())
	end
end

-- Functions to make/write-to pipes

function socket.pipe()
	local readFd, writeFd = socket.cPipe()
	
	-- does not register polling on fds, as we don't currently read from them
	return wrapFd(readFd), wrapFd(writeFd)
end


