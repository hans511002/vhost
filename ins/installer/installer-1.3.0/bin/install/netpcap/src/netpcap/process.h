#ifndef PROCESS_H
#define PROCESS_H

#include <stdint.h>
#include <iostream>
#include <pcap.h>
#include <netinet/ether.h>
#include <netinet/ip.h>
#include <netinet/ip6.h>
#include <netinet/tcp.h>
#include <netinet/udp.h>
#include <stdlib.h>
#include <unistd.h>
#include <linux/types.h>
#include <string.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <net/if.h>
#include <ifaddrs.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <sys/ioctl.h>
#include <vector>
#include <map>
#include <pthread.h>
#include<vector>
#include<list>
using namespace std;
#include "config.h"
#include "mempool.h"
#include "array.h"
#include "hashMath.h"
#include "hashTable.hpp"
#include "numMap.hpp" 
using namespace Common;

// typedef unsigned long long int uint64_t ;

extern struct statisticInfo statis;
extern struct configure conf;
extern void set_debug_level(char    *token);

struct connection
{
    u_int16_t remote_port ;
    u_int16_t local_port;
};                           //记录进程的连接的实例


struct processPort{
    int port;
    uint64_t  total_in;
    uint64_t  total_out;
    processPort():port(0),total_in(0),total_out(0){}
    processPort(int p):port(p),total_in(0),total_out(0){
    }
};


extern void clearProcess(void * p);
extern void clearProcessPort(void * p);

struct process
{
    int pid;
    uint64_t  total_in;
    uint64_t  total_out;
    uint64_t  last_in;
    uint64_t  last_out;
   	time_t	st_time;
    uint64_t  rate_in;
    uint64_t  rate_out;
    uint64_t start_code;
   	
    char *name;
    map<unsigned short, struct processPort> proPort;

    pthread_mutex_t lock_process;

    process(int p,char* n):pid(p),total_in(0),total_out(0),last_in(0),last_out(0),name(n){
    	pthread_mutex_init(&lock_process,NULL);
    	st_time = time(NULL);
		if(n){
			name = n;
		}else{
			name = NULL;
		}
		pid =  p;
	}	
    ~process(){
		if(name){
		    delete []name;
		    name=NULL;
		}
		proPort.clear();
		pthread_mutex_destroy(&lock_process);
	}
};   // 标志每个有网络链接的进程



class process_manager
{
public:
	/*flush info of all process, construct all process has sockets,create the map from port to process,*/
    void reflush_process(class inodeport&);
	/*single instance*/
    static process_manager& GetInstance(){ static class process_manager s; return s;}
	/*return map of pid_process*/	
	void calc_process_rate();// traffic
	/*flush the packet infomation into process*/
    void test(class inodeport& );
    friend void callback(u_char *args,const struct pcap_pkthdr* pkthdr,const u_char* packet);	
 
	uint64_t lenin;
	uint64_t lenout;
	
	vector<struct process *> & getProcess(){
	    calc_process_rate();
	    return pres;
	}

private:	
    ~process_manager();
    process_manager();
	process_manager& operator=(process_manager&); //disallowed
	process_manager(const process_manager&);//disallowed
	
	//get name of process by pid
	void get_process_handlers(process * proc);
    char* get_process_name(int pid); 
	void get_info_for_pid(char * pid , class inodeport&); 
	void get_info_by_linkname ( char *pid,uint64_t start_code, char* linkname, class inodeport&);
	
	/*pid to process*/
	map<unsigned int,struct process* > pids;
	/*port to pid*/
 	numMap<unsigned short,unsigned int> portMap;
 	numMap<unsigned int, struct process* > lastpPidProcess;
 	numMap<unsigned short, struct process* > portprocess;
    pthread_mutex_t lock_manager;

	vector<struct process *> pres;

	// map<unsigned short, int> portpid;
	/*port to process*/
	// map<unsigned short, struct process* >portprocess; 

};

#endif // PROCESS_H
