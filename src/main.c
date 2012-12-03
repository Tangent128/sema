
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include "resources.h"

// from init.c
void loadInitFuncs(lua_State *L);

int main(int argc, char** argv) {
	
	lua_State *L = luaL_newstate();
	luaL_openlibs(L);
	
	// load C functions
	loadInitFuncs(L);	
	
	// load initial Lua code
	LOAD_LUA_CHUNK(L, main)
	
	int i;
	for(i = 0; i < argc; i++) {
		lua_checkstack(L, 1);
		lua_pushstring(L, argv[i]);
	}
	
	lua_call(L, argc, 0);
	
	return 0;
}

