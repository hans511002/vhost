/*
hans
*/
#include <pthread.h>
#include <signal.h>
#include <unistd.h>
#include <iostream>
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
using namespace std;
#include "config.h"
#include "packet_cap.h"
#include "inodeport.h"
#include "process.h"
#include "cui.h"
#include "mempool.h"

int PID_MAX=32769;

void usage()
{
	fprintf(stderr, 
			"Usage: netpcap [options]\n"
			"Options:\n"
			"    --serv/-s		run in service mode, output data to file\n"
			"    --size/-z		out file max size \n" 
			"    --allinfo/-a	output port net info \n" 
			"    --filenum/-n	output reserve file nums\n" 
			"    --interval/-i	specify intervals numbers, in minutes if with --live, it is in seconds\n"
			"    --live/-l		running print live mode, which module will print\n" 
			"    --pname/-p		not output or show program name\n" 
			"    --rate/-r		output order by rate \n" 
			"    --debug/-d		debug level info warn error fatal,default error\n" 
			"    --help/-h		help\n");
	exit(0);
}

struct option longopts[] = {
	{ "serv", required_argument, NULL, 's' },
	{ "filenum", required_argument, NULL, 'n' },
	{ "size", required_argument, NULL, 'z' },
	{ "allinfo", no_argument, NULL, 'a' },
	{ "interval", required_argument, NULL, 'i' },
	{ "live", no_argument, NULL, 'l' },
	{ "rate", no_argument, NULL, 'r' },
	{ "pname", no_argument, NULL, 'p' },
	{ "debug", required_argument, NULL, 'd' },
	{ "help", no_argument, NULL, 'h' },
	{ 0, 0, 0, 0},
};

static void main_init(int argc, char **argv)
{
	int opt, oind = 0;
	conf.includeProName=1;
	conf.debug_level = LOG_ERROR;
	conf.fileNum=0;
	conf.fileSize=64*1024000;
	conf.outputPortNetInfo=0;
	while ((opt = getopt_long(argc, argv, ":s:z:i:n:lad:rph", longopts, NULL)) != -1) {
		oind++;
		switch (opt) {
			case 's':
				conf.running_mode = RUN_SERV;
			    memcpy(conf.output_file_path,optarg,strlen(optarg));
				oind++;
				break;
			case 'i':
				conf.print_interval = strtol(optarg,NULL,0);
				oind++;
				break;
			case 'n':
				conf.fileNum = strtol(optarg,NULL,0);
			    //strcpy(conf.output_file_path,optarg);
				oind++;	
				break;
			case 'z':
				conf.fileSize = strtol(optarg,NULL,0);
			    //strcpy(conf.output_file_path,optarg);
				oind++;	
				break;
			case 'l':
				conf.running_mode = RUN_LIVE;
				break;
			case 'd':
			    set_debug_level(optarg);
 				oind++;
				break; 
			case 'a':
				conf.outputPortNetInfo=1;
				break; 
			case 'p':
				conf.includeProName=0;
				break; 
			case 'r':
				conf.printOrder=1;
				break; 
			case 'h':
				usage();
			case ':':
				printf("must have parameter\n");
				usage();
			case '?':
				usage();
			default:
				break;
		}
	}
	if (!conf.print_interval)
		conf.print_interval = 5;
	if(conf.running_mode == RUN_NULL){
	    conf.running_mode = RUN_PRINT;
    }
    
    FILE * pidMax = fopen (PID_MAX_FILE, "r");
	char buffer[24];
	if (pidMax == NULL)
		exit(1); 
	if (fgets(buffer, sizeof(buffer), pidMax)){
		PID_MAX=atol(buffer)+1;
	} 
	fclose(pidMax);
}

int started=0;
static void print_moniter(){
	if(!statis.inited){
    	return;
    } 
	/*first we get the packet list which represents the packets captured*/
 	class Cui& cui_instance = Cui::GetInstance();	 
	/*we need  map of inode to port, the map of port to process*/
    class process_manager &Process_manager = process_manager::GetInstance(); 
	/*packet to process*/
     vector<struct process *>  &pros=Process_manager.getProcess();
 	cui_instance.show_title(pros.size());
	cui_instance.show( (const vector<struct process *>&)pros );
}
/*signal handle for process flush*/
static void moniter_process(int signo)  
{
	print_moniter();
	if(!stop)
		alarm(conf.print_interval);
	else
		exit(0);
}
pthread_t inode_thread;

void * inode_handle(void *){
    class inodeport &Inode_instance = inodeport::GetInstance();
    class process_manager &Process_manager = process_manager::GetInstance(); 
    while(!stop){
		Inode_instance.refreshinodeport();
		Process_manager.reflush_process(Inode_instance);
        //usleep(1000000);
        sleep(5);
	}
}
void startRefreshInodeport(){
    class inodeport &Inode_instance = inodeport::GetInstance();
    Inode_instance.refreshinodeport();
    class process_manager &Process_manager = process_manager::GetInstance(); 
 	Process_manager.reflush_process(Inode_instance);     
    //Inode_instance.test();
    int err =  pthread_create(&inode_thread, NULL, inode_handle, NULL);
    if(0!=err)
	    exit(-1);
}

void running_live(){
	class Cui&  cui_instance = Cui::GetInstance();	
	cui_instance.show_title(0);
    if( signal(SIGALRM,moniter_process) == SIG_ERR )
	{
		return ;
	}
	alarm(conf.print_interval);

	int err;
	void *perr = &err;
	pthread_t pcap_thread;
	err =  pthread_create(&pcap_thread, NULL, packet_handle, NULL);
	if(0!=err)
		exit(-1);
	started=1;
	pthread_join(pcap_thread, &perr);
}

void whileRenameFile(char * src,char * dest){
    while (true) {
        if(access(src,0)){
            break;
        }
        if (rename(src,dest)==0){
            break;
        }
    }
}
void whileRemoveFile(char * src){
    while (true) {
        if(access(src,0)){
            break;
        }
        if (remove(src)==0){
            break;
        }
    }
}
FILE * openOutFile(int & fileNum)
{
    if (conf.fileSize==0){
    	conf.fileSize=64*1024000;
    	conf.fileNum=10;
    }
    FILE * in = fopen (conf.output_file_path, "r");
    char openType[4];
    sprintf(openType,"ar+");
    if(in!=NULL){
        fseek(in,0,SEEK_END);
        long fize=ftell(in);
        bool needTrun=false;
        char fileName[512];
        if(fize>=conf.fileSize ){
            if(conf.debug_level != LOG_DEBUG && conf.fileNum==0){
                sprintf(fileName,"%s.tmp",conf.output_file_path);
                FILE * out = fopen (fileName, "w+");
                if (out == NULL){
            	    fclose(in);
            	    cout<<"open file error:"<<fileName<<" msg:"<<strerror(errno)<<endl;
            	    return NULL;
            	}
            	if(conf.outputPortNetInfo){
            	    fseek(in,fize-102400,SEEK_SET);
            	}else{
            	    fseek(in,fize-20480,SEEK_SET);
            	}
            	char buffer[64000];
            	while (fgets(buffer, sizeof(buffer), in)) {
                     fprintf(out,"%s",buffer);
                }
                fclose(out);
            }
            needTrun=true;
        }
        fclose(in);
        if(needTrun){
            // system("rm -f "+conf.output_file_path);
            // system("mv -f "+conf.output_file_path fileName); fileNum % conf.fileNum+1
            if(conf.debug_level == LOG_DEBUG || conf.fileNum>0){
                fileNum=fileNum % conf.fileNum;
                fileNum++;
                if(conf.fileNum>0){
                    char bakfileName[512];
                    time_t	timep=time(NULL);
                    sprintf(bakfileName,"%s.%d",conf.output_file_path,fileNum);
                    whileRemoveFile(bakfileName);
                    whileRenameFile(conf.output_file_path,bakfileName);
                }else{
                    char bakfileName[512];
                    time_t	timep=time(NULL);
                    sprintf(bakfileName,"%s.%ld",conf.output_file_path,timep);
                    whileRenameFile( conf.output_file_path,bakfileName);
                }
                //whileRenameFile(fileName,conf.output_file_path);
            }else{
                whileRemoveFile(conf.output_file_path);
                whileRenameFile(fileName,conf.output_file_path);
            }
        }
    }
    FILE * out = fopen (conf.output_file_path, "ar+");
	if (out == NULL)
	{
	    cout<<"open file error:"<<strerror(errno)<<endl;
	    return NULL;
	}
	return out;
}



//write to file
void running_serv(){
    conf.includeProName=0;
    if(strlen(conf.output_file_path)==0){
        cout<<" -s must need   out filepath"<<endl;
        exit(-1);
    }
	int err;
	void *perr = &err;
	pthread_t pcap_thread;
	err =  pthread_create(&pcap_thread, NULL, packet_handle, NULL);
	if(0!=err)
		exit(-1);
	started=1;
    class process_manager &Process_manager = process_manager::GetInstance(); 
    //printf("pid total_in total_out rate_in rate_out st_time cur_time [--pid port total_in total_out ]");
    int fileNum=0;
	while (!stop) {
    	sleep(conf.print_interval);
    	if(!statis.inited){
    		continue;
    	}
        vector<struct process *>  &pros=Process_manager.getProcess();
        FILE * out=NULL;
        if(conf.fileNum>0){
            out=openOutFile(fileNum);
        }else{
            out=openOutFile(fileNum);
        }
        if(fileNum>0xFFFFFF)
            fileNum=0;
        if(out==NULL){
            continue;
        }
        int c = pros.size();
        int len=0;
    	for(int i = 0;i<c;i++){
    	    process * p=(pros)[i];
    	    if (p->total_in==0 && p->total_out==0) {
	    		continue;
	    	}
	    	if(len++>0){
        	    fprintf(out,"|" );
        	}
     	    fprintf(out,"%d,%lld,%lld,%lld,%lld,%ld,%ld",p->pid , p->total_in , p->total_out , p->rate_in , p->rate_out , statis.st_time , statis.cur_time);
    	    if(conf.outputPortNetInfo){
    	        map<unsigned short, struct processPort >::iterator it; 
            	for(it=p->proPort.begin();it!=p->proPort.end();it++){
            	    if ( it->second.total_in>0 || it->second.total_out >0){
                        fprintf(out,";%d,%lld,%lld",it->first,it->second.total_in,it->second.total_out);
                    }
            	}
    	    }
    	}
	    fprintf(out,"\n" );
	    fclose(out);
    }
	pthread_join(pcap_thread, &perr);
}

//write to stdout
void running_print(){
	int err;
	void *perr = &err;
	pthread_t pcap_thread;
	err =  pthread_create(&pcap_thread, NULL, packet_handle, NULL);
	if(0!=err)
		exit(-1);
	started=1;
    class process_manager &Process_manager = process_manager::GetInstance(); 
    //printf("pid total_in total_out rate_in rate_out st_time cur_time [--pid port total_in total_out ]");
	while (!stop) {
    	sleep(conf.print_interval);
    	if(!statis.inited){
    		continue;
    	}
        vector<struct process *>  &pros=Process_manager.getProcess();
        int c = pros.size();
    	for(int i = 0;i<c;i++){
    	    process * p=(pros)[i];
    	    if (p->total_in==0 && p->total_out==0) {
	    		continue;
	    	}
     	    printf("%d ",p->pid);
     	    printf("%lld ", p->total_in);
    		printf("%lld ", p->total_out);
    		printf("%lld ", p->rate_in);
    		printf("%lld ", p->rate_out);
    		printf("%ld ", statis.st_time);
    		printf("%ld ", statis.cur_time);

    	    if(conf.includeProName){
    	        printf("%s ",p->name);
    	    }
    	    printf("\n" );
    	    map<  unsigned short, struct processPort >::iterator it; 
        	for(it=p->proPort.begin();it!=p->proPort.end();it++){
     	        printf("#%d",p->pid);
        	    printf(" %d",it->first);
        	    printf(" %lld",it->second.total_in);
        	    printf(" %lld",it->second.total_out);
    	        printf("\n" );
        	}
    	}
    	 

	    //printf("---------------------------------\n" );
	    printf("\n" );
	    printf("\n" );
    }
	pthread_join(pcap_thread, &perr);
}
int main(int argc, char *argv[])
{
 
 //   QApplication app(argc,argv);
	statis.st_time = time(NULL);
	statis.cur_time = statis.st_time;
    main_init(argc, argv);
    class inodeport &Inode_instance = inodeport::GetInstance();
	class process_manager &Process_manager = process_manager::GetInstance(); 
	startRefreshInodeport();
	
    switch (conf.running_mode) {
		case RUN_LIVE:
			running_live();
			break;
		case RUN_SERV:
			running_serv();
			break;
		case RUN_PRINT:
			running_print();
			break;
		default:
			break;
	}
	return 0; 
}
