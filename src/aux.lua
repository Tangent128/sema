
-- misc. functions supplementing os table

-- code for shutting down cleanly

aux = {}

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

