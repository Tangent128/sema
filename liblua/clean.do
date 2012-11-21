
. ./vars

rm liblua.a luac madelua

# clean lua dir too
(
	cd $LUA_BUILD
	make clean
)
