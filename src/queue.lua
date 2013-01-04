
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

function queue.enqueue(thread)
	local co
	co = thread.coroutine or coroutine.create(function()
		thread.func()
		-- cleanup
		deactivate(co)
	end)
	thread.coroutine = co
	activate(thread)
end

-- assumption: the thread dispatch loop is non-reentrant
local activeThread
function queue.runActive()
	for thread in pairs(activeSet) do
		activeThread = thread
		local ok, err = coroutine.resume(thread.coroutine)
		if not ok then
			print(err)
		end
	end
end

function queue.getActive()
	return activeThread
end

--[[
     Threads blocked on child processes
--]]

local pidBlocked = {}

-- assumption: only one thread can wait on a given PID
function queue.waitPid(pid)
	--activeThread declared above
	pidBlocked[pid] = activeThread
	deactivate(activeThread)
	coroutine.yield()
end

function queue.resumePid(pid)
	local thread = pidBlocked[pid]
	if thread then
		pidBlocked[pid] = nil
		activate(thread)
	end
end

