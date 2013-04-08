
api = {}

--[[
	Script-side API functions
--]]

local current = queue.getActive

function api.threadName()
	return current().name
end

function api.run(tbl, ...)
	if type(tbl) ~= "table" then
		return api.run{tbl, ...}
	end
	
	local pid = children.run(table.unpack(tbl))
	queue.waitPid(pid)
	return current().pidExitStatus
end	

-- TODO: cut DEBUG code
api.print = print


