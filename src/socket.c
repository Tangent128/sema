
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <sys/un.h>
#include <stdint.h>

#include <lua.h>
#include <lauxlib.h>

static int absPath(lua_State *L) {
// TODO: move to misc. utils module at some point, has non-socket uses
	const char *relative = luaL_checkstring(L, 1);
	
	char *absolute = realpath(relative, NULL);
	
	if(absolute == NULL) {
		lua_pushstring(L, relative);
	} else {
		lua_pushstring(L, absolute);
	}
	free(absolute);
	
	return 1;
}

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
	printf("%d\n", result);
	
	lua_pushinteger(L, client);
	return 1;
}

static int acceptConnection(lua_State *L) {

	int serverSocket = luaL_checkinteger(L, 1);

	int newConnection = accept(serverSocket, NULL, NULL);
	
	lua_pushinteger(L, newConnection);
	return 1;
}

static int closeConnection(lua_State *L) {
	
	int fd = luaL_checkinteger(L, 1);
	
	close(fd);
	
	return 0;
}

static int readFromConnection(lua_State *L) {
	
	int fd = luaL_checkinteger(L, 1);
	
	char buffer[256];
	size_t len = read(fd, buffer, sizeof(buffer));
	
	if(len == 0) {
		/* TODO: what on socket close? An error, since message lengths are known? Nil? Empty string (current behavior)? */
	}
	
	lua_pushlstring(L, buffer, len);
	
	return 1;
}

static int writeToConnection(lua_State *L) {
	
	int fd = luaL_checkinteger(L, 1);
	size_t len;
	const char *message = luaL_checklstring (L, 2, &len);
	
	write(fd, message, len);
	
	return 0;
}


/* functions to read & format 32-bit network-byte-order unsigned int fields, given as bytestrings */
static int readNetworkInt(lua_State *L) {
	size_t len;
	const char* bytes = luaL_checklstring(L, 1, &len);
	if(len < 4) {
		return luaL_error(L, "need a 4-byte string argument");
	}
	
	const uint32_t *netNum = (const uint32_t*) bytes;
	lua_pushunsigned(L, ntohl(*netNum));
	return 1;
}

static int formatNetworkInt(lua_State *L) {

	uint32_t hostNum = luaL_checkunsigned(L, 1);
	uint32_t netNum = htonl(hostNum);
	lua_pushlstring(L, (char *) &netNum, sizeof(netNum));
	return 1;
}

static const luaL_Reg socketFuncs[] = {
	/* wrapped in, or only used by, socket.lua */
	{ "cAbsPath", &absPath},
	{ "cGrabServerSocket", &grabServerSocket },
	{ "cGrabClientSocket", &grabClientSocket },
	{ "cAccept", &acceptConnection },
	{ "cRead", &readFromConnection },
	{ "cWrite", &writeToConnection },
	{ "cClose", &closeConnection },
	{ "cUnlink", &unlinkL },
	
	/* no wrapping needed */
	{ "readNetworkInt", &readNetworkInt }, // readNetworkInt(4-bytes)
	{ "formatNetworkInt", &formatNetworkInt }, // formatNetworkInt(uint)
	{ NULL, NULL }
};

int luaopen_socket(lua_State *L) {
	luaL_newlib(L, socketFuncs);
	return 1;
}
