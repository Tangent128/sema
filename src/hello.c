
#include <lua.h>
#include <lauxlib.h>

// include "../build/hello.luac.c"

extern char res_hello_luac[];
extern int res_hello_luac_size;

int main(int argc, char** argv) {
	
	lua_State *L = luaL_newstate();
	luaL_openlibs(L);
	
	luaL_dostring(L, "print([[Hello from ]].._VERSION..[[~!]])");
	
	luaL_loadbuffer(L, res_hello_luac, res_hello_luac_size, "hello");
	lua_call(L, 0, 0);
	
	return 0;
}

