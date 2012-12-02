
#include <lua.h>
#include <lauxlib.h>
#include "resources.h"

int main(int argc, char** argv) {
	
	lua_State *L = luaL_newstate();
	luaL_openlibs(L);
	
	luaL_loadbuffer(L, res_main_luac, res_main_luac_size, "main");
	
	int i;
	for(i = 0; i < argc; i++) {
		lua_checkstack(L, 1);
		lua_pushstring(L, argv[i]);
	}
	
	lua_call(L, argc, 0);
	
	return 0;
}

