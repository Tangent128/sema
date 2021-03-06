
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
	sigaddset(&signalSet, SIGINT);
	sigaddset(&signalSet, SIGTERM);
	sigaddset(&signalSet, SIGPIPE);
	
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

static int sendSignal(lua_State *L) {
	int pid = luaL_checkint(L, 1);
	int signum = luaL_checkint(L, 2);
	
	kill(pid, signum);
	printf("sent signal %d to %d\n", signum, pid);
	
	return 0;
}

static const luaL_Reg signalFuncs[] = {
	{ "makeSignalFd", &makeSignalFd },
	{ "readSignal", &readSignal },
	{ "sendSignal", &sendSignal },
	{ NULL, NULL }
};

#define REGISTER_SIGNAL(signal) \
	lua_pushstring(L, #signal); \
	lua_pushinteger(L, signal); \
	lua_settable(L, -3);

int luaopen_signal(lua_State *L) {
	luaL_newlib(L, signalFuncs);
	
	REGISTER_SIGNAL(SIGALRM);
	REGISTER_SIGNAL(SIGCHLD);
	REGISTER_SIGNAL(SIGHUP);
	REGISTER_SIGNAL(SIGINT);
	REGISTER_SIGNAL(SIGKILL);
	REGISTER_SIGNAL(SIGPIPE);
	REGISTER_SIGNAL(SIGTERM);
	REGISTER_SIGNAL(SIGUSR1);
	REGISTER_SIGNAL(SIGUSR2);
	// TODO: more
	
	return 1;
}

