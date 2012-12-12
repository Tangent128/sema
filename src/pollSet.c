
#include <unistd.h>
#include <stdlib.h>
#include <poll.h>
#include <sys/signalfd.h>


#include <lua.h>
#include <lauxlib.h>
#include "pollSet.h"

static struct pollfd *fds = NULL;
static int *reasons = NULL;
static int nfds = 0;
static int size = 1;

static const char* watchTypes[] = {
	[FD_POLL_FOR_SIGNAL] = "signal",
	[FD_POLL_FOR_LISTEN] = "listen",
	[FD_POLL_FOR_READ] = "read",
	NULL
};

int poll_add_fd(lua_State *L) {
	
	// check size/initialize list
	if(nfds >= size || fds == NULL) {
		size = size * 2;
		fds = realloc(fds, sizeof(struct pollfd) * size);
		reasons = realloc(reasons, sizeof(int) * size);
	}
	
	// read params (fd, why)
	int fd = luaL_checkint(L, 1);
	int why = luaL_checkoption(L, 2, NULL, watchTypes);
	
	// check for existing fd
	int i;
	for(i = 0; i < nfds; i++) {
		if(fds[i].fd == fd) {
			// nothing to do, already in set
			return 0;
		}
	}
	
	// insert if needed
	struct pollfd *pollFd = &fds[nfds];
	pollFd->fd = fd;
	pollFd->events = POLLIN;
	reasons[nfds] = why;
	
	nfds++;
	
	return 0;
}

int poll_drop_fd(lua_State *L) {
	return 0;
}

static void pushReasonName(lua_State *L, int reason) {
	switch(reason) {
		case FD_POLL_FOR_SIGNAL:
				lua_pushstring(L, "signal");
			break;
		case FD_POLL_FOR_LISTEN:
				lua_pushstring(L, "listen");
			break;
		case FD_POLL_FOR_READ:
				lua_pushstring(L, "read");
			break;
		default:
			luaL_error(L, "Invalid fd type in pollSet");
	}
}

// TODO: move to signals module
static int readSignal(int fd) {
	struct signalfd_siginfo buffer;
	read(fd, &buffer, sizeof(buffer));
	
	return buffer.ssi_signo;
}

static int doPoll(lua_State *L) {
	
	int result = poll(fds, nfds, -1);
	
	if(result > 0) {
		lua_createtable(L, result, 0);
		
		int i, resultIndex = 1;
		for(i = 0; i < nfds; i++) {
			if(fds[i].revents & POLLIN) {
				int fd = fds[i].fd;
				int why = reasons[i];
			
				lua_pushinteger(L, resultIndex);
				lua_newtable(L);
				
				// set fd
				lua_pushstring(L, "fd");
				lua_pushinteger(L, fd);
				lua_settable(L, -3);
				
				// set reason-for-watching code
				lua_pushstring(L, "type");
				pushReasonName(L, why);
				lua_settable(L, -3);
				
				// set signal if relevant
				if(why == FD_POLL_FOR_SIGNAL) {
					lua_pushstring(L, "signal");
					lua_pushinteger(L, readSignal(fd));
					lua_settable(L, -3);
				}
				
				// add record to result table
				lua_settable(L, -3);
				resultIndex++;
			}
		}
		
		return 1;
	} else {
		return 0;
	}
}

static const luaL_Reg pollFuncs[] = {
	{ "addFd", &poll_add_fd },
	{ "dropFd", &poll_drop_fd },
	{ "doPoll", &doPoll },
	{ NULL, NULL }
};

int luaopen_pollSet(lua_State *L) {
	luaL_newlib(L, pollFuncs);
	return 1;
}
