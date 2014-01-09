
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
			queue.pidBlocked:resumeOn(pid, status)
		end
		
		-- resume threads waiting on an fd to be safely readable
		for fd in pairs(events.fds) do
			queue.fdBlocked:resumeOn(fd)
		end
		
		queue.runActive()
		
	end
end

--[[
     Queue management
--]]

-- Threads that exist
local liveSet = {}

--Threads that can run
local activeSet = {}

local function activate(thread)
	activeSet[thread] = thread
end

local function deactivate(thread)
	activeSet[thread] = nil

	if thread.ready ~= false then
		thread.ready = true
		queue.threadBlocked:resumeOnAndClear(thread)
	else
		-- unclear thread
	end
end

function queue.kill(thread)
	activeSet[thread] = nil
	liveSet[thread] = nil
	if thread.script then
		thread.script.threads[thread.id] = nil
	end
	if thread.waitSet then
		thread.waitSet:removeThread(thread)
	end
	--print("killed thread# "..thread.id)
end

function queue.enqueue(thread)
	local co
	co = thread.coroutine or coroutine.create(function()
		thread.func()
		
		--[[xpcall(thread.func(), function(err)
			error(debug.traceback(err))
		end)
		--]]
		
		-- cleanup
		queue.kill(thread)
	end)
	thread.coroutine = co
	liveSet[thread] = thread
	activate(thread)
end

-- assumption: the thread dispatch loop is non-reentrant
local activeThread
function queue.runActive()
	-- duplicate list of active threads to allow the list to be added to during loop
	local copy = {}
	for thread in pairs(activeSet) do
		copy[thread] = true
	end
	for thread in pairs(copy) do
		activeThread = thread
		local ok, err = coroutine.resume(thread.coroutine)
		if not ok then
			print(err)
			queue.kill(thread)
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
     Generic container for threads waiting on some event to resume.
     A waitSet identifies relevant events by some key, scheduling
     all threads waiting on a given key when notified.
     A "cleared" event stays triggered, and waits on it return immediately.
--]]

local wait_mt = {}
wait_mt.__index = wait_mt

function wait_mt:waitOn(key)
	if self.clear[key] then
		return -- no need to wait
	end

	local blocked = self.blocked
	blocked[key] = blocked[key] or {}

	--activeThread declared above
	blocked[key][activeThread] = activeThread
	activeThread.waitSet = self
	activeThread.waitKey = key
	deactivate(activeThread)
	coroutine.yield() -- <== Coroutine jump here ===========
end

function wait_mt:resumeOn(key, ...)
	local blockedThreads = self.blocked[key]
	if blockedThreads then
		for thread in pairs(blockedThreads) do
			if self.resumeFunc then self.resumeFunc(thread, key, ...) end
			thread.waitSet = nil
			thread.waitKey = nil
			activate(thread)
		end
		self.blocked[key] = nil
	end
end

function wait_mt:resumeOnAndClear(key, ...)
	self.clear[key] = true
	self:resumeOn(key, ...)
end

function wait_mt:unClear(key)
	self.clear[key] = nil
end

function wait_mt:removeThread(thread)
	local blockedThreads = self.blocked[thread.waitKey]
	blockedThreads[thread] = nil
	if #blockedThreads == 0 then
		self.blocked[thread.waitKey] = nil
	end
end

-- resume func is called as resumeFunc(thread, key, ...),
-- getting any extra arguments passed to waitSet:resume()
function queue.newWaitSet(resumeFunc)
	return setmetatable({
		blocked = {},
		clear = setmetatable({}, aux.weak_mt),
		resumeFunc = resumeFunc,
	}, wait_mt)
end

--[[
     Predefined queues
--]]

-- Threads blocked on another thread having had runtime
queue.threadBlocked = queue.newWaitSet()

-- Threads blocked on child processes
queue.pidBlocked = queue.newWaitSet(function(thread, pid, status)
	thread.pidExitStatus = status
end)

-- by design, only one thread at a time is blocked on a PID;
-- if that gets killed, force-kill the child too (TODO: be less harsh?)
function queue.pidBlocked:removeThread(thread)
	local pid = thread.waitKey
	signal.sendSignal(pid, signal.SIGKILL)
	--default:
	wait_mt.removeThread(self, thread)
end

-- Threads blocked on file descriptor reads
queue.fdBlocked = queue.newWaitSet()


