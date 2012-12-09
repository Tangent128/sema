
// reasons a given FD may be queued
#define	FD_POLL_FOR_SIGNAL	0
#define	FD_POLL_FOR_LISTEN	1
#define	FD_POLL_FOR_READ	2

int poll_add_fd(lua_State *L);
int poll_drop_fd(lua_State *L);

int luaopen_poll(lua_State *L);
