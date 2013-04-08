
--[[
     S E T T I N G S
--]]

local args = { select(2, ... ) } -- trim off argv[0]

local mode = "spawn"
-- spawn = run as client, but spawn server process to talk to
-- server = run as server, managing daemon-supervising coroutines
-- client = run as client, sending command to server

-- parse arguments

if args[1] == "--server" then
	mode = "server"
elseif args[1] == "--client" then
	mode = "client"
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
		mode = "client"
	else
		-- get server socket ready
		socket.grabServerSocket()
		mode = init.modeFork()
	end
end

-- start appropriate code path

if mode == "client" then
	control.main()
elseif mode == "server" then
	supervise.main()
else
	error("Somehow got an invalid mode: "..mode)
end

