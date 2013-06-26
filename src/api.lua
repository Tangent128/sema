
api = {}

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

-- get name of current thread
function api.scriptName()
	return current().script.name
end

-- send a message back to the client that spawned this command
-- (only works from a command handler)
function api.reply(...)
	local reply = current().reply
	if reply then
		reply{"STATUS", ...}
	else
		error("reply() has to be called from a command handler")
	end
end

-- spawn a thread in parallel
function api.parallel(func)
	local thread = current().script:makeThread(func)
	queue.enqueue(thread)
	return {id = thread.id}
end


--[[
	Process-control functions
--]]

-- spawn a child process and wait for exit
function api.run(tbl, ...)
	-- normalize arguments
	if type(tbl) ~= "table" then
		return api.run{tbl, ...}
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
	
	-- fd mapping is handled Lua-side for simplification
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
function api.runIfUp(...)
	-- insure we are not down
	api.waitEvent "up"
	
	-- pass through
	return api.run(...)
end


-- signal a child process
function api.signal(threadID, signum)

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

-- splice in signal constants
for name, num in pairs(signal) do
	if type(name) == "string" and name:sub(1,3) == "SIG" then
		api[name] = num
	end
end

--[[
     Pipe functions
--]]

function api.pipe()
	local inFd, outFd = socket.pipe()
	
	--TODO: add write function to input proxy
	return {
		input = proxyFd(inFd),
		output = proxyFd(outFd),
	}
end

--[[
     Event functions
--]]

function api.waitEvent(name)
	current().script.events:waitOn(name)
end

function api.triggerEvent(name)
	current().script.events:resumeOn(name)
end

function api.setEvent(name, on)
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

do 
	local _ENV = api
	
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
api.DEBUG = _G


