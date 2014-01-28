
event = {}

-- marker for metatables of objects that expect to be used as event sources
event.SourceMark = {}

function event.isSource(obj)
	local mt = getmetatable(obj)
	if mt then
		return mt[event.SourceMark] == true
	else
		return false
	end
end
function event.markSource(meta)
	meta[event.SourceMark] = true
end

-- map of objects that emit an event/promise result => the event/promise's
-- dispatcher object.
local dispatchers = setmetatable({}, aux.weak_k_mt)

-- a dispatcher carries a set of callback functions for an event/promise's
-- succeed/error results. Callbacks are single-shot.
local function dispatch(list, ...)
	for callback, mode in pairs(list) do
		pcall(callback, ...)
	end
end
local dispatch_mt = {
	__index = {
		reset = function(self)
			self.eventHandlers = {}
			self.repeatHandlers = self.repeatHandlers or {}
			self.errorHandlers = {}
			-- self.constantEvent exists, if non-nil is fired anytime a listener is provided
			-- self.constantError exists, if non-nil is fired anytime a listener is provided
			return self
		end,
		fireEvent = function(self, ...)
			dispatch(self.eventHandlers, ...)
			dispatch(self.repeatHandlers, ...)
			self:reset()
		end,
		fireError = function(self, ...)
			dispatch(self.errorHandlers, ...)
			self:reset()
		end,
		fire = function(self, type, ...)
		end
	},
	__gc = function(dispatcher)
		-- consider garbage-collection an error state;
		-- if listeners are still interested, it is an error
		-- if no listeners, then firing error does nothing
		dispatcher:fireError("Event source was garbage-collected.")
	end,
}

local function grabDispatcher(source)
	local dispatcher = dispatchers[source]
	if not dispatcher then
		dispatcher = setmetatable({}, dispatch_mt):reset()
		dispatchers[source] = dispatcher
	end
	return dispatcher
end

-- trigger handlers
function event.fire(source, ...)
	grabDispatcher(source):fireEvent(...)
end
function event.fail(source, ...)
	grabDispatcher(source):fireError(...)
end

-- trigger handlers, or queue event for when there is a handler
-- sources can queue & update an event consisting of a single data item;
-- for instance, data read from an fd when there are no listeners waiting for it yet
-- updater function takes the old value of the queued event, which is nil if none queued,
-- and returns the new value
function event.queueFire(source, updater)
	local dispatcher = grabDispatcher(source)
	if next(dispatcher.eventHandlers) or next(dispatcher.repeatHandlers) then
		dispatcher:fireEvent(updater(nil))
	else
		dispatcher.queuedEvent = updater(dispatcher.queuedEvent)
	end
end

-- setup handlers
local function drainQueue(dispatcher)
	if dispatcher.queuedEvent then
		dispatcher:fireEvent(dispatcher.queuedEvent)
	elseif dispatcher.constantEvent then
		dispatcher:fireEvent(dispatcher.constantEvent)
	end
	dispatcher.queuedEvent = nil
end
function event.onFire(source, callback)
	local dispatcher = grabDispatcher(source)
	dispatcher.eventHandlers[callback] = callback
	
	drainQueue(dispatcher)
end
--[[ is this needed / even a good idea?
function event.onEveryFire(source, callback)
	local dispatcher = grabDispatcher(source)
	dispatcher.repeatHandlers[callback] = callback
	drainQueue(dispatcher)
end]]
function event.onFail(source, callback)
	local dispatcher = grabDispatcher(source)
	dispatcher.errorHandlers[callback] = callback
	
	if dispatcher.constantError then
		dispatcher:fireError(dispatcher.constantError)
	end
end




