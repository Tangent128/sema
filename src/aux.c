
#include <stdlib.h>
#include <unistd.h>
#include <pwd.h>

#include <lua.h>
#include <lauxlib.h>


static int modeFork(lua_State *L) {
	
	int result = fork();
	
	if(result == -1) {
		return luaL_error(L, "Couldn't fork");
	}
	
	// normally, the forked child process becomes the server,
	// so as to disappear from the shell
	int isChild = (result == 0);
	int isServer = isChild;
	
	// reverse this for PID 1, so that init doesn't exit
	if(getpid() == 1) {
		isServer = !isChild;
	}

	// return server/client, parent/child 
	
	if(isServer) {
		lua_pushstring(L, "server");
	} else {
		lua_pushstring(L, "client");
	}
	
	if(isChild) {
		
		// decisively detach from controlling terminal
		setsid();
		if(fork() != 0) exit(0);
		
		lua_pushstring(L, "child");
	} else {
		lua_pushstring(L, "parent");
	}
	
	return 2;
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


static int getUID(lua_State *L) {

	lua_pushinteger(L, getuid());
	
	return 1;
}

// accepts string for username, or number for UID
// returns (uid, name, gid, home)
static int userInfo(lua_State *L) {
	
	struct passwd *pw = NULL;
	
	int type = lua_type(L, 1);
	
	// lookup user
	if(type == LUA_TSTRING) {
		pw = getpwnam(luaL_checkstring(L, 1));
	} else if(type == LUA_TNUMBER) {
		pw = getpwuid(luaL_checkinteger(L, 1));
	}
	
	// extract uid & name
	if(pw != NULL) {
		lua_pushinteger(L, pw->pw_uid);
		lua_pushstring(L, pw->pw_name);
		lua_pushinteger(L, pw->pw_gid);
		lua_pushstring(L, pw->pw_dir);
		return 4;
	} else {
		lua_pushnil(L);
		return 1;
	}
}

static const luaL_Reg auxFuncs[] = {
	{ "modeFork", &modeFork },
	{ "cAbsPath", &absPath},
	{ "getUID", &getUID},
	{ "userInfo", &userInfo},
	{ NULL, NULL }
};

int luaopen_aux(lua_State *L) {
	luaL_newlib(L, auxFuncs);
	return 1;
}
