
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include "resources.h"

int main(int argc, char** argv) {
	
	lua_State *L = luaL_newstate();
	luaL_openlibs(L);
	
	// load C functions
	OPEN_LUA_C_LIB(L, init)
	OPEN_LUA_C_LIB(L, poll)
	OPEN_LUA_C_LIB(L, signal)
	
	// load Lua functions
	//RUN_LUA_CHUNK(L, poll)
	RUN_LUA_CHUNK(L, supervise)
	RUN_LUA_CHUNK(L, control)
	
	// load entry Lua code
	LOAD_LUA_CHUNK(L, main)
	
	int i;
	for(i = 0; i < argc; i++) {
		lua_checkstack(L, 1);
		lua_pushstring(L, argv[i]);
	}
	
	lua_call(L, argc, 0);
	
	return 0;
}

