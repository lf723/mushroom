#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include <errno.h>
#include <pthread.h>
#include <getopt.h>
#include <sys/time.h>
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

void* thread_func(void* arg)
{
	char* luaFileName = (char*)arg;

	//init lua
	lua_State* L = luaL_newstate();
	if(L == NULL)
		ERR_EXIT("new lua state fail!\n");
	luaL_openlibs(L);

	if(luaL_loadfile(L,luaFileName) != LUA_OK)
		ERR_EXIT(lua_tostring(L,-1));

	struct timeval now;
	int ret = gettimeofday(&now,NULL);
	if(ret != 0)
		ERR_EXIT("gettimeofday fail:%s\n",strerror(errno));
	size_t uid = now.tv_sec + now.tv_usec;

	lua_pushinteger(L,uid);
	ret = lua_pcall(L,1,0,0);
	if(ret != LUA_OK)
		ERR_EXIT("run lua script fail:%s\n",lua_tostring(L,-1));

	lua_close(L);

	free(arg); //strdup from main thread

	return NULL;
}

void ShowUsage()
{
	ERR_EXIT("Usage: \n-f\t[luafilename]\tdofile lua file name\n"
						"-n\trepeat the lua script,default 1\n");
}

int main(int argc,char* argv[])
{
	int opt;
	char* luaFileName = NULL;
	int reCount = 1;

	while((opt = getopt(argc,argv,"f:n:")) != -1)
	{
		switch(opt)
		{
			case 'f':
				luaFileName = optarg;
				break;
			case 'n':
				reCount = atoi(optarg);
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
		int ret = pthread_create(&threadIds[i],NULL,thread_func,(void*)strdup(luaFileName));
		if(ret != 0)
			ERR_EXIT("pthread_create fail,err info:%s\n",strerror(ret));
	}

	for (int i = 0; i < reCount; ++i)
		pthread_join(threadIds[i],NULL);
	
	return 0;
}
