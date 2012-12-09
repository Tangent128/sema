
#include <stdlib.h>
#include <lua.h>
#include <lauxlib.h>
#include <poll.h>
#include "pollSet.h"

static struct pollfd *fds = NULL;
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
	}
	
	// read params (fd, why)
	int fd = luaL_checkint(L, 1);
	int why = luaL_checkoption(L, 2, NULL, watchTypes);
	
	// check for existing fd
	
	// insert if needed
	
	return 0;
}

int poll_drop_fd(lua_State *L) {
	return 0;
}


static const luaL_Reg pollFuncs[] = {
	{ "addFd", &poll_add_fd },
	{ "dropFd", &poll_drop_fd },
	{ NULL, NULL }
};

int luaopen_pollSet(lua_State *L) {
	luaL_newlib(L, pollFuncs);
	return 1;
}
