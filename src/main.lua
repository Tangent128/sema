
--wrap error handler

xpcall(function(...)

--[[
     H E L P
--]]

local programName = (...) -- argv[0]
local function printHelp()
	local text = [=[
Lua-scripted centralized daemon supervisor. Usage:

$sema --server
	Launch a foreground server process, which will receive commands
	from future clients.

$sema --client scriptFile.sema [command [command args...]]
	Connect to the server and ensure a given script is running.
	Optionally send a command to the script.

$sema scriptFile.sema [command [command args...]]
	Like --client, but automatically spawn a background server if
	a server is not yet running.

$sema --ls
	List server's currently loaded scripts, and PIDs of any daemons.
	
$sema --kill scriptFile.sema
	Force-quit a script on the server and SIGKILL its daemons.

Default control socket location is based on current user,
$SEMA_SOCKET may be set to provide an explicit control socket to use.
]=]
	text = text:gsub("$sema", programName)
	print(text)
end

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
		print("Unknown command: " .. args[1])
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
elseif mode == "help" then
	printHelp()
else
	error("Somehow got an invalid mode: "..mode)
end

-- print stacktrace on toplevel error
end, function(err)
	print( debug.traceback(err, 2))
end, ...)

