
queue = {}

--[[
     does continual event processing until no threads left
--]]


function queue.eventLoopMain()
	
	queue.runActive()
	while queue.hasLiveThreads() do
	
		local events = poll.events(not queue.hasActiveThreads())
		
	--	if events.signals[signal.SIG???] then
	--	end
	
		for pid, status in pairs(events.children) do
			queue.resumePid(pid, status)
		end
		
		queue.runActive()
		
	end
end

--[[
     Threads that can run
--]]

local liveSet = {}
local activeSet = {}

local function activate(thread)
	activeSet[thread] = thread
end
local function deactivate(thread)
	activeSet[thread] = nil
end
local function kill(thread)
	activeSet[thread] = nil
	liveSet[thread] = nil
end

function queue.enqueue(thread)
	local co
	co = thread.coroutine or coroutine.create(function()
		thread.func()
		-- cleanup
		kill(thread)
	end)
	thread.coroutine = co
	liveSet[thread] = thread
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
			kill(thread)
		end
	end
end

function queue.hasLiveThreads()
	return next(liveSet) ~= nil
end

function queue.hasActiveThreads()
	return next(activeSet) ~= nil
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

-- assumption: a thread only waits on one PID at a time
function queue.resumePid(pid, status)
	local thread = pidBlocked[pid]
	if thread then
		pidBlocked[pid] = nil
		thread.pidExitStatus = status
		activate(thread)
	end
end



