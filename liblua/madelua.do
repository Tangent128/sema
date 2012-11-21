
. ./vars

# defer to make for lua
(
	cd $LUA_BUILD
	make posix
)

echo "$LUA_BUILD" > $3
