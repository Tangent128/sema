
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
	
		-- resume threads waiting on child processes to finish
		for pid, status in pairs(events.children) do
			queue.resumePid(pid, status)
		end
		
		-- resume threads waiting on an fd to be safely readable
		for fd in pairs(events.fds) do
			queue.resumeFd(fd)
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
	if thread.script then
		thread.script.threads[thread] = nil
	end
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

--TODO: generic wait queue w/ waitOn(event) & resume-with-callback methods?
--[[
     Threads blocked on another thread being "ready"
--]]



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

--[[
     Threads blocked on file descriptor reads
--]]

local fdBlocked = {}

-- assumption: only one thread can wait on a given fd
function queue.waitFd(fd)
	--activeThread declared above
	fdBlocked[fd] = activeThread
	deactivate(activeThread)
	coroutine.yield()
end

-- assumption: a thread only waits on one fd at a time
function queue.resumeFd(fd)
	local thread = fdBlocked[fd]
	if thread then
		fdBlocked[fd] = nil
		activate(thread)
	end
end

