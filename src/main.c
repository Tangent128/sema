
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

/*******************************
 *  Macros to declare & load
 *  C & Lua modules, according
 *  to naming conventions 
 */

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

/*******************************
 *  Main- load C & Lua modules,
 *        then run starting code 
 */

int main(int argc, char** argv) {
	
	lua_State *L = luaL_newstate();
	luaL_openlibs(L);
	
	// load C functions
	OPEN_LUA_C_LIB(L, aux)
	OPEN_LUA_C_LIB(L, signal)
	OPEN_LUA_C_LIB(L, children)
	OPEN_LUA_C_LIB(L, poll)
	OPEN_LUA_C_LIB(L, socket)
	
	// load Lua functions
	RUN_LUA_CHUNK(L, aux)
	RUN_LUA_CHUNK(L, event)
	RUN_LUA_CHUNK(L, poll)
	RUN_LUA_CHUNK(L, queue)
	RUN_LUA_CHUNK(L, api)
	RUN_LUA_CHUNK(L, script)
	RUN_LUA_CHUNK(L, supervise)
	RUN_LUA_CHUNK(L, control)
	RUN_LUA_CHUNK(L, socket)
	
	// load entry Lua code
	LOAD_LUA_CHUNK(L, main)
	
	lua_checkstack(L, argc);
	
	int i;
	for(i = 0; i < argc; i++) {
		lua_pushstring(L, argv[i]);
	}
	
	lua_call(L, argc, 0);
	
	return 0;
}

