
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
	-- normalize arguments
	if type(tbl) ~= "table" then
		return api.run{tbl, ...}
	end
	
	-- run child process
	local pid = children.run(table.unpack(tbl))
	queue.waitPid(pid)
	return current().pidExitStatus
end

-- send a message back to the client that spawned this command
-- (only works from a command handler)
function api.reply(...)
	local reply = current().reply
	if reply then
		reply{"STATUS", ...}
	else
		error("reply() has to be called from a command handler")
	end
end

--[[
     Default implementation for default commands
--]]

api.command = {}

do 
	local _ENV = api
	
	function command.up()
		--up()
	end
	
	function command.down()
		--down()
		--killall()
	end
	
	function command.status()
		reply {
			"OK",
			"Script loaded."
		}
	end
end

-- access to global environment for debug purposes
-- (not realistic security risk, as scripts can inherently spawn arbitrary processes)
api.DEBUG = _G


