
#include <unistd.h>
#include <signal.h>
#include <sys/signalfd.h>

#include <lua.h>
#include <lauxlib.h>

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

static int readSignal(lua_State *L) {
	int fd = luaL_checkint(L, 1);
	
	struct signalfd_siginfo buffer;
	read(fd, &buffer, sizeof(buffer));
	
	lua_pushinteger(L, buffer.ssi_signo);
	return 1;
}

static const luaL_Reg signalFuncs[] = {
	{ "makeSignalFd", &makeSignalFd },
	{ "readSignal", &readSignal },
	{ NULL, NULL }
};

int luaopen_signal(lua_State *L) {
	luaL_newlib(L, signalFuncs);
	return 1;
}
