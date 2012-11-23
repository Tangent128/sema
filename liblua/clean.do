
. ./vars

rm -f *.a *.h lua luac madelua

# clean lua dir too
(
	cd $LUA_BUILD
	make clean
)
