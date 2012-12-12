
#include <unistd.h>
#include <signal.h>
#include <sys/signalfd.h>

#include <lua.h>
#include <lauxlib.h>

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

// TODO: move to signals module
static int fdSignals = -1;
static int makeSignalFd(lua_State *L) {
	
	sigset_t signalSet;
	
	sigemptyset(&signalSet);
	sigaddset(&signalSet, SIGCHLD);
	sigaddset(&signalSet, SIGALRM);
	sigaddset(&signalSet, SIGHUP);
	
	sigprocmask(SIG_BLOCK, &signalSet, NULL);
	
	fdSignals = signalfd(fdSignals, &signalSet, SFD_CLOEXEC);
	
	if(fdSignals == -1) {
		perror("makeSignalFd");
		return luaL_error(L, "Couldn't create signalfd");
	}
	
	lua_pushinteger(L, fdSignals);
	return 1;
}

static const luaL_Reg initFuncs[] = {
	{ "modeFork", &modeFork },
	{ "makeSignalFd", &makeSignalFd },
	{ NULL, NULL }
};

int luaopen_init(lua_State *L) {
	luaL_newlib(L, initFuncs);
	return 1;
}

