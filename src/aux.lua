
-- misc. functions supplementing os table

-- code to normalize paths
function aux.absPath(path)
	local dir, name = path:match("^(.-/?)([^/]-)$")
	
	if #dir == 0 then
		--TODO: do we want to use some default directory
		-- in these cases besides cwd?
		dir = "./"
	end
		
	-- normalize directory, including a trailing slash
	-- (but leave "/" as-is, not "//")
	dir = aux.cAbsPath(dir):gsub("^(.-)/?$", "%1/")
	
	path = dir .. name
	
	return path, dir
end

-- code for shutting down cleanly
aux.exitHooks = {}

function aux.addExitHook(hook)
	aux.exitHooks[#aux.exitHooks + 1] = hook
end

function aux.shutdown()
	for i = 1,#aux.exitHooks do
		aux.exitHooks[i]()
	end
	
	os.exit()
end

