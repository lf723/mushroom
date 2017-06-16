#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include <errno.h>
#include <pthread.h>
#include <getopt.h>
#include <sys/time.h>
#define LUA_USE_LINUX
#include "../../3rd/skynet/3rd/lua/lua.h"
#include "../../3rd/skynet/3rd/lua/lualib.h"
#include "../../3rd/skynet/3rd/lua/lauxlib.h"

#define ERR_EXIT(msg,arg...) \
do \
{ \
	char info[1024] = {0}; \
	snprintf(info,sizeof(info),msg,##arg); \
	fprintf(stderr,info); \
	exit(EXIT_FAILURE); \
}while(0)

#define INFO_EXIT(msg,arg...) \
do \
{ \
	char info[1024] = {0}; \
	snprintf(info,sizeof(info),msg,##arg); \
	fprintf(stderr,info); \
	return NULL; \
}while(0)

typedef struct _threadArgs
{
	char* luaFileName;
	char* arg;
	int ext;
}ThreadArgs;

void* thread_func(void* arg)
{
	ThreadArgs* tArgs = (ThreadArgs*)arg;
	//init lua
	lua_State* L = luaL_newstate();
	if(L == NULL)
		INFO_EXIT("new lua state fail!\n");

	luaL_checkversion(L);
	luaL_openlibs(L);
	if(luaL_loadfile(L,tArgs->luaFileName) != LUA_OK)
		INFO_EXIT(lua_tostring(L,-1));

	lua_pushstring(L,tArgs->arg);
	lua_pushinteger(L,tArgs->ext);
	int ret = lua_pcall(L,2,0,0);
	if(ret != LUA_OK)
		INFO_EXIT("run lua script fail:%s\n",lua_tostring(L,-1));

	lua_gc(L, LUA_GCRESTART, 0);
	lua_close(L);
	free(arg); //calloc in main thread
	return NULL;
}

void ShowUsage()
{
	ERR_EXIT("Usage: \n-f\t[luafilename]\tdofile lua file name\n"
						"-n\trepeat the lua script,default 1\n"
						"-a\tlua script argument\n");
}

int main(int argc,char* argv[])
{
	int opt;
	int reCount = 1;
	char* luaFileName = NULL;
	char* arg = NULL;

	while((opt = getopt(argc,argv,"f:n:a:")) != -1)
	{
		switch(opt)
		{
			case 'f':
				luaFileName = strdup(optarg);
				break;
			case 'n':
				reCount = atoi(optarg);
				break;
			case 'a':
				arg = strdup(optarg);
				break;
			default: /* '?' */
				ShowUsage();
				break;
		}
	}

	if(!luaFileName)
		ShowUsage();

	pthread_t threadIds[reCount]; //only c99 or gnu99
	for(int i = 0; i < reCount; i++)
	{
		ThreadArgs* tArgs = (ThreadArgs*)calloc(1,sizeof(ThreadArgs));
		tArgs->luaFileName = luaFileName;
		tArgs->arg = arg;
		tArgs->ext = i;
		int ret = pthread_create(&threadIds[i],NULL,thread_func,(void*)tArgs);
		if(ret != 0)
			ERR_EXIT("pthread_create fail,err info:%s\n",strerror(ret));
	}

	for (int i = 0; i < reCount; ++i)
		pthread_join(threadIds[i],NULL);

	free(luaFileName);
	free(arg);
	return 0;
}
