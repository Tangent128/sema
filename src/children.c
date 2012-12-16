
#include <unistd.h>
#include <stdlib.h>
#include <sys/wait.h>

#include <lua.h>
#include <lauxlib.h>

static int run(lua_State *L) {
	
	// check arguments
	
	int argc = lua_gettop(L);
	
	if(argc < 1) {
		return luaL_error(L, "No command provided to run.");
	}
	
	int i;
	for(i = 0; i < argc; i++) {
		luaL_checkstring(L, i+1);
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
	
	// prepare to exec the child process
	
	//typedef char * ConstString;
	const char ** argv = malloc((argc + 1) * sizeof(char*));
	
	for(i = 0; i < argc; i++) {
		argv[i] = luaL_checkstring(L, i+1);
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

