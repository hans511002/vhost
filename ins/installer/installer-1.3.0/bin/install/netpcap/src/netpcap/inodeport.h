/*
	This class matains a map from inode to port, which used to construct relation between process and port.
*/

#ifndef CONNECTION
#define CONNECTION
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
extern struct statisticInfo statis;
extern struct configure conf;

using namespace Common;

class inodeport{
	inodeport():inode_port(0),inode_port_tmp(0){
		pthread_mutex_init(&lock_inode,NULL);
	}
	~inodeport(){
		pthread_mutex_destroy(&lock_inode);
		if(inode_port){
			inode_port->clear();
			delete inode_port;
			inode_port=NULL;
		}
	}
	inodeport& operator=(inodeport&);
	inodeport(const inodeport& p);
	/*map from inode to port*/
	//std::map <unsigned long, unsigned short> inode_port;  
	numMap<unsigned long, unsigned short> * inode_port;
	numMap<unsigned long, unsigned short> * inode_port_tmp;
	void add_inodeport (char * buffer);
	int add_procinfo (const char * filename);
	
	pthread_mutex_t lock_inode;

public:
	static inodeport& GetInstance(){static inodeport s; return s;}
	void refreshinodeport();

	unsigned short get_port_by_inode(unsigned long a){
	    unsigned short port=0;
        pthread_mutex_lock(&lock_inode);
        bool res=inode_port->find(a,port);
        pthread_mutex_unlock(&lock_inode);
		if(res)
			return port;
		else 
			return 0;
	}
	void test();
private:

};



#endif
