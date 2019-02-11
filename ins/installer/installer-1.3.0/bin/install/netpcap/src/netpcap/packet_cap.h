/*	This class contains data structures of packet capture and functions. */

#ifndef MYPCAP_H
#define MYPCAP_H
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
#include "process.h"
#include "mempool.h"
#include "array.h"
#include "hashMath.h"
#include "hashTable.hpp"
#include "numMap.hpp"

using namespace Common;
/*callback hander for packet*/
typedef void (*callback_fun)(u_char *args,const struct pcap_pkthdr* pkthdr,const u_char* packet) ;
extern void callback(u_char *args,const struct pcap_pkthdr* pkthdr,const u_char* packet);
extern void* packet_handle(void* args);

extern int stop ;

extern const size_t SnapLen;

enum DIRECTION{
    IN = 1,
    OUT =2
};

/* ppp header, i hope ;) */
/* glanced from ethereal, it's 16 bytes, and the payload packet type is
 * in the last 2 bytes... */
struct ppp_header {
	u_int16_t dummy1;
	u_int16_t dummy2;
	u_int16_t dummy3;
	u_int16_t dummy4;
	u_int16_t dummy5;
	u_int16_t dummy6;
	u_int16_t dummy7;
	u_int16_t packettype;
};

// packet from network
struct packet{  
    struct packet* next;
	u_int16_t len;
	u_int16_t local_port;
	u_int16_t remote_port;
	enum DIRECTION direct;

    packet():next(NULL){}
    packet(struct packet* n,u_int16_t l, u_int16_t lp, u_int16_t rp ,enum DIRECTION d):next(n),len(l),local_port(lp),remote_port(rp),direct(d){}

	void* operator new(size_t )
	{
		return pool.alloc();
	}

	void operator delete(void *p, size_t )
	{
		pool.free(p);
	}
	static mempool<struct packet> &pool;
};


/*handle in libcap*/
struct HANDLE{
	pcap_t* handle;
	int linktype;
	HANDLE():handle(NULL){}
};

inline char * suAddrToStr (in6_addr addr6)
{
    char * ip6=new char[50];
	int pos=0;
	for (int i=0; i<16; i++){
        pos+=sprintf(ip6+pos,"%u,",addr6.s6_addr[i]);                     
    }
    return ip6;
}


class pcap
{
public :
	static pcap& GetInstance()
	{
		static pcap s; 
		return s; 
	}
	
    bool init(); 
	  
	/*capture packet, install callback;*/
	virtual int do_something( callback_fun func ); 
	friend void callback(u_char *args,const struct pcap_pkthdr* pkthdr,const u_char* packet);	
	
	//for test
	void test();

private:
   	pcap();
    virtual ~pcap();
	pcap& operator=(pcap& );
	pcap(const pcap& );

	/*open all network device*/
	void open_devices(map<string,int> &ifNames);						
	/*get local ip address*/
	bool get_local_ip(map<string,int> &ifNames);  

	bool IP4_contain(const struct in_addr &t);
	bool IP6_contain(const struct in6_addr &t);
	
	//存放错误信息的缓冲
    char errbuf[PCAP_ERRBUF_SIZE];
	//all the descriptions of device;
	vector<HANDLE> handles;  
	//local address infomation
	
	numMap<unsigned int,char> IP4map;
	HashTable<char *,in6_addr> IP6map;
	//vector<struct in6_addr> IP4s;
	//vector<struct in6_addr> IP6s;

	//the packet list, the captured packets are added in this list, and mutex
	pthread_mutex_t lock_packet;
 };


#endif // MYPCAP_H
