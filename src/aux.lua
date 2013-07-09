
-- misc. functions supplementing os table

-- utility metatable for making tables key-weak
aux.weak_k_mt = {
	__mode = "k"
}
-- utility metatable for making tables fully weak
aux.weak_mt = {
	__mode = "kv"
}

-- code to normalize paths
function aux.absPath(path)
	local dir, name = path:match("^(.-/?)([^/]-)$")
	
	if #dir == 0 then
		--TODO: we presumably want to use some default directory
		-- in these cases besides cwd
		dir = "./"
	end
		
	-- normalize directory, including a trailing slash
	-- (but leave "/" as-is, not "//")
	dir = aux.cAbsPath(dir):gsub("^(.-)/?$", "%1/")
	
	path = dir .. name
	
	return path, dir
end

function aux.resolvePath(base, path)
	if path:match("^/") then
		return path
	end
	
	return base .. "/" .. path
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

