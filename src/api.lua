
api = {}

--[[
	Script-side API functions
--]]

local current = queue.getActive

-- get name of current thread
function api.threadName()
	return current().name
end

-- spawn a child process and wait for exit
function api.run(tbl, ...)
	if type(tbl) ~= "table" then
		return api.run{tbl, ...}
	end
	
	local pid = children.run(table.unpack(tbl))
	queue.waitPid(pid)
	return current().pidExitStatus
end

-- send a message back to the client that spawned this command
-- (only works from a command handler)
function api.reply(msg)
	local reply = current().reply
	if reply then
		reply(msg)
	else
		error("reply() has to be called from a command handler")
	end
end

-- TODO: cut DEBUG code
api.print = print


