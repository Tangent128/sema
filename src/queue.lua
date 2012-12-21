
queue = {}

--[[
     Threads that can run
--]]

local activeSet = {}

local function activate(thread)
	activeSet[thread] = thread
end
local function deactivate(thread)
	activeSet[thread] = nil
end

function queue.enqueue(func)
	local thread
	thread = coroutine.create(function()
		func()
		-- cleanup
		deactivate(thread)
	end)
	activate(thread)
end

function queue.runActive()
	for thread in pairs(activeSet) do
		local ok, err = coroutine.resume(thread)
		if not ok then
			print(err)
		end
	end
end


--[[
     Threads blocked on child processes
--]]

local pidBlocked = {}

-- assumption: only one thread can wait on a given PID
function queue.waitPid(pid)
	local thread = coroutine.running()
	pidBlocked[pid] = thread
	deactivate(thread)
	coroutine.yield()
end

function queue.resumePid(pid)
	local thread = pidBlocked[pid]
	if thread then
		pidBlocked[pid] = nil
		activate(thread)
	end
end

