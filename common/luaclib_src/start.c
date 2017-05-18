/*
* @Author: linfeng
* @Date:   2017-01-04 10:05:59
* @Last Modified by:   linfeng
* @Last Modified time: 2017-02-09 14:41:24
*/

#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdbool.h> //bool type

#define FAIL(format,arg...) \
do \
{ \
	char fbuf[1024] = {0}; \
	snprintf(fbuf,sizeof(fbuf),"\033[31m[ERR]\033[0m  %s\n",format); \
	fprintf( stderr, fbuf ,##arg); \
	exit(EXIT_FAILURE); \
} \
while(0)

#define OK(format,arg...) \
do \
{ \
	char fbuf[1024] = {0}; \
	snprintf(fbuf,sizeof(fbuf),"\033[32m[MSG]\033[0m  %s\n",format); \
	fprintf( stderr, fbuf ,##arg); \
} \
while(0)


void ShowUsage()
{
	FAIL("Usage: \n-h\tthis help\n"
					"-l\tstart login server,default use etc/start_login.sh\n"
					"-g\tstart game server,default use etc/start_game.sh\n"
					"-b\tstart battle server,default use etc/start_battle.sh\n"
					"-m\tstart monitor server,default use etc/start_monitor.sh\n"
					"-w\tstart world server,default use etc/start_world.sh\n"
					"-s\t[name]\tstop server by name\n");
}

void boot_server(char* name,char* shell)
{
	OK("start %s server...",name);
	
	//启动程序
	char cmd[128] = {0};
	snprintf(cmd,sizeof(cmd),"bash %s",shell);
	if(system(cmd) == -1)
		FAIL("start %s fail,shell:%s",name,shell);

	OK("boot <%s> ok",name);
}

void kill_server(char* name)
{
	OK("kill <%s> server...",name);

	//get pid
	FILE* f = NULL;
	int processid = 0;
	char cmd[128] = {0};
	snprintf(cmd,sizeof(cmd),"cat logs/%s.pid",name);
	if((f = popen(cmd,"r")) == NULL)
		FAIL("not found logs/%s.pid file,stop fail.",name);
	if(fgets(cmd,sizeof(cmd),f) == NULL)
	{
		pclose(f);
		FAIL("get pid error,stop fail.");
	}
	else
		processid = atoi(cmd);

	snprintf(cmd,sizeof(cmd),"kill -1 %d",processid);
	if(system(cmd) == -1)
		FAIL("kill %s fail",name);

	OK("kill <%s> ok",name);
}

int main(int argc, char* argv[]) 
{
	if(argc < 2)
		ShowUsage();

	bool boot_login = false,boot_game = false,boot_battle = false, stop_server = false;
	bool boot_monitor = false, boot_center = false, boot_db = false, boot_world = false;
	char process_name[128] = {0};
	int opt;
	while((opt = getopt(argc,argv,"lgbms:cdwh")) != -1)
	{
		switch(opt)
		{
			case 'h':
				ShowUsage();
				break;
			case 'l':
				boot_login = true;
				break;
			case 'g':
				boot_game = true;
				break;
			case 'b':
				boot_battle = true;
				break;
			case 'm':
				boot_monitor = true;
				break;
			case 'c':
				boot_center = true;
				break;
			case 'd':
				boot_db = true;
				break;
			case 'w':
				boot_world = true;
				break;
			case 's':
				stop_server = true;
				strncpy(process_name,optarg,sizeof(process_name));
				break;
			default: /* '?',':' */
				ShowUsage();
				break;
		}
	}

	if(!stop_server && !boot_login && !boot_game && !boot_battle 
		&& !boot_monitor && !boot_center && !boot_db && !boot_world)
		ShowUsage();

	if(stop_server)
		kill_server(process_name);
	if(boot_login)
		boot_server("login server", "etc/start_login.sh");
	if(boot_game)
		boot_server("game server", "etc/start_game.sh");
	if(boot_battle)
		boot_server("battle server", "etc/start_battle.sh");
	if(boot_monitor)
		boot_server("monitor server", "etc/start_monitor.sh");
	if(boot_center)
		boot_server("center server", "etc/start_center.sh");
	if(boot_db)
		boot_server("db server", "etc/start_db.sh");
	if(boot_world)
		boot_server("world server", "etc/start_world.sh");

    return 0;
}