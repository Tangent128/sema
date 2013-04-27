
#include <stdlib.h>
#include <unistd.h>

#include <lua.h>
#include <lauxlib.h>


static int modeFork(lua_State *L) {
	
	int result = fork();
	
	if(result == -1) {
		return luaL_error(L, "Couldn't fork");
	}
	
	// normally, the forked child process becomes the server,
	// so as to disappear from the shell
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


static int absPath(lua_State *L) {
	const char *relative = luaL_checkstring(L, 1);
	
	char *absolute = realpath(relative, NULL);
	
	// TODO: was there a point to this behavior, or would an error be appropriate?
	if(absolute == NULL) {
		lua_pushstring(L, relative);
	} else {
		lua_pushstring(L, absolute);
	}
	free(absolute);
	
	return 1;
}



static const luaL_Reg auxFuncs[] = {
	{ "modeFork", &modeFork },
	{ "cAbsPath", &absPath},
	{ NULL, NULL }
};

int luaopen_aux(lua_State *L) {
	luaL_newlib(L, auxFuncs);
	return 1;
}
