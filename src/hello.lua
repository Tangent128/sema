print "Hello from an embedded Lua script!"

for k, v in pairs(_ENV) do
	print(k,v)
end

