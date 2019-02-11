#include "packet_cap.h"

const size_t SnapLen = max(sizeof(ppp_header),sizeof(ethhdr) ) + max(sizeof(ip6_hdr),sizeof(ip)) + max(sizeof(tcphdr),sizeof(udphdr));

mempool<struct packet>& packet::pool = mempool<struct packet>::GetInstance();
 int stop = 0;

/*thread handle for capture packet*/
 void* packet_handle(void* args)
{
	class pcap& Packet_instance = pcap::GetInstance();
	Packet_instance.init();
	while(!stop){
	    usleep(100);
	              //  cout<<"In packet_handle"<<endl;
		Packet_instance.do_something(callback);
		            //cout<<"In packet_handle"<<endl;

	}
	return (void*)(0);
}

/*what we want to do when a packet arrives,  we need pay attention to the network byte order and host byte order*/
void callback(u_char *args,const struct pcap_pkthdr* pkthdr,const u_char* packet)
{
    try
    {
        //cout<<"In callback"<<endl;
    	int linktype;     //data link type
    	u_int16_t IPtype;   //ip layer type
    	u_int8_t Transfer_p;	 //transfer layer type
    	u_char* buf;            //buf  to captured data
    	int direction = 0;     // packet in or out
    	u_int16_t len;    // payload of the packet
    
    	struct ethhdr *ethernet;
    	struct ppp_header *ppp;
    	struct ip * ip;
    	struct ip6_hdr * ip6;
    	struct packet *list_packet;
    	pcap& instance = pcap::GetInstance();
    	linktype = *(int*)args; 
    	//parse data link layer
    	switch (linktype)
    	{
    		case DLT_EN10MB:
    			ethernet = (struct ethhdr *)packet;
    			IPtype = ethernet->h_proto;
    			buf =  (u_char*)packet + sizeof(struct ethhdr);
    			break;
    		case DLT_PPP:
    			ppp = (struct ppp_header *) packet;
    			IPtype = ppp->packettype;
    			buf =  (u_char*)packet + sizeof(struct ppp_header);
    			break;
    		default:
    			//fprintf(stdout, "Unknown linktype %d", linktype);
    			return ;
    	}
    
    	//parse ip layer
    	switch (IPtype){
    		case (0x0008):  //ipv4
    			ip = (struct ip *) buf;
    			Transfer_p = ip->ip_p;
    			buf = buf + sizeof(struct ip);
    
    			if( instance.IP4_contain(ip->ip_src) )
    				direction = OUT;
    			else if( instance.IP4_contain(ip->ip_dst) )
    				direction = IN;
    			else
     				return;
    			len = ntohs(ip->ip_len);
    			break;
    		case (0xDD86): //ipv6
    			ip6 = (struct ip6_hdr *) buf;
    			Transfer_p = (ip6->ip6_ctlun).ip6_un1.ip6_un1_nxt;
    			buf = buf + sizeof(struct ip6_hdr);
    			if( instance.IP6_contain(ip6->ip6_src) )
    				direction = OUT;
    			else if( instance.IP6_contain(ip6->ip6_dst) )
    				direction = IN;
    			else
    				return;
    			len = ntohs(ip6->ip6_ctlun.ip6_un1.ip6_un1_plen);
    			break;
    		default:
    			// TODO: maybe support for other protocols apart from IPv4 and IPv6
    			return ;
    	}
    
    	/*statistic*/
    	if(IPPROTO_TCP == Transfer_p){
    		tcphdr *tcp = (tcphdr*)buf; 
     		// add calc
		    class process_manager &manager = process_manager::GetInstance(); 
	        short int localPort=0;
	        short int remotePort=0;
            if(IN==direction){
                localPort=ntohs(tcp->dest);
                remotePort=ntohs(tcp->source);
                manager.lenin+=len;
            }else if(OUT==direction){
                localPort=ntohs(tcp->source);
                remotePort=ntohs(tcp->dest);
                manager.lenout+=len;
            }
            process * proc=NULL;
            if(manager.portprocess.find(localPort,proc) && proc!=NULL){
                pthread_mutex_lock(&proc->lock_process);
                if(IN==direction){
                    proc->total_in+=len;
                    proc->proPort[localPort].total_in+=len;
                }else if(OUT==direction){
                    proc->total_out+=len;
                    proc->proPort[localPort].total_out+=len;
                }
                pthread_mutex_unlock(&proc->lock_process);
            }
    	}
    }
    catch (...)
    {
        // error handling
    }
}

 

pcap::pcap():IP4map(11),IP6map(11) 
{
	pthread_mutex_init(&lock_packet,NULL);
}

pcap::~pcap()
{
	for(unsigned int i=0;i<handles.size();i++)
	{
		if(handles[i].handle)
			pcap_close(handles[i].handle);
	}
	pthread_mutex_destroy(&lock_packet);
}

 



bool pcap::init()
{
	map<string,int> ifNames;
	bool getIp=get_local_ip(ifNames);
	if(getIp){
		open_devices(ifNames);
		statis.inited=1;
	}
	return getIp;
}


void pcap::open_devices(map<string,int> &ifNames)
{
	int res;
	pcap_if_t *it,*tmp;
	pcap_t *handle;
	this->handles.clear();
	res=pcap_findalldevs(&it,errbuf);

	if(res < 0){
		do_debug(LOG_ERROR, "Find devs err : %s\n",errbuf);
		exit(-1);
	}
	tmp = it;
	while(tmp)
	{
		if(strcmp("any",tmp->name)==0 || strcmp("nflog",tmp->name)==0 || strcmp("nfqueue",tmp->name)==0 || strcmp("lo",tmp->name)==0
			|| ifNames.find(tmp->name)==ifNames.end())
		{
			tmp = tmp->next;
			continue;
		}
		do_debug(LOG_INFO, "dev name : %s\n",tmp->name);
		handle = pcap_open_live(tmp->name, SnapLen, 0, 100, errbuf);
		//handle = pcap_open_live(tmp->name, SnapLen, 0, 100, errbuf);
	 	if (handle == NULL) {
			//fprintf(stderr, "Couldn't open device %s: %s\n", tmp->name, errbuf);
	 	}else{
 			//if(pcap_setnonblock(handle,1,errbuf) <0)
				//fprintf(stderr, "Couldn't setnonblock %s\n",  errbuf);
	        struct HANDLE h;
			h.handle = handle;
		    h.linktype = pcap_datalink(handle);
		    if(h.linktype==DLT_EN10MB || h.linktype== DLT_PPP){
		        handles.push_back(h);
		    }else{
		        pcap_close(handle);
		    }
			//cout<<handle<<endl;
		}
		tmp = tmp->next;
	}
	pcap_freealldevs(it);
}


int pcap::do_something( callback_fun func )
{
    try
    {
   // cout<<"In pcap::do_something handles.size()="<<handles.size()<<endl;

      unsigned int i;
	int res;
	for(i=0; i<handles.size(); i++)
	{
        //cout<<" handles["<<i<<"].linktype="<<handles[i].linktype<<endl;
        if (handles[i].linktype==220)
        {
            continue;
           // cout<<" handles["<<i<<"].linktype="<<handles[i].linktype<<endl;
        }
		/*which handler is better, loop or dispatch ? */
		res = pcap_dispatch(handles[i].handle, -1,func, (u_char*)&handles[i].linktype);
		//res = pcap_dispatch(handles[i].handle, 1,func, (u_char*)&handles[i].linktype);
		//res = pcap_loop(handles[i].handle, 0,func, (u_char*)&handles[i].linktype);
		if( res != 0)
		{
		    //res = pcap_loop(handles[i].handle, 0,func, (u_char*)&handles[i].linktype);
			//cout<<"Dispatch error :"<<i<<pcap_geterr(handles[i].handle)<<endl;
			//return res;
		}else{
			//cout<<"Success handle "<<res<<endl;
		}

	}
            //cout<<"end pcap::do_something"<<endl;

	return handles.size();
    }
    catch (... )
    {
        // error handling
    }

}

bool pcap::get_local_ip(map<string,int> &ifNames)
{
	struct ifaddrs *ifaddr, *ifa;
 	if (getifaddrs(&ifaddr) == -1) {
		do_debug(LOG_ERROR, "Err in getifaddrs\n");
       	return false;
   	}
	for (ifa = ifaddr; ifa != NULL; ifa = ifa->ifa_next){
        if (ifa->ifa_addr == NULL)
            continue;
        if(strcmp("any",ifa->ifa_name)==0 || strcmp("nflog",ifa->ifa_name)==0 || strcmp("nfqueue",ifa->ifa_name)==0 || strcmp("lo",ifa->ifa_name)==0){
			continue;
		}
		switch (ifa->ifa_addr->sa_family){
			case (AF_INET):
				struct in_addr addr;
        		addr = ((struct sockaddr_in*)ifa->ifa_addr)->sin_addr;
				//IP4s.push_back(addr);
				IP4map.addNode(addr.s_addr,1);
				ifNames[ifa->ifa_name]=1;
				break;
			case (AF_INET6):
				struct in6_addr addr6;
				addr6 = ((struct sockaddr_in6	*)ifa->ifa_addr)->sin6_addr;
				//IP6s.push_back(addr6);
				IP6map.addNode(suAddrToStr(addr6),addr6);
				ifNames[ifa->ifa_name]=1;
				break;
			default:
				break;
		}
	}
	freeifaddrs(ifaddr);
    return true;
}

// Is a address in our local addresses?
bool pcap::IP4_contain(const struct in_addr &t)
{
    if(IP4map.contain(t.s_addr)){
      return true;  
    }
	return false;
	//for(unsigned int i=0; i<IP4s.size();i++)
	//	if(IP4s[i].s_addr == t.s_addr)
	//		return true;
	//return false;
}

// Is a address in our local addresses?
bool pcap::IP6_contain(const struct in6_addr &t)
{
    struct in6_addr addr6;
    if(IP6map.find(suAddrToStr(addr6),addr6)){
        if( memcmp(t.s6_addr, addr6.s6_addr, sizeof(struct in6_addr))==0 )
			return true;
    }
    return false;
	//for(unsigned int i=0; i<IP6s.size();i++)
	//	if( memcmp(t.s6_addr, IP6s[i].s6_addr, sizeof(struct in6_addr))==0 )
	//		return true;
	//return false;
}


void pcap::test()
{
	init();
	while(1)
	{
		sleep(1);
		do_something(NULL);
	}

}
