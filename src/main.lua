
--[[
     S E T T I N G S
--]]

local args = { select(2, ... ) } -- trim off argv[0]

local mode = "spawn"
-- spawn = run as client, but spawn server process to talk to
-- server = run as server, managing daemon-supervising coroutines
-- client = run as client, sending command to server

local socketPath
-- path of client/server connection socket

-- parse arguments

if args[1] == "--server" then
	mode = "server"
end

--[[
     S O C K E T   C H E C K
--]]

-- try --socket if given, failing if given but invalid
-- else try SEMA_SOCKET
-- else try $HOME/.sema/control.socket

if not socketPath then
	--error("No control socket path available; try setting either $SEMA_SOCKET or $HOME.")
end

--[[
     K I C K O F F
--]]

-- fork if need be
if mode == "spawn" then
	
	if socket.grabClientSocket() then
		mode = "client"
		print(socket.grabClientSocket() .. "=sock")
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

