
api = {}

-- functions to expose as globals to scripts
api.export = {}
local API = api.export

--[[
	Script-side API functions
--]]

local current = queue.getActive

local function proxyFd(fd)
	local proxy = {}
	current().script.fds[proxy] = fd
	return proxy
end

local function unproxyFd(proxy)
	return current().script.fds[proxy]
end

--[[
	General functions
--]]

-- get name of current script
function API.scriptName()
	return current().script.name
end

-- send a message back to the client that spawned this command
-- (only works from a command handler)
function API.reply(...)
	local reply = current().reply
	if reply then
		reply{"STATUS", ...}
	else
		error("reply() has to be called from a command handler")
	end
end

-- spawn a thread in parallel
function API.parallel(func)
	local thread = current().script:makeThread(func)
	queue.enqueue(thread)
	return {id = thread.id}
end


--[[
	Process-control functions
--]]

-- spawn a child process and wait for exit
function API.run(tbl, ...)
	-- normalize arguments
	if type(tbl) ~= "table" then
		return API.run{tbl, ...}
	end
	
	-- normalize setuid/setgid
	local uid, name, gid = aux.userInfo(tbl.user)
	tbl.user = uid
	tbl.group = gid
	
	-- build fd map - starts numbering at zero for fd compatability!
	local fds = {[0] = 0,1,2}
	
	for fd, name in pairs{[0] = "stdin", "stdout", "stderr"} do
		if tbl[name] and unproxyFd(tbl[name]) then
			fds[fd] = unproxyFd(tbl[name]).fd
		end
	end
	
	-- normalize chdir path to script location, if relative
	--TODO: how to handle directory not changing if user-given path is bad?
	local _, scriptDir = aux.absPath(current().script.name)
	tbl.chdir = aux.resolvePath(scriptDir, tbl.chdir or "")
	
	
	-- fd mapping is handled Lua-side for simplification
	-- this is called post-fork, in the child
	tbl.fdMapper = function()
		local floor = #fds + 1 -- ensure we are out of range of fd table
		
		-- ensure relevant fds "out of the way"
		local i = 0
		while fds[i] ~= nil do
			if fds[i] ~= false then
				fds[i] = children.puntFd(fds[i], floor)
			end
			i = i + 1
		end
		
		-- place them
		i = 0
		while fds[i] ~= nil do
			if fds[i] == false then
				socket.cClose(i)
			else
				children.dupTo(fds[i], i)
			end
			i = i + 1
		end

	end
	
	-- run child process
	local pid = children.run(tbl)
	queue.pidBlocked:waitOn(pid)
	return current().pidExitStatus
end

-- run{}, but blocks if service is down
-- conciseness function
function API.runIfUp(...)
	-- insure we are not down
	API.waitEvent "up"
	
	-- pass through
	return API.run(...)
end

-- split a simple command line string for a run{} command
-- does nothing about quotes, envvars, etc, just splits on whitespace
function API.cmd(cmdline)
	local words = {}
	for word in cmdline:gmatch("[^%s]+") do
		words[#words + 1] = word
	end
	return table.unpack(words)
end

-- signal a child process
function API.signal(threadID, signum)

	-- get the intended ID
	local idType = type(threadID)
	if idType == "table" then
		threadID = threadID.id
	elseif idType == "nil" then
		-- nil means main thread
		threadID = current().script.main.id
	end
	
	-- get the thread object from the ID
	local thread = current().script.threads[threadID]
	
	-- signal if appropriate
	if thread and thread.waitSet == queue.pidBlocked then
		--TODO: if blocked on down, should run{} fake a kill by the given signal?
		local pid = thread.waitKey
		signal.sendSignal(pid, signum)
		print("signal", threadID, thread.waitKey, signum)
	end
end

-- export signal constants
for name, num in pairs(signal) do
	if type(name) == "string" and name:sub(1,3) == "SIG" then
		API[name] = num
	end
end

--[[
     Pipe functions
--]]

local write_mt = {}
write_mt.__index = write_mt

function write_mt:write(message)
	local fd = unproxyFd(self)
	socket.write(fd, message)
end
function write_mt:writeln(message)
	self:write(message .. "\n")
end

function API.pipe()
	local readFd, writeFd = socket.pipe()
	
	--TODO: add write function to input proxy
	return {
		output = proxyFd(readFd),
		input = setmetatable(proxyFd(writeFd), write_mt),
	}
end

--[[
     Event functions
--]]

function API.waitEvent(name)
	current().script.events:waitOn(name)
end

function API.triggerEvent(name)
	current().script.events:resumeOn(name)
end

function API.setEvent(name, on)
	if on == nil then on = true end
	
	if on then
		current().script.events:resumeOnAndClear(name)
	else
		current().script.events:unClear(name)
	end
end

--[[
     Default implementation for default commands
--]]

api.command = {}
local command = api.command

do 
	local _ENV = API
	
	function command.up()
		setEvent("up")
	end
	
	function command.down()
		setEvent("up", false)
		signal(nil, SIGTERM)
	end
	
	function command.status()
		reply {
			"OK",
			"Script loaded."
		}
	end
end

-- access to global environment for debug purposes
-- (not realistic security risk, as scripts can inherently spawn arbitrary processes)
API.DEBUG = _G


