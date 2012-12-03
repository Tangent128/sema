
#include <unistd.h>
#include <lua.h>
#include <lauxlib.h>
#include "resources.h"

static int modeFork(lua_State *L) {
	
	int result = fork();
	
	if(result == -1) {
		return luaL_error(L, "Couldn't fork");
	}
	
	// normally, the forked child process becomes the server,
	// so as to disappear with the shell
	int isServer = (result == 0);
	
	// reverse this for PID 1, so that init doesn't exit
	if(getpid() == 1) {
		isServer = !isServer;
	}

	// return	
	if(isServer) { // Child
		lua_pushstring(L, "server");
		return 1;
		
	} else { // Parent
		lua_pushstring(L, "client");
		return 1;
		
	}
	
}

static const luaL_Reg initFuncs[] = {
	{ "modeFork", &modeFork },
	{ NULL, NULL }
};

void loadInitFuncs(lua_State *L) {
	luaL_newlib(L, initFuncs);
	lua_setglobal(L, "init");
}

