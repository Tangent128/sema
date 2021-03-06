
local reasons = {
	"signal", "read"
}
local reasonIndex = {}
for k,v in pairs(reasons) do
	reasonIndex[v] = k
end

function poll.addFd(fd, reason)
	poll.cAddFd(fd, reasonIndex[reason])
	--print("add", fd, reason, reasonIndex[reason])
end

function poll.dropFd(fd)
	poll.cDropFd(fd)
end

function poll.events(block)
	local result = {
		signals = {},
		children = {},
		fds = {},
	}
	
	-- collect events
	local readableFds = poll.cDoPoll(block)
	for k, v in pairs(readableFds) do
		local reason = reasons[v.reason]
		
		if reason == "signal" then
			local sig = signal.readSignal(v.fd)
			result.signals[sig] = true
		elseif reason == "read" then
			result.fds[v.fd] = true
		elseif false then
		end
	end
	
	-- handle certain signal events
	for k, v in pairs(result.signals) do
	
		if k == signal.SIGCHLD then
			result.children = children.wait()
		elseif (k == signal.SIGINT) or (k == signal.SIGTERM) then
			--TODO: hard shutdown on SIGQUIT, else send exit command to all scripts and wait for all exit
			aux.shutdown()
		end
		
	end

	
	return result
end

