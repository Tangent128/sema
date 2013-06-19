
#include <unistd.h>
#include <stdlib.h>
#include <poll.h>

#include <lua.h>
#include <lauxlib.h>

static struct pollfd *fds = NULL;
static int *reasons = NULL;
static int nfds = 0;
static int size = 1;

static int poll_add_fd(lua_State *L) {
	
	// read params (fd, why)
	int fd = luaL_checkint(L, 1);
	int why = luaL_checkint(L, 2);

	// check size/initialize list
	if(nfds >= size || fds == NULL) {
		size = size * 2;
		fds = realloc(fds, sizeof(struct pollfd) * size);
		int *biggerReasons = realloc(reasons, sizeof(int) * size);
		
		if(biggerReasons == NULL) {
			close(fd);
			lua_pushstring(L, "not enough memory to open a new fd");
			lua_error(L);
		}
		
		reasons = biggerReasons;
	}
	
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

static int poll_drop_fd(lua_State *L) {

	// read param
	int fd = luaL_checkint(L, 1);
	
	// find fd
	int i;
	for(i = 0; i < nfds; i++) {
		if(fds[i].fd == fd) {
			// found it, can drop it
			
			// decrement list size
			nfds--;
			
			// rescue fd at end of list by
			// replacing dropped fd with it
			fds[i].fd = fds[nfds].fd;
			reasons[i] = reasons[nfds];
			
			return 0;
		}
	}

	// didn't find it, work's already done
	return 0;
}


static int doPoll(lua_State *L) {
	
	int result;
	int block = lua_toboolean(L, 1);
	
	if(block) {
		result = poll(fds, nfds, -1);
	} else {
		result = poll(fds, nfds, 0);
	}
	
	lua_createtable(L, result, 0);
	
	if(result > 0) {
		
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
				lua_pushstring(L, "reason");
				lua_pushinteger(L, why);
				lua_settable(L, -3);
				
				// add record to result table
				lua_settable(L, -3);
				resultIndex++;
			}
		}
		
	}
	
	return 1;
}

static const luaL_Reg pollFuncs[] = {
	{ "cAddFd", &poll_add_fd },
	{ "cDropFd", &poll_drop_fd },
	{ "cDoPoll", &doPoll },
	{ NULL, NULL }
};

int luaopen_poll(lua_State *L) {
	luaL_newlib(L, pollFuncs);
	return 1;
}
