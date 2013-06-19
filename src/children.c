
#include <unistd.h>
#include <stdlib.h>
#include <sys/wait.h>

#include <lua.h>
#include <lauxlib.h>

static int run(lua_State *L) {
	
	// check argument is a table
	// numeric indices are argv
	// .user is a string username or a numeric UID to switch to if possible

	luaL_checktype(L, 1, LUA_TTABLE);
	
	int argc = lua_rawlen(L, 1);
	int i;
	
	// argv check
	
	if(argc < 1) {
		return luaL_error(L, "No command provided to run.");
	}
	
	// loop through numeric indicies, ensure all are strings
	for(i = 1; i <= argc; i++) {
		lua_pushinteger(L, i);
		lua_gettable(L, 1);
		luaL_checkstring(L, -1);
		lua_pop(L, 1);
	}
	
	// OK, sanity check done, prepare child
	
	int result = fork();
	
	if(result == -1) {
		return luaL_error(L, "Couldn't fork");
	}

	if(result != 0) {
		// we are still the supervisor process, return the child PID
		lua_pushinteger(L, result);
		return 1;
	}
	
	// we are the child, set up enviroment
	
	// set user (if able to)
	
	// prepare to exec the child process
	
	const char ** argv = malloc((argc + 1) * sizeof(char*));
	if(argv == NULL) {
		perror("malloc");
		exit(1);
	}
	
	// collect argv strings
	for(i = 1; i <= argc; i++) {
		lua_pushinteger(L, i);
		lua_gettable(L, 1);
		argv[i-1] = luaL_checkstring(L, -1);
	}
	argv[argc] = NULL;
	
	execvp(argv[0], (char **) argv);
	
	perror("execvp");
	
	exit(1);
}

static int waitChildren(lua_State *L) {
	
	lua_newtable(L);
	
	int status;
	while(1) {
		int result = waitpid(-1, &status, WNOHANG);
		
		if(result <= 0) break;
		
		// TODO: distinguish between exits, signal kills, etc
		lua_pushinteger(L, result); // pid
		lua_pushinteger(L, WEXITSTATUS(status));
		lua_settable(L, -3);
	}
	
	return 1;
}

//static int (lua_State *L) {
//	return 0;
//}

static const luaL_Reg childFuncs[] = {
	{ "run", &run },
	{ "wait", &waitChildren },
	{ NULL, NULL }
};

int luaopen_children(lua_State *L) {
	luaL_newlib(L, childFuncs);
	return 1;
}

