
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>

#include <lua.h>
#include <lauxlib.h>

static int grabServerSocket(lua_State *L) {
	const char *path = luaL_checkstring(L, 1);
	
	int server = socket(AF_UNIX, SOCK_STREAM, 0);
	if(server == -1) {
		perror("socket");
		return luaL_error(L, "Couldn't create server socket");
	}
	
	struct sockaddr_un addr;
	addr.sun_family = AF_UNIX;
	strncpy(addr.sun_path, path, sizeof(addr.sun_path));
	
	errno = 0;
	int result = bind(server, (struct sockaddr*) &addr, sizeof(addr));
	if(result == -1) {
		close(server);
		perror("bind");
		return luaL_error(L, "Couldn't bind server socket");
	}
	
	result = listen(server, 128);
	if(result == -1) {
		close(server);
		perror("listen");
		return luaL_error(L, "Couldn't listen on server socket");
	}
	
	lua_pushinteger(L, server);
	return 1;
}

static int unlinkL(lua_State *L) {
	const char *path = luaL_checkstring(L, 1);
	unlink(path);
	return 0;
}

static int grabClientSocket(lua_State *L) {
	
	const char *path = luaL_checkstring(L, 1);
	
	int client = socket(AF_UNIX, SOCK_STREAM, 0);
	if(client == -1) {
		perror("socket");
		return luaL_error(L, "Couldn't create client socket");
	}
	
	struct sockaddr_un addr;
	addr.sun_family = AF_UNIX;
	strncpy(addr.sun_path, path, sizeof(addr.sun_path));
	
	errno = 0;
	int result = connect(client, (struct sockaddr*) &addr, sizeof(addr));
	if(errno == ECONNREFUSED || errno == ENOENT) {
		lua_pushnil(L);
		return 1;
	}
	if(result == -1) {
		perror("connect");
		return luaL_error(L, "Couldn't connect client socket");
	}
	
	
	lua_pushinteger(L, client);
	return 1;
}

static int acceptConnection(lua_State *L) {
	lua_pushnil(L);
	return 1;
}

static int closeConnection(lua_State *L) {
	lua_pushnil(L);
	return 1;
}

static int readFromConnection(lua_State *L) {
	lua_pushnil(L);
	return 1;
}

static int writeToConnection(lua_State *L) {
	lua_pushnil(L);
	return 1;
}

static const luaL_Reg socketFuncs[] = {
	{ "cGrabServerSocket", &grabServerSocket },
	{ "cGrabClientSocket", &grabClientSocket },
	{ "cUnlink", &unlinkL },
	{ NULL, NULL }
};

int luaopen_socket(lua_State *L) {
	luaL_newlib(L, socketFuncs);
	return 1;
}
