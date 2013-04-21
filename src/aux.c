
#include <stdlib.h>

#include <lua.h>
#include <lauxlib.h>

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
	{ "cAbsPath", &absPath},
	{ NULL, NULL }
};

int luaopen_aux(lua_State *L) {
	luaL_newlib(L, auxFuncs);
	return 1;
}
