
# suppress stdout
exec 1>&2

LUA_BUILD=../lua-5.2.1

# defer to make for lua
(
	cd $LUA_BUILD
	make posix
)

cp $LUA_BUILD/src/liblua.a $3

