
script = {}

--[[
     thread metatable
--]]

local thread_mt = {}
thread_mt.__index = thread_mt

--[[
     SCRIPT _ENV metatable
     (script-side API)
--]]

-- env metatable needs to be seperate from index table to prevent accessing it via __index
local env_mt = {}
local api = {}
env_mt.__index = api

local current = queue.getActive

function api.threadName()
	return current().name
end

function api.run(tbl, ...)
	if type(tbl) ~= "table" then
		return api.run{tbl, ...}
	end
	
	local pid = children.run(table.unpack(tbl))
	queue.waitPid(pid)
	return current().pidExitStatus
end	

api.print = print

--[[
     script metatable
--]]

local script_mt = {}
script_mt.__index = script_mt

function script_mt:makeThread(func, name)
	local thread = setmetatable({
		script = self,
		name = name,
		func = func
	}, thread_mt)
	
	return thread
end

--[[
     supervisor-side API
--]]

function script.makeScript()
	local context = setmetatable({
		env = script.makeEnv()
	}, script_mt)
	return context
end

function script.makeEnv()
	local env = setmetatable({}, env_mt)
	return env
end
