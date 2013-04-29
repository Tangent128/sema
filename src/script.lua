
script = {}

--[[
     thread metatable
--]]

local thread_mt = {}
thread_mt.__index = thread_mt

--[[
     script metatable
--]]

local script_mt = {}
script_mt.__index = script_mt

function script_mt:makeThread(func, name)
	local thread = setmetatable({
		script = self,
		name = name,
		func = func,
		ready = nil
	}, thread_mt)
	
	self:adoptThread(thread)
	
	return thread
end

-- move a thread to a different script's context for proper bookkeeping/killing
function script_mt:adoptThread(thread)
	
	local oldScript = thread.script
	if oldScript then
		oldScript.threads[thread] = nil
	end
	
	thread.script = self
	self.threads[thread] = thread
	
end

--[[
     supervisor-side API
--]]

function script.makeScript()
	local context = setmetatable({
		env = script.makeEnv(),
		events = queue.newWaitSet(),
		threads = {},
	}, script_mt)
	return context
end

-- script _ENV metatable
-- needs to be seperate from index table (defined in api.lua) to prevent accessing it via __index
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

