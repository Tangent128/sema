
script = {}

local threadId = 0
local function nextId()
	threadId = threadId + 1
	return threadId
end

--[[
     thread metatable
--]]

local thread_mt = {}
thread_mt.__index = thread_mt
--thread_mt.__gc = function() print "reap thread" end --for debugging proper GC
function thread_mt:kill()
	queue.kill(self)
end

--[[
     script metatable
--]]

local script_mt = {}
script_mt.__index = script_mt
--script_mt.__gc = function() print "reap script" end --for debugging proper GC

function script_mt:makeThread(func)
	local thread = setmetatable({
		script = self,
		func = func,
		id = nextId(),
		ready = nil,
		waitSet = nil,
		waitKey = nil,
	}, thread_mt)
	
	self:adoptThread(thread)
	
	return thread
end

-- move a thread to a different script's context for proper bookkeeping/killing
function script_mt:adoptThread(thread)
	
	local oldScript = thread.script
	if oldScript then
		oldScript.threads[thread.id] = nil
	end
	
	thread.script = self
	self.threads[thread.id] = thread
	
end

-- end all threads belonging to a script
function script_mt:killAll()
	for id, thread in pairs(self.threads) do
		thread:kill()
	end
end

--[[
     supervisor-side API
--]]

function script.makeScript(name)
	local context = setmetatable({
		env = script.makeEnv(),
		events = queue.newWaitSet(),
		name = name,
		threads = {},
		fds = setmetatable({}, aux.weak_k_mt),
		main = nil, --set in supervise.lua, grabScript()
	}, script_mt)
	return context
end

-- script _ENV metatable
-- needs to be separate from index table (defined in api.lua) to prevent accessing it via __index
local env_mt = {}
env_mt.__index = api -- see api.lua

local command_mt = {}
command_mt.__index = api.command -- see api.lua

function script.makeEnv()
	local env = setmetatable({
	}, env_mt)
	env.command = setmetatable({}, command_mt)
	return env
end

