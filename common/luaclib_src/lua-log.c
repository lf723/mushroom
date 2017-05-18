// @Author: linfeng
// @Date:   2015-10-02 11:47:21
// @Last Modified by:   linfeng
// @Last Modified time: 2015-10-12 11:48:53

#include <lua.h>
#include <lauxlib.h>

#include <unistd.h>
#include <stdio.h>
#include <time.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <stdbool.h>

#include <sys/stat.h>
#include <sys/types.h>

#include <dirent.h>
#include <pthread.h>
#include <assert.h>
#include <ctype.h>

#if defined(__APPLE__)
#include <sys/time.h>
#define fwrite_unlocked fwrite
#define fflush_unlocked fflush
#endif

#define ONE_MB	(1024*1024)
#define DEFAULT_ROLL_SIZE (1024*ONE_MB)		// 日志文件达到1G，滚动一个新文件
#define DEFAULT_BASENAME "default"
#define DEFAULT_DIRNAME "."
#define DEFAULT_INTERVAL 5					// 日志同步到磁盘间隔时间

#define LOG_MAX 16*1024						// 单条LOG最长16K
//#define LOG_BUFFER_SIZE 4*1024*1024		// 一个LOG缓冲区4M
#define LOG_MESSAGE_SIZE 512				// 最大LOG消息数量
#define LOG_LEVEL_NUM	200	 				// 最多200项LOG
#define LOGGER_FNAME_LEN	64				// LOG文件名长度

static char logger_fname[LOG_LEVEL_NUM][LOGGER_FNAME_LEN];

struct buffer_message
{
	char data[LOG_MAX];
	int len;
	int loglevel;
};


struct buffer
{
	struct buffer* next;
	struct buffer_message message[LOG_MESSAGE_SIZE];
	int size;					// 缓冲区已使用字节数
};

struct buffer_list
{
	struct buffer* head;
	struct buffer* tail;
	int size;					// 缓冲区个数
};

struct logger
{
	FILE* handle[LOG_LEVEL_NUM];
	int loglevel;
	int rollsize;
	char basename[64];
	int use_basename[LOG_LEVEL_NUM];
	char dirname[LOG_LEVEL_NUM][64];
	size_t written_bytes[LOG_LEVEL_NUM];	// 已写入文件的字节数
	int roll_hour[LOG_LEVEL_NUM];			// 同struct tm中的tm_hour
	int flush_interval;		// 异步日志后端写入文件时间间隔

	struct buffer* curr_buffer;		// 当前缓冲区
	struct buffer* next_buffer;		// 备用缓冲区
	struct buffer_list buffers;		// 待写入文件的缓冲区列表

	int running;
	pthread_t thread;
	pthread_mutex_t mutex;
	pthread_cond_t cond;
} inst;


char* get_log_filename(int use_basename,const char* basename, int index, int loglevel)
{
	static char filename[128];			// 只有一个线程访问，不用担心线程安全问题
	memset(filename, 0, sizeof(filename));
	char timebuf[64];
	struct tm tm;
	time_t now = time(NULL);
	localtime_r(&now, &tm);
	strftime(timebuf, sizeof(timebuf), "%Y%m%d%H", &tm);
	if(index == 0)
	{
		if(strcmp(basename,DEFAULT_BASENAME) == 0 || use_basename == 0)
			snprintf(filename, sizeof(filename), "%s.%s.log", logger_fname[loglevel],timebuf);
		else
			snprintf(filename, sizeof(filename), "%s.%s.%s.log", basename, logger_fname[loglevel],timebuf);
	}
	else
	{
		if(strcmp(basename,DEFAULT_BASENAME) == 0 || use_basename == 0)
			snprintf(filename, sizeof(filename), "%s.%s.%d.log", logger_fname[loglevel],timebuf, index);
		else
			snprintf(filename, sizeof(filename), "%s.%s.%s.%d.log", basename, logger_fname[loglevel],timebuf, index);
	}
	
	return filename;
}

/*
size_t get_filesize(const char* path)
{
	off_t size = 0;
	struct stat statbuf;
	if (stat(path, &statbuf) == 0)
		size = statbuf.st_size;
	else
	{
		int saved_errno = errno;
		fprintf(stderr, "stat error: %s\n", strerror(saved_errno));
		exit(EXIT_FAILURE);
	}
	return size;
}*/

void rollfile(int loglevel)
{
	if (inst.handle[loglevel] != NULL && (inst.handle[loglevel] == stdin 
		|| inst.handle[loglevel] == stdout || inst.handle[loglevel] == stderr))
		return;

	if (inst.handle[loglevel] != NULL && inst.written_bytes[loglevel] > 0)
	{
		fflush(inst.handle[loglevel]);
		fclose(inst.handle[loglevel]);
	}

	char filename[128];
	// 如果不存在，创建文件夹
	DIR* dir;
	dir = opendir(inst.dirname[loglevel]);
	if (dir == NULL)
	{
		int saved_errno = errno;
		if (saved_errno == ENOENT)
		{
			if (mkdir(inst.dirname[loglevel], 0755) == -1)
			{
				saved_errno = errno;
				fprintf(stderr, "mkdir error: %s,%s\n", strerror(saved_errno),inst.dirname[loglevel]);
				inst.handle[loglevel] = stdout;
				//exit(EXIT_FAILURE);
				return;
			}
		}
		else
		{
			fprintf(stderr, "opendir error: %s,%s\n", strerror(saved_errno),inst.dirname[loglevel]);
			inst.handle[loglevel] = stdout;
			//exit(EXIT_FAILURE);
			return;
		}
	}
	else
		closedir(dir);

	int index = 0;
	while (1)
	{
		snprintf(filename, sizeof(filename), "%s/%s", inst.dirname[loglevel], 
			get_log_filename(inst.use_basename[loglevel],inst.basename, index++, loglevel));

		inst.handle[loglevel] = fopen(filename, "a+");
		if (inst.handle[loglevel] == NULL)
		{
			int saved_errno = errno;
			fprintf(stderr, "open file error: %s,%s\n", strerror(saved_errno),filename);
			inst.handle[loglevel] = stdout;
			break;
		}
		else
		{
			struct stat statbuff;
			if(stat(filename, &statbuff) >= 0)
		        inst.written_bytes[loglevel] = statbuff.st_size; 
			
			if (inst.written_bytes[loglevel] >= inst.rollsize)
			{
				// 继续滚动日志文件
				fclose(inst.handle[loglevel]);
				continue;
			}
			
			struct tm tm;
			time_t now = time(NULL);
			localtime_r(&now, &tm);
			inst.roll_hour[loglevel] = tm.tm_hour;

			break;
		}
	}

	
}

void append(const char* logline, size_t len, int loglevel, const char* logdir, int use_basename)
{
	pthread_mutex_lock(&inst.mutex);
	if(inst.dirname[loglevel][0] == 0)
	{
		strncpy(inst.dirname[loglevel],logdir,sizeof(inst.dirname[loglevel]));
		inst.use_basename[loglevel] = use_basename;
	}

	bool notify = false;
	int msg_size = inst.curr_buffer->size;
	if (msg_size + 1 >= LOG_MESSAGE_SIZE)
	{
		notify = true;
		// 当前缓冲区已满，将当前缓冲区添加到待写入文件缓冲区列表
		if (!inst.buffers.head)
		{
			assert(inst.buffers.tail == NULL);
			inst.buffers.head = inst.curr_buffer;
			inst.buffers.tail = inst.curr_buffer;
		}
		else
		{
			inst.buffers.tail->next = inst.curr_buffer;
			inst.buffers.tail = inst.curr_buffer;
		}

		inst.buffers.size++;
		assert(inst.buffers.tail->next == NULL);
		
		// 将预备缓冲区设置为当前缓冲区
		if (inst.next_buffer)
		{
			inst.curr_buffer->next = inst.next_buffer;
			inst.curr_buffer = inst.next_buffer;
			inst.next_buffer = NULL;
		}
		else
		{
			// 这种情况，极少发生，前端写入速度太快，一下子把两块缓冲区都写完，
			// 那么，只好分配一块新的缓冲区。
			struct buffer* newbuf = (struct buffer*)calloc(1, sizeof(struct buffer));
			if(!newbuf) //内存分配不成功,放弃这次log写入,下个log还会继续calloc
			{
				pthread_mutex_unlock(&inst.mutex);
				return;
			}
			inst.curr_buffer->next = newbuf;
			inst.curr_buffer = newbuf;
		}

		msg_size = 0;
	}

	memcpy(inst.curr_buffer->message[msg_size].data , logline, len);
	inst.curr_buffer->message[msg_size].loglevel = loglevel;
	inst.curr_buffer->message[msg_size].len = len;
	inst.curr_buffer->size = msg_size + 1;

	if(notify)
		pthread_cond_signal(&inst.cond);	// 通知后端开始写入日志

	pthread_mutex_unlock(&inst.mutex);
}

// 日志线程处理函数
static inline void* worker_func(void* p)
{
#if !defined(__APPLE__)
	struct timespec ts;
#else
	struct timeval ts;
#endif
	struct buffer_list buffers_to_write;
	memset(&buffers_to_write, 0, sizeof(buffers_to_write));
	// 准备两块空闲缓冲区
	struct buffer* new_buffer1 = (struct buffer*)calloc(1, sizeof(struct buffer));
	struct buffer* new_buffer2 = (struct buffer*)calloc(1, sizeof(struct buffer));
	while (inst.running)
	{
		assert(buffers_to_write.head == NULL);
		assert(new_buffer1->size == 0);
		assert(new_buffer2->size == 0);

		pthread_mutex_lock(&inst.mutex);
		if (inst.buffers.head == NULL)
		{
#if !defined(__APPLE__)
			clock_gettime(CLOCK_REALTIME, &ts);
#else
			struct timeval tv;
			gettimeofday(&tv, NULL);
			ts.tv_sec = tv.tv_sec;
			ts.tv_nsec = tv.tv_usec * 1000; //tv.tv_usec  微秒    ts.tv_nsec  纳秒
#endif
	    	ts.tv_sec += inst.flush_interval;
			pthread_cond_timedwait(&inst.cond, &inst.mutex, &ts);
		}

		// 将当前缓冲区移入buffers
		if (!inst.buffers.head)
		{
			inst.buffers.head = inst.curr_buffer;
			inst.buffers.tail = inst.curr_buffer;
		}
		else
			inst.buffers.tail = inst.curr_buffer;
		inst.buffers.size += 1;

		inst.curr_buffer = new_buffer1;				// 将空闲的newBuffer1置为当前缓冲区
		new_buffer1 = NULL;

		// buffers与buffers_to_write交换，
		// 这样后面的代码可以在临界区之外安全地访问buffers_to_write
		buffers_to_write.head = inst.buffers.head;
		buffers_to_write.tail = inst.buffers.tail;
		buffers_to_write.size = inst.buffers.size;
		inst.buffers.head = 0;
		inst.buffers.tail = 0;
		inst.buffers.size = 0;

		if (!inst.next_buffer)
		{
			// 确保前端始终有一个预备buffer可供调配，
			// 减少前端临界区分配内存的概率，缩短前端临界区长度。
			inst.next_buffer = new_buffer2;
			new_buffer2 = NULL;
		}

		pthread_mutex_unlock(&inst.mutex);

		assert(buffers_to_write.size > 0);

		struct tm tm;
		time_t now = time(NULL);
		localtime_r(&now, &tm);

		if (buffers_to_write.size > 25)
		{
			/*
			char timebuf[64];
			strftime(timebuf, sizeof(timebuf), "%Y-%m-%d %H:%M:%S", &tm);

			char buf[256];
			snprintf(buf, sizeof(buf), "Dropped log messages at %s, %d larger buffers\n",
				timebuf, buffers_to_write.size-2);
			fprintf(stderr, "%s", buf);

			pthread_mutex_lock(&inst.mutex); //这里需要lock,上面已经unlock
			append(buf, strlen(buf),200); //写入前端
			pthread_mutex_unlock(&inst.mutex);
			*/

			// 丢掉多余日志，以腾出内存，仅保留两块缓冲区
			struct buffer* new_tail = buffers_to_write.head->next;
			struct buffer* node = new_tail->next;
			while (node != NULL)
			{
				struct buffer* p = node;
				node = node->next;
				free(p);
			}
			buffers_to_write.tail = new_tail;
			buffers_to_write.tail->next = NULL;
			buffers_to_write.size = 2;
		}

		struct buffer* node;
		
		int need_flush[LOG_LEVEL_NUM];
		memset(need_flush,0,sizeof(need_flush));
		
		for (node = buffers_to_write.head; node != NULL; node = node->next)
		{
			for(int i = 0; i < node->size; i++)
			{
				if(!inst.handle[node->message[i].loglevel])
				{
					rollfile(node->message[i].loglevel); 	//第一次写入,创建文件
				}
				if (inst.handle[node->message[i].loglevel])
				{
					fwrite_unlocked(node->message[i].data, 1, node->message[i].len, inst.handle[node->message[i].loglevel]);
					
					inst.written_bytes[node->message[i].loglevel] += node->size;
					need_flush[node->message[i].loglevel] = 1;
				}
			}
			
		}

		
		for(int i = 0; i < LOG_LEVEL_NUM; i++)
		{
			if(need_flush[i] == 1)
			{
				fflush(inst.handle[i]);
				if (inst.written_bytes[i] > inst.rollsize)
				{
					rollfile(i); //超出一个文件大小,滚动日志
				}
			}

			// 新的一小时，滚动日志
			if (inst.roll_hour[i] >= 0 && inst.roll_hour[i] != tm.tm_hour)
			{
				rollfile(i);
			}
		}


		if (!new_buffer1) //always true
		{
			assert(buffers_to_write.size > 0);
			new_buffer1 = buffers_to_write.head;
			buffers_to_write.head = buffers_to_write.head->next;
			memset(new_buffer1, 0, sizeof(struct buffer));
			buffers_to_write.size -= 1;
		}

		if (!new_buffer2)
		{
			assert(buffers_to_write.size > 0);
			new_buffer2 = buffers_to_write.head;
			buffers_to_write.head = buffers_to_write.head->next;
			memset(new_buffer2, 0, sizeof(struct buffer));
			buffers_to_write.size -= 1;
		}

		// 清除buffers_to_write
		node = buffers_to_write.head;
		while (node != NULL)
		{
			struct buffer* p = node;
			node = node->next;
			free(p);
		}

		buffers_to_write.head = 0;
		buffers_to_write.tail = 0;
		buffers_to_write.size = 0;

	}

	for(int i = 0; i < LOG_LEVEL_NUM; i++)
		if(inst.handle[i])
			fflush(inst.handle[i]);

	return NULL;
}

static void log_exit()
{
	inst.running = 0;
	pthread_join(inst.thread, NULL);
	pthread_mutex_destroy(&inst.mutex);
	pthread_cond_destroy(&inst.cond);
	for(int i = 0; i < LOG_LEVEL_NUM; i++)
		if (inst.handle[i])
			fclose(inst.handle[i]);
}

int linit(lua_State *L)
{
	memset(&inst, 0, sizeof(inst));
	inst.loglevel = lua_tointeger(L, 1);
	inst.rollsize = lua_tointeger(L, 2);
	inst.flush_interval = lua_tointeger(L, 3);
	inst.rollsize = inst.rollsize > 0 ? inst.rollsize * ONE_MB : DEFAULT_ROLL_SIZE;
	inst.flush_interval = inst.flush_interval > 0 ? inst.flush_interval : DEFAULT_INTERVAL;
	inst.curr_buffer = (struct buffer*)calloc(1, sizeof(struct buffer));
	inst.next_buffer = (struct buffer*)calloc(1, sizeof(struct buffer));

	for(int i = 0; i < LOG_LEVEL_NUM; i++)
	{
		inst.handle[i] = NULL;
		inst.roll_hour[i] = -1;
	}

	const char *basename = lua_tolstring(L, 4, NULL);
	if (basename == NULL)
		strncpy(inst.basename, DEFAULT_BASENAME, sizeof(inst.basename));
	else
		strncpy(inst.basename, basename, sizeof(inst.basename));

	if (pthread_mutex_init(&inst.mutex, NULL) != 0)
	{
		int saved_errno = errno;
		fprintf(stderr, "pthread_mutex_init error: %s\n", strerror(saved_errno));
		exit(EXIT_FAILURE);
	}
	if (pthread_cond_init(&inst.cond, NULL) != 0)
	{
		int saved_errno = errno;
		fprintf(stderr, "pthread_cond_init error: %s\n", strerror(saved_errno));
		exit(EXIT_FAILURE);
	}

	inst.running = 1;
	if (pthread_create(&inst.thread, NULL, worker_func, NULL) != 0)
	{
		int saved_errno = errno;
		fprintf(stderr, "pthread_create error: %s\n", strerror(saved_errno));
		exit(EXIT_FAILURE);
	}

	return 0;
}

int lexit(lua_State *L)
{	
	log_exit();
	return 0;
}

int lwrite(lua_State *L)
{
	int loglevel = (int)lua_tointeger(L,1);
	char* prefix = (char*)lua_tolstring(L, 2, NULL);
	char* data = (char*)lua_tolstring(L, 3, NULL);
	char* dir = (char*)lua_tolstring(L, 4, NULL);
	int basename = (int)lua_toboolean(L, 5);

	if (data == NULL || prefix == NULL || dir == NULL)
		return 0;
	if(inst.loglevel <= loglevel)
	{
		if(strcmp(logger_fname[loglevel],"") == 0)
			strncpy(logger_fname[loglevel],prefix,LOGGER_FNAME_LEN);
		char msg[LOG_MAX];
		snprintf(msg, sizeof(msg), "%s\n", data);
		append(msg, strlen(msg), loglevel, dir, basename);
	}

	return 0;
}

int luaopen_log_core(lua_State *L)
{
	luaL_checkversion(L);
	luaL_Reg l[] =
	{
		{ "init", linit },
		{ "exit", lexit },
		{ "write", lwrite },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);

	return 1;
}
