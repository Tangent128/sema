
# not very portable, just for testing

redo-ifchange liblua/liblua.a liblua/lua.h liblua/lualib.h liblua/lauxlib.h liblua/luaconf.h
redo-ifchange src/hello.c build/hello.luac.c

gcc -Wall -Iliblua -Lliblua src/hello.c -o $3 -llua -lm
