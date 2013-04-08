
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

-- script _ENV metatable
-- needs to be seperate from index table (defined in api.lua) to prevent accessing it via __index
local env_mt = {}
env_mt.__index = api

function script.makeEnv()
	local env = setmetatable({}, env_mt)
	return env
end
