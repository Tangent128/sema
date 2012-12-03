
local args = { select(2, ... ) } -- trim off argv[0]

local mode = "spawn"
-- spawn = run as client, but spawn server process to talk to
-- server = run as server, managing daemon-supervising coroutines
-- client = run as client, sending command to server

-- parse arguments

if args[1] == "--server" then
	mode = "server"
end


-- fork if need be

if mode == "spawn" then
	mode = init.modeFork()
end

-- start appropriate code path

if mode == "client" then
	print "start client"
elseif mode == "server" then
	print "start server"
else
	error("Somehow got an invalid mode: "..mode)
end

