#ifndef _CONFIG_H
#define _CONFIG_H

#define	U_64		unsigned long long

#define LEN_32		32
#define LEN_64		64
#define LEN_128		128
#define LEN_256		256
#define LEN_512		512
#define LEN_1024	1024
#define LEN_4096	4096

#define PID_MAX_FILE "/proc/sys/kernel/pid_max"
extern int PID_MAX;

struct statisticInfo
{
	time_t	st_time;
    time_t	cur_time;
    int cur_socket_num;
    int cur_pro_num;
    int inited;
};

struct configure
{
	int fileNum;
    int fileSize;
	unsigned char 	running_mode;	/* running mode */
	unsigned char 	debug_level;
	unsigned char 	print_interval;		 /* how many seconds will escape every print interval */
	unsigned char  includeProName;
	unsigned char  printOrder;
    unsigned char outputPortNetInfo;
	char output_file_path[LEN_256];
};

enum {
	RUN_NULL,
	RUN_SERV,
	RUN_LIVE,
	RUN_PRINT
};

typedef enum
{
	LOG_DEBUG,
	LOG_INFO,
	LOG_WARN,
	LOG_ERROR,
	LOG_FATAL
} log_level_t;


void do_debug(log_level_t level, const char *fmt, ...);

#endif
