#include <string.h>
#include <iostream>
#include <dirent.h>
#include <unistd.h>
#include <fcntl.h> 
#include <string>
#include <algorithm>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include <time.h>
#include <dlfcn.h>
#include <errno.h>
#include <signal.h>
#include <getopt.h>
#include <ctype.h>
#include <sys/stat.h>
#include "config.h"
#include "inodeport.h"
#include "process.h"
#include "packet_cap.h"

struct statisticInfo statis;
struct configure conf;

using namespace std;
void do_debug(log_level_t level, const char *fmt, ...)
{
	//FIXME
	if (level >= conf.debug_level) {
		va_list	argp;
		time_t	timep=time(NULL);
		//unsigned long tp=timep;
	    //vfprintf(stderr, "%ld ", tp);
		
		va_start(argp, fmt);
		vfprintf(stderr, fmt, argp);
		fflush(stderr);
		va_end(argp);
	}
	//if (level == LOG_FATAL)
	//	exit(1);
}
void clearProcess(void * p){
    process ** pro=(process **)p;
    process * proc=*pro;
    delete proc;
}
void clearProcessPort(void * p){
    processPort ** pro=(processPort **)p;
    processPort * proc=*pro;
    delete proc;
}
void set_debug_level(char    *token)
{
	if(token){
		if (!strcmp(token,"INFO")||!strcmp(token,"info")||!strcmp(token,"i"))
			conf.debug_level = LOG_INFO;
		else if (!strcmp(token,"WARN") || !strcmp(token,"warn") || !strcmp(token,"w"))
			conf.debug_level = LOG_WARN;
		else if (!strcmp(token,"DEBUG")||!strcmp(token,"debug")||!strcmp(token,"d"))
			conf.debug_level = LOG_DEBUG;
		else if (!strcmp(token,"ERROR")||!strcmp(token,"error")||!strcmp(token,"e"))
			conf.debug_level = LOG_ERROR;
		else if (!strcmp(token,"FATAL")||!strcmp(token,"fatal")||!strcmp(token,"f"))
			conf.debug_level = LOG_FATAL;
		else
			conf.debug_level = LOG_ERROR;
	}else{	
		conf.debug_level = LOG_ERROR;
    }
}
unsigned long str2ulong (char * ptr) {//辅助函数
	unsigned long retval = 0;

	while ((*ptr >= '0') && (*ptr <= '9')) {
		retval *= 10;
		retval += *ptr - '0';
		ptr++;
	}
	return retval;
}

bool isdigit(const char *name) //辅助函数
{
	size_t i =0;
	char l;
	while( (l=name[i]) != '\0')
	{
		if( l<'0' || l>'9')
			return false;
		i++;
	}
	return true;
}

char* itoa(int i) //辅助函数
{
	static char buf[10];
	int pos=0;
	memset(buf,0,10);
	while(i>0)
	{
		buf[pos++] = '0'+i%10;
		i /= 10;
	}
	i=0;pos--;
	while(i<pos)
	{char c=buf[i];buf[i]=buf[pos];buf[pos]=c;i++;pos--;}
	return buf;
}

process_manager::process_manager():lenin(0),lenout(0),portMap(65535),lastpPidProcess(PID_MAX),portprocess(65535){
	pthread_mutex_init(&lock_manager,NULL);
}

process_manager::~process_manager(){
    pthread_mutex_destroy(&lock_manager);
}


/*reflush the infomation of all process which has created socket*/
void process_manager::reflush_process(class inodeport& inodeport)  
{
    pthread_mutex_lock(&lock_manager);
    pids.clear();
    portMap.clear();
    DIR* open_process=opendir("/proc");
    struct dirent *h;
    while(NULL!=(h=readdir(open_process))){
        if(strcmp(h->d_name,".")==0 || strcmp(h->d_name,".." )==0){
            continue;
        }
        if( isdigit(h->d_name)){
            get_info_for_pid( h->d_name , inodeport);  //handle one process
        }
    }
    closedir(open_process);
    portMap.clear();
    pthread_mutex_unlock(&lock_manager);
}


/*read the process name by pid  in /proc/pid/cmdline*/
char* process_manager::get_process_name(int pid) {
  	int bufsize = 512;
	char buffer[512];
	char filename[512];
	int len=snprintf (filename, 512, "/proc/%d/cmdline", pid);
	filename[len]=0;
	int fd = open(filename, O_RDONLY);
	if (fd < 0) { 
		exit(3);
		return NULL;
	}
	int length = read (fd, buffer, bufsize);
	if (close (fd)) { 
		exit(34);
	} 
	if (length < bufsize - 1)
		buffer[length]='\0';
	char * retval = buffer;
	return strdup(retval);
}

/*collect information of one process by read /proc/pid/fd/*/
void process_manager::get_info_for_pid(char * pid, class inodeport& inodeport) {
	size_t dirlen = 10 + strlen(pid);
	//char * dirname = (char *) malloc (dirlen * sizeof(char));
	char dirname[128];
	snprintf(dirname, dirlen, "/proc/%s/fd", pid);
	//std::cout << "Getting info for pid " << pid << std::endl;
	DIR * dir = opendir(dirname);
	if (!dir){
		//std::cout << "Couldn't open dir " << dirname << ": "<< "\n";
		//free (dirname);
		return;
	}
    uint64_t start_code=0;
	char statFile[128];
    snprintf(statFile, dirlen+2, "/proc/%s/stat", pid);
    FILE * pidstat = fopen (statFile, "r");
	char buffer[512];
	if (pidstat == NULL)
		return;
	if (fgets(buffer, sizeof(buffer), pidstat)){
	    int ipid=atol(buffer);
        if(ipid==atol(pid)){
            char * scode=buffer;
            char * cols[100];
            int colLen=0;
            cols[colLen]=scode;
            while(*scode){
                if(*scode==' '){
                    *scode=0;
                    colLen++;
                    scode++;
                    cols[colLen]=scode;
                }else{
                    scode++;
                }
            }
            start_code=atoll(cols[21]);//start_time
            if(start_code==0){
                start_code=atoll(cols[25]);//start_time
            }
           // int index=0;
           // for (index=0; index<colLen; index++){
           //     //18446744073709551615llu
           //     int cl=strlen(cols[index]);
           //     uint64_t llumx=(uint64_t)atoll(cols[index]);
           //     //std::cout << "cl=" << cl<<" cols["<<index<<"]="<<cols[index]<<" llumx=" <<llumx<< std::endl;
           //     if(strlen(cols[index])>=20 &&  (llumx== -1 || llumx==9223372036854775807llu)){
           //         index++;
           //         break;
           //     }
           // }
            //if(index<colLen){
            //    start_code=atoll(cols[index]);
            //}
        }
	}
	fclose(pidstat);
	//std::cout << "Getting info for pid " << pid<<" " <<start_code<< std::endl;
	     
	if(start_code==0){
	    return;
	}
	/* walk through /proc/%s/fd/... */
	dirent * entry;
	while ((entry = readdir(dir))) {
		if (entry->d_type != DT_LNK)
			continue;
		//std::cout << "Looking at: " << entry->d_name << std::endl;

		int fromlen = dirlen + strlen(entry->d_name) + 1;
		char * fromname = (char *) malloc (fromlen * sizeof(char));
		snprintf (fromname, fromlen, "%s/%s", dirname, entry->d_name);

		//std::cout << "Linking from: " << fromname << std::endl;

		int linklen = 80;
		char linkname[linklen];
		int usedlen = readlink(fromname, linkname, linklen-1);
		if (usedlen == -1){
			free (fromname);
			continue;
		}
		//assert (usedlen < linklen);
		linkname[usedlen] = '\0';
		//std::cout << "Linking to: " << linkname << std::endl;
		get_info_by_linkname (pid,start_code, linkname , inodeport);
		free (fromname);
	}
	closedir(dir);
	//free (dirname);
}
void process_manager::get_process_handlers(process * proc) {
    
}
/*read information in /proc/pid/fd/.  ,thus we know whether this process has created socket and the inode of socket*/
void process_manager::get_info_by_linkname (char * pid,uint64_t start_code, char * linkname, class inodeport& inodeport) {  
	if (strncmp(linkname, "socket:[", 8) == 0) {
		char * ptr = linkname + 8;
		unsigned long inode = str2ulong(ptr);
		unsigned short port; 
		if( (port=inodeport.get_port_by_inode(inode) )!=0){// only port  ip:port
		    int p = atoi(pid);
		    if(portMap.contain(port)){
		        return;
		    }
		    bool pidExists=pids.find(p)!=pids.end();
		    portMap[port]=p;
		    struct process* proc=NULL;
		    struct process* portPproc=NULL;
		    bool pidProFlag=lastpPidProcess.find(p,proc); 
		    bool portProFlag=portprocess.find(port,portPproc); // ip:port
		    //cout<<"pid "<<pid<<"="<<pidProFlag <<" port "<<port<<"="<<portProFlag <<" portPproc="<<portPproc <<" proc="<<proc <<endl;
		    bool portReUse=(portProFlag && portPproc!=proc);
		    // 如何判断端口及进程ID 复用 
	        if(pidProFlag ){
	            if(proc->start_code!=start_code)
                {
 		            map<unsigned short, struct processPort >::iterator it; 
                	for(it=proc->proPort.begin();it!=proc->proPort.end();it++){
             	        portprocess.remove(it->first);
                 	}
                    pthread_mutex_lock(&proc->lock_process);
                    pthread_mutex_unlock(&proc->lock_process);
		            delete proc;
		            proc=NULL;
                }
	        }
	        if(proc==NULL){
	            char * pname=NULL;
		        if(conf.includeProName){
		            pname=get_process_name(p);
		        }
		        // cout<<"pid "<<pid<<"="<<pidProFlag <<" port "<<port<<"="<<portProFlag <<" portPproc="<<portPproc <<" proc="<<proc <<endl;
		        proc=new process(p,pname);
		        proc->start_code=start_code;
		        pids[p]=(proc);
		        lastpPidProcess[p]=proc;
		        portprocess[port]=proc;
		        processPort pport(port);
		        proc->proPort[port]=pport;
		        get_process_handlers(proc);
	        }else{
	            if(!pidExists)pids[p]=(proc);
	            portprocess[port]=proc;
	            pthread_mutex_lock(&proc->lock_process);
 	            if(proc->proPort.find(port)==proc->proPort.end()){ 
 	                processPort pport(port);
		            proc->proPort[port]=pport ;
	            }
	            pthread_mutex_unlock(&proc->lock_process);
	        }
	        
		    
		    //if(!pidExists){
		    //    if(!pidProFlag || portReUse ){
		    //        char * pname=NULL;
    		//        if(conf.includeProName){
    		//            pname=get_process_name(p);
    		//        }
    		//        // cout<<"pid "<<pid<<"="<<pidProFlag <<" port "<<port<<"="<<portProFlag <<" portPproc="<<portPproc <<" proc="<<proc <<endl;
            //
    		//        if(proc){
     		//            map<unsigned short, struct processPort >::iterator it; 
            //        	for(it=proc->proPort.begin();it!=proc->proPort.end();it++){
            //     	        portprocess.remove(it->first);
            //         	}
            //            pthread_mutex_lock(&proc->lock_process);
            //            pthread_mutex_unlock(&proc->lock_process);
    		//            delete proc;
    		//            proc=NULL;
    		//        }
    		//        
    		//        proc=new process(p,pname);
    		//        pids[p]=(proc);
    		//        lastpPidProcess[p]=proc;
    		//        portprocess[port]=proc;
    		//        processPort pport(port);
    		//        proc->proPort[port]=pport;
		    //    }else{
		    //        pids[p]=(proc);
		    //    }
		    //}else{
		    //    if(!portProFlag || proc != portPproc){
		    //        portprocess[port]=proc;
		    //    }
		    //    pthread_mutex_lock(&proc->lock_process);
 	        //    if(proc->proPort.find(port)==proc->proPort.end()){ 
 	        //        processPort pport(port);
		    //        proc->proPort[port]=pport ;
	        //    }
	        //    pthread_mutex_unlock(&proc->lock_process);
		    //}
		}
	} else {
		//std::cout << "Linkname looked like: " << linkname << endl;
	}
}


//bool myfunction (struct process i,struct process j) {
//    if(conf.printOrder==0){
//        return (i.total_in+i.total_out)>(j.total_in+j.total_out); 
//    }else{
//        return (i.rate_in+i.rate_out)>(j.rate_in+j.rate_out); 
//    }
//}
bool myfunction (struct process * i,struct process *j) {
    if(conf.printOrder==0){
        if((i->total_in+i->total_out)==(j->total_in+j->total_out)){
            return i->pid > j->pid ; 
        }else{
            return (i->total_in+i->total_out)>(j->total_in+j->total_out); 
        }
    }else{
        if((i->rate_in+i->rate_out)==(j->rate_in+j->rate_out)){
            return i->pid < j->pid ; 
        }
        return (i->rate_in+i->rate_out)>(j->rate_in+j->rate_out); 
    }
}
void process_manager::calc_process_rate()
{
    pres.clear();
	pthread_mutex_lock(&lock_manager); 
	map< unsigned int, struct process *>::iterator it1;
	int index=0;
	for(it1=pids.begin();it1!=pids.end();it1++)
	{
	    process * proc=it1->second;
		proc->rate_out=(proc->total_out-proc->last_out)/conf.print_interval;
		proc->rate_in=(proc->total_in-proc->last_in)/conf.print_interval;
		proc->last_in=proc->total_in;
		proc->last_out=proc->total_out;
		pres.push_back(proc);
		//pres[index++]=proc;
	}
	pthread_mutex_unlock(&lock_manager);
	sort(pres.begin(),pres.end(),myfunction);
	statis.cur_time=time(NULL);
	//return pres;
}

void process_manager::test(inodeport& inodeport)
{
	reflush_process( inodeport);
	map<unsigned int, struct process* >::iterator it; 
	for(it=pids.begin();it!=pids.end();it++)
	{
		//cout<<"Port: "<< it->first <<" Process: "<< it->second << endl;
		//cout<<"Port: "<< it->first <<" Process: "<< it->second << endl;
	}  

}




