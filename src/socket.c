
#include <stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>

#include <lua.h>
#include <lauxlib.h>

static int grabServerSocket(lua_State *L) {
	lua_pushnil(L);
	return 1;
}

static int grabClientSocket(lua_State *L) {
	lua_pushnil(L);
	return 1;
}

static int acceptConnection(lua_State *L) {
	lua_pushnil(L);
	return 1;
}

static int closeConnection(lua_State *L) {
	lua_pushnil(L);
	return 1;
}

static const luaL_Reg socketFuncs[] = {
	{ "cGrabServerSocket", &grabServerSocket },
	{ "cGrabClientSocket", &grabClientSocket },
	{ NULL, NULL }
};

int luaopen_socket(lua_State *L) {
	luaL_newlib(L, socketFuncs);
	return 1;
}
