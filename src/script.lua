
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

local env_mt = {}
local api = {}
env_mt.__index = api

function api.threadName()
	return queue.getActive().name
end

function api.run(tbl, ...)
	if type(tbl) ~= "table" then
		return api.run{tbl, ...}
	end
	
	local pid = children.run(table.unpack(tbl))
	queue.waitPid(pid)
end	

--[[
     supervisor-side API
--]]

function script.makeThread(func, name)
	local thread = setmetatable({
		name = name,
		func = func
	}, thread_mt)
	
	return thread
end

function script.makeEnv()
	local env = setmetatable({}, env_mt)
	return env
end
