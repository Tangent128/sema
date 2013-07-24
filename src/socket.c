
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <arpa/inet.h>
#include <sys/un.h>
#include <stdint.h>

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
	
	// don't pass socket fd to children unintentionally
	fcntl(server, F_SETFD, FD_CLOEXEC);
	
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
	if(errno == ECONNREFUSED) {
		// try to clean up stale socket so a new server can be spawned
		struct stat fileInfo;
		stat(path, &fileInfo);
		
		if(S_ISSOCK(fileInfo.st_mode)) {
			// the path actually is a socket,
			// and thus safe to attempt deleting
			unlink(path);
		} else {
			return luaL_error(L, "Chosen socket path was not a socket.");
		}
		
		// report cause of error
		lua_pushnil(L);
		lua_pushstring(L, "ECONNREFUSED");
		return 2;
	}
	if(errno == ENOENT) {
		lua_pushnil(L);
		lua_pushstring(L, "ENOENT");
		return 2;
	}
	if(result == -1) {
		perror("connect");
		return luaL_error(L, "Couldn't connect client socket");
	}
	//printf("%d\n", result);
	
	// don't pass socket fd to children unintentionally
	fcntl(client, F_SETFD, FD_CLOEXEC);
	
	lua_pushinteger(L, client);
	return 1;
}

static int acceptConnection(lua_State *L) {

	int serverSocket = luaL_checkinteger(L, 1);

	int newConnection = accept(serverSocket, NULL, NULL);
	
	// don't pass socket fd to children unintentionally
	fcntl(newConnection, F_SETFD, FD_CLOEXEC);
	
	lua_pushinteger(L, newConnection);
	return 1;
}

static int makePipe(lua_State *L) {

	int fds[2];
	int status = pipe(fds);
	
	if(status != 0) {
		perror("pipe");
		return luaL_error(L, "Couldn't make pipe pair.");
	}
	
	// don't pass pipe fds to children unintentionally
	fcntl(fds[0], F_SETFD, FD_CLOEXEC);
	fcntl(fds[1], F_SETFD, FD_CLOEXEC);
	
	lua_pushinteger(L, fds[0]);
	lua_pushinteger(L, fds[1]);
	
	return 2;
}

static int closeFd(lua_State *L) {
	
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
	
	// make writing nonblocking
	int oldFlags = fcntl(fd, F_GETFL, 0);
	fcntl(fd, F_SETFL, O_NONBLOCK);
	
	// write data
	size_t result = write(fd, message, len);
	
	// restore state regardless of success or failure
	fcntl(fd, F_SETFL, oldFlags);
	
	// identify some errors
	if(result == -1) {
		if(errno == EPIPE) {
			return luaL_error(L, "Connection closed before message sent.");
		} else if(errno == EAGAIN || errno == EWOULDBLOCK) {
			return luaL_error(L, "Pipe/socket full.");
		}
		return luaL_error(L, "Unknown socket write error.");
	}
	
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
	{ "cGrabServerSocket", &grabServerSocket },
	{ "cGrabClientSocket", &grabClientSocket },
	{ "cAccept", &acceptConnection },
	{ "cPipe", &makePipe },
	{ "cRead", &readFromConnection },
	{ "cWrite", &writeToConnection },
	{ "cClose", &closeFd },
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
