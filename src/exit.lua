
-- code for shutting down cleanly

exit = {}

exit.hooks = {}

function exit.addHook(hook)
	exit.hooks[#exit.hooks + 1] = hook
end

function exit.shutdown()
	for i = 1,#exit.hooks do
		exit.hooks[i]()
	end
	
	os.exit()
end

