
// references to a Lua script we compile into the final binary
#define EXTERN_LUA_CHUNK(name) \
	extern char res_ ## name ## _luac[]; \
	extern int res_ ## name ## _luac_size;

#define LOAD_LUA_CHUNK(L, name) \
	EXTERN_LUA_CHUNK(name) \
	luaL_loadbuffer( \
	L, \
	res_ ## name ## _luac, \
	res_ ## name ## _luac_size, \
	#name );

#define RUN_LUA_CHUNK(L, name) \
	LOAD_LUA_CHUNK(L, name) \
	lua_call(L, 0, 0);

#define OPEN_LUA_C_LIB(L, name) \
	extern int luaopen_ ## name (lua_State *L); \
	lua_pushcfunction(L, &luaopen_ ## name); \
	lua_call(L, 0, 1); /* returns library table */ \
	lua_setglobal(L, #name );

