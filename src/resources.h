
#define EXTERN_LUA_CHUNK(name) \
extern char res_ ## name ## _luac[]; \
extern int res_ ## name ## _luac_size;

// references to the Lua scripts we compile into the final binary
EXTERN_LUA_CHUNK(main)

#define LOAD_LUA_CHUNK(L, name) luaL_loadbuffer( \
	L, \
	res_ ## name ## _luac, \
	res_ ## name ## _luac_size, \
	#name );

