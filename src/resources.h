
#define LUA_CHUNK(name) \
extern char res_ ## name ## _luac[]; \
extern int res_ ## name ## _luac_size;

// references to the Lua scripts we compile into the final binary
LUA_CHUNK(main)
