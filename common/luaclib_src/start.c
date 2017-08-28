/*
* @Author: linfeng
* @Date:   2017-01-04 10:05:59
* @Last Modified by:   linfeng
* @Last Modified time: 2017-07-04 16:51:57
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
					"-a\tstart all services\n"
					"-f\tforce run in daemon\n"
					"-l\tstart login server,default use etc/start_login.sh\n"
					"-g\tstart game server,default use etc/start_game.sh\n"
					"-b\tstart battle server,default use etc/start_battle.sh\n"
					"-m\tstart monitor server,default use etc/start_monitor.sh\n"
					"-r\tstart redis server,default use etc/start_redis.sh\n"
					"-d\tstart db server,default use etc/start_db.sh\n"
					"-c\tstart center server,default use etc/start_center.sh\n"
					"-s\t[name]\tstop server by name, if name is 'all', then kill all service\n");
}

bool boot_daemon = false;

void boot_server(char* name,char* shell, bool all_start)
{
	OK("start %s server...",name);
	char cmd[128] = {0};
	int f_daemon = (all_start || boot_daemon) ? 0 : 1;
	int t_daemon = (all_start || boot_daemon) ? 1 : 0;
	//修改daemon参数
	snprintf(cmd,sizeof(cmd), "sed -i \"s/export DAEMON=%d/export DAEMON=%d/g\" %s", f_daemon, t_daemon, shell);
	if(system(cmd) == -1)
		FAIL("config to daemon = 1 error!");

	//启动程序
	snprintf(cmd,sizeof(cmd),"bash %s",shell);
	if(system(cmd) == -1)
		FAIL("start %s fail,shell:%s",name,shell);

	OK("boot <%s> ok",name);
	if(all_start == true)
		usleep(1000 * 1000);
}

void kill_server(char* name)
{
	if(strcmp(name,"all") == 0)
	{
		system("pkill main");
		OK("kill <%s> server...ok!",name);
		return;
	}
		
	OK("kill <%s> server...",name);

	//get pid
	FILE* f = NULL;
	int processid = 0;
	char cmd[128] = {0};
	snprintf(cmd,sizeof(cmd),"ls logs/%s*.pid | xargs cat",name);
	if((f = popen(cmd,"r")) == NULL)
		FAIL("not found logs/%s.pid file,stop fail.",name);
	if(fgets(cmd,sizeof(cmd),f) == NULL)
	{
		pclose(f);
		FAIL("get pid error,stop fail.");
	}
	else
		processid = atoi(cmd);

	snprintf(cmd,sizeof(cmd),"kill -9 %d",processid);
	if(system(cmd) == -1)
		FAIL("kill %s fail",name);

	OK("kill <%s> (%d) ok",name,processid);
}

int main(int argc, char* argv[]) 
{
	if(argc < 2)
		ShowUsage();

	bool boot_login = false,boot_game = false,boot_battle = false, stop_server = false;
	bool boot_monitor = false, boot_center = false, boot_db = false, boot_redis = false;
	bool all_start = false;
	char process_name[128] = {0};
	int opt;
	while((opt = getopt(argc,argv,"algbms:cdwhrf")) != -1)
	{
		switch(opt)
		{
			case 'h':
				ShowUsage();
				break;
			case 'a':
				boot_login = true,boot_game = true,boot_battle = true;
				boot_monitor = true, boot_center = true, boot_db = true, boot_redis = true;
				all_start = true;
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
			case 's':
				stop_server = true;
				strncpy(process_name,optarg,sizeof(process_name));
				break;
			case 'r':
				boot_redis = true;
				break;
			case 'f':
				boot_daemon = true;
				break;
			default: /* '?',':' */
				ShowUsage();
				break;
		}
	}

	if(!stop_server && !boot_login && !boot_game && !boot_battle 
		&& !boot_monitor && !boot_center && !boot_db && !boot_redis)
		ShowUsage();

	if(all_start)
	{
		char cmd[256];
		snprintf(cmd, sizeof(cmd), "pkill main");
		system(cmd);
	}
	
	if(stop_server)
		kill_server(process_name);
	if(boot_redis)
		boot_server("redis", "etc/start_redis.sh", all_start);
	if(boot_monitor)
		boot_server("monitor", "etc/start_monitor.sh", all_start);
	if(boot_battle)
		boot_server("battle", "etc/start_battle.sh", all_start);
	if(boot_center)
		boot_server("center", "etc/start_center.sh", all_start);
	if(boot_db)
		boot_server("db", "etc/start_db.sh", all_start);
	if(boot_login)
		boot_server("login", "etc/start_login.sh", all_start);
	if(boot_game)
		boot_server("game", "etc/start_game.sh", all_start);
	
    return 0;
}