
--wrap error handler

xpcall(function(...)

--[[
     S E T T I N G S
--]]

local args = { select(2, ... ) } -- trim off argv[0]

local mode = "spawn"
autoSpawned = false

-- spawn = run as client, but spawn server process to talk to if needed
-- server = run as server, managing daemon-supervising coroutines
-- client = run as client, sending command to server
-- help = print help

local action = "command"
-- command = send command to be executed by supervision script

-- parse arguments

local argStartIndex = 1
if args[1] and args[1]:match "^[-][-]" then
	argStartIndex = 2
	
	if args[1] == "--server" then
		mode = "server"
	elseif args[1] == "--client" and #args >= 2 then
		mode = "client"
		action = "command"
	elseif args[1] == "--ls" and #args == 1 then
		mode = "client"
		action = "ls"
	elseif args[1] == "--kill" and #args == 2 then
		mode = "client"
		action = "killScript"
	elseif args[1] == "--debug" then
		mode = "client"
		action = "debug"
	else
		mode = "help"
	end
	
elseif #args < 1 then
	mode = "help"
end


--[[
     K I C K O F F
--]]

-- last-minute initialization
local signalFd = signal.makeSignalFd();
poll.addFd(signalFd, "signal")

-- fork if need be
if mode == "spawn" then
	
	if socket.grabClientSocket() then
		-- server running, fork uneeded
		mode = "client"
	else
		-- need to fork to create server
		
		-- get server socket ready pre-fork to avoid 
		socket.grabServerSocket()
		
		local process
		mode, process = aux.modeFork()
		
		-- when the server is the child (normal case, unless PID == 1),
		-- allow it to autoquit when all scripts are quit
		if process == "child" then
			autoSpawned = true
		end
	end
end

-- start appropriate code path
if mode == "client" then
	socket.detachServer()
	control.main(action, select(argStartIndex, unpack(args)))
elseif mode == "server" then
	supervise.main()
else
	error("Somehow got an invalid mode: "..mode)
end

-- print stacktrace on toplevel error
end, function(err)
	print( debug.traceback(err, 2))
end, ...)

