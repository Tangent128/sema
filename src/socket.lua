
local socketPath = nil
function socket.getSocketPath()
	if socketPath then
		return socketPath
	end

	--TODO: base default off $HOME? or?
	-- $HOME/.sema/control.socket ?
	--error("No control socket path available; try setting either $SEMA_SOCKET or $HOME.")
	socketPath = os.getenv("SEMA_SOCKET") or "./sema.socket"
	
	local dir, name = socketPath:match("^(.-/?)([^/]-)$")
	
	if #dir == 0 then
		--TODO: may want to use some default directory
		-- in these cases besides cwd?
		dir = "./"
	end
		
	-- normalize directory, including a trailing slash
	-- (but leave "/" as-is, not "//")
	dir = socket.cAbsPath(dir):gsub("^(.-)/?$", "%1/")
	
	socketPath = dir .. name
	return socketPath
end

local clientFd = nil
function socket.grabClientSocket()

	if clientFd then
		return clientFd
	end

	clientFd = socket.cGrabClientSocket(socket.getSocketPath())

	if clientFd then
		poll.addFd(clientFd, "read")
	end

	return clientFd
end

local serverFd = nil
function socket.grabServerSocket()

	if serverFd then
		return serverFd
	end

	serverFd = socket.cGrabServerSocket(socket.getSocketPath())

	if serverFd then
		poll.addFd(serverFd, "read")
		aux.addExitHook(socket.serverShutdown)
	end

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
function socket.sendMessage(fd, message)
	--format message body
	local body = ""
	for i=1,#message do
		local arg = message[i]
		body = body .. socket.formatNetworkInt(#arg) .. arg
	end
	
	--format message header
	local header = "sema\x00" .. socket.formatNetworkInt(#body)
	socket.cWrite(fd, header .. body);
end

local function readBlock(fd)
	queue.waitFd(fd)
	
	local block = socket.cRead(fd)
	
	if #block == 0 then
		error "Connection closed before whole message sent."
	end
	
	return block
end

--to only be run from a blockable coroutine!
--assumption: only one message is sent each way on a connection
--- (later fix: "buffer" -> "buffers[fd]" w/ bookkeeping in accept/close?
---  & then extract appropriate chunks)
function socket.receiveMessage(fd)
	local readBytes = 0
	local buffer = ""
	
	--read message header
	while readBytes < 9 do
		local block = readBlock(fd)
		buffer = buffer .. block
		readBytes = readBytes + #block
	end
	
	if buffer:sub(1,5) ~= "sema\x00" then
		error "Message was not a sema packet."
	end
	
	local messageLength = socket.readNetworkInt(buffer:sub(6,9))
	
	--discard header and read message body
	buffer = buffer:sub(10)
	readBytes = #buffer
	
	while readBytes < messageLength do
		local block = readBlock(fd)
		buffer = buffer .. block
		readBytes = readBytes + #block
	end
	
	--security/sanity
	buffer = buffer:sub(1,messageLength)
	
	--parse message body
	local message = {}
	
	while #buffer >= 4 do
		local argLength = socket.readNetworkInt(buffer:sub(1,4))
		message[#message + 1] = buffer:sub(5, 4 + argLength)
		buffer = buffer:sub(5 + argLength)
	end
	
	return message
end


function socket.serverShutdown()
	if serverFd then
		socket.cUnlink(socket.getSocketPath())
	end
end

