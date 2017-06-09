/*
* @Author: linfeng
* @Date:   2017-06-08 16:39:41
* @Last Modified by:   linfeng
* @Last Modified time: 2017-06-09 12:07:27
*/

#include <stdio.h>
#include "aoi.h"

#include <lua.h>
#include <lauxlib.h>

static int lnew(lua_State* L)
{
	struct aoi_space* space = aoi_new();
	if(space == NULL)
		return 0;
	lua_pushlightuserdata(L, space);
	return 1;
}

static int lcreate(lua_State* L)
{
	return 0;
}

static int lrelease(lua_State* L)
{
	luaL_checktype(L ,1, LUA_TLIGHTUSERDATA);
	struct aoi_space* space = lua_tolightuserdata(L, -1);
	aoi_release(space);
	lua_pushboolen(L, TRUE);
	return 1;
}

static int lupdate(lua_State* L)
{
	if(lua_gettop(L) != 4)
	{
		lua_pushboolen(L, FALSE);
		return 1;
	}
	struct aoi_space* space = lua_tolightuserdata(L, 1);
	int id = lua_tointeger(L, 2);
	const char* mode = lua_tostring(L, 3);
	luaL_checktype(L ,4, LUA_TTABLE);
	lua_gettable(L, 4);
	float pos[3] = {0.0};
	for(int i = 1; i <= 3; i++)
	{	
		lua_rawgeti(L, -1, i);
		pos[i - 1] = lua_tonumber(L, -1);
		lua_pop(L, 1);
	}

	aoi_update(space, id, mode, pos);
	lua_pushboolen(L, TRUE);
	return 1;
}

static void _cb(void *ud, uint32_t watcher, uint32_t marker)
{
	lua_State *L = (lua_State*)ud;
	assert(lua_gettop(L) == 2);

	lua_pushvalue(L, 2);
	lua_pushinteger(L, watcher);
	lua_pushinteger(L, marker);

	int r = lua_pcall(L, 5, 0, 1);
	if(r != LUA_OK)
		printf(stderr,"aoi cb error:%s",lua_tostring(L, -1));
}

static int lmessage(lua_State* L)
{
	luaL_checktype(L, 1, LUA_TFUNCTION);
	luaL_checktype(L ,2, LUA_TUSERDATA);
	
	lua_settop(L,2);
	lua_rawsetp(L, LUA_REGISTRYINDEX, _cb);
	lua_rawgeti(L, LUA_REGISTRYINDEX, LUA_RIDX_MAINTHREAD); //main lua thread for the vm
	lua_State *gL = lua_tothread(L,-1);

	struct aoi_space* space = lua_tolightuserdata(L, 2);
	aoi_message(space, cb, gL);
	return 0;
}

int luaopen_aoi_core(lua_State* L)
{
	luaL_checkversion(L);
	luaL_Reg l[] =
	{
		{ "new", lnew },
		{ "create", lcreate },
		{ "release", lrelease },
		{ "update", lupdate },
		{ "message", lmessage },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);

	return 1;
}