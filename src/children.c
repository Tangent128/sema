
#include <unistd.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/wait.h>
#include <grp.h>

#include <lua.h>
#include <lauxlib.h>

static int run(lua_State *L) {
	
	// check argument is a table
	// numeric indices are argv
	// .user is a string username or a numeric UID to switch to if possible

	luaL_checktype(L, 1, LUA_TTABLE);
	
	int argc = lua_rawlen(L, 1);
	int i;
	
	luaL_checkstack(L, argc+2, "not enough stack space to spawn child");
	
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
	
	
	// we are the child at this point, set up enviroment
	// ==================
	
	// reenable all signals
	
	sigset_t signalSet;
	sigemptyset(&signalSet);
	sigprocmask(SIG_SETMASK, &signalSet, NULL);
	
	// set user (if able to)
	lua_getfield(L, 1, "user");
	if(lua_isnumber(L, -1)) {
		int uid = lua_tointeger(L, -1);
		
		setuid(uid);
		
		// if changing user, change group too
		lua_getfield(L, 1, "group");
		int gid = lua_tointeger(L, -1);
		lua_pop(L, 1);
		
		setgid(gid);
		
		// clear excess groups
		setgroups(0, NULL);
	}
	lua_pop(L, 1);
	
	// traverse fdMap table & map fds
	lua_getfield(L, 1, "fdMapper");
	lua_call(L, 0, 0);
	
	// change working directory
	lua_getfield(L, 1, "chdir");
	const char * workingDir = lua_tostring(L, -1);
	chdir(workingDir);
	lua_pop(L, 1);
	
	
	// prepare to exec the child process
	
	const char ** argv = malloc((argc + 1) * sizeof(char*));
	if(argv == NULL) {
		perror("malloc");
		exit(1);
	}
	
	// collect argv strings (need to be left on stack for GC safety)
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

// puntFd(fd, above)
// returns new fd (which will have CLOEXEC set)
// only expected to be called in a forked child, and thus exits on error!
static int puntFd(lua_State *L) {
	
	int fd = luaL_checkinteger(L, 1);
	int floor = luaL_checkinteger(L, 2);
	
	int punted = fcntl(fd, F_DUPFD, floor);
	if(punted == -1) {
		perror("fcntl/F_DUPFD");
		exit(1);
	}
	
	// punting is for temporary holding, no need to keep post-exec
	fcntl(punted, F_SETFD, FD_CLOEXEC);
	
	lua_pushinteger(L, punted);
	
	return 1;
}

// dupTo(from, to)
// copies a file descriptor, without the CLOEXEC flag
// only expected to be called in a forked child, and thus exits on error!
static int dupTo(lua_State *L) {
	
	int fd = luaL_checkinteger(L, 1);
	int target = luaL_checkinteger(L, 2);
	
	int status = dup2(fd, target);
	if(status == -1) {
		perror("dup2");
		exit(1);
	}
	
	return 0;
}

//static int (lua_State *L) {
//	return 0;
//}

static const luaL_Reg childFuncs[] = {
	{ "run", &run },
	{ "wait", &waitChildren },
	{ "puntFd", &puntFd },
	{ "dupTo", &dupTo },
	{ NULL, NULL }
};

int luaopen_children(lua_State *L) {
	luaL_newlib(L, childFuncs);
	return 1;
}

