#include "inodeport.h"

#include <cstdio>
#include <iostream>
#include <cstdlib>
using namespace std;

int sockNodePortSize=0;

/*read /proc/net/{tcp,tcp6} to get (inode--port)*/
void inodeport::refreshinodeport()
{
	inode_port_tmp=new numMap<unsigned long, unsigned short>(111111);
	sockNodePortSize=0;
	if (!add_procinfo ("/proc/net/tcp")){
		do_debug(LOG_ERROR, "couldn't open /proc/net/tcp\n");
		exit(1);
	}
	add_procinfo ("/proc/net/tcp6");
	pthread_mutex_lock(&lock_inode);
	if(inode_port==NULL){
		inode_port=inode_port_tmp;
	}else{
		inode_port->clear();
		delete inode_port;
		inode_port=inode_port_tmp;
	}
	inode_port_tmp=NULL;
	pthread_mutex_unlock(&lock_inode);
	statis.cur_socket_num=sockNodePortSize;
}

/* opens /proc/net/tcp[6] and adds its contents line by line */
int inodeport::add_procinfo (const char * filename) 
{
	FILE * procinfo = fopen (filename, "r");
	char buffer[4096];
	if (procinfo == NULL)
		return 0;
	fgets(buffer, sizeof(buffer), procinfo);
	do
	{
		if (fgets(buffer, sizeof(buffer), procinfo))
			add_inodeport(buffer);
	} while (!feof(procinfo));
	fclose(procinfo);
	return 1;
}

/*handle one line in file*/
void inodeport::add_inodeport (char * buffer)
{
	unsigned int local_port, rem_port;
	unsigned long inode;
	int matches = sscanf(buffer, "%*d: %*64[0-9A-Fa-f]:%04X %*64[0-9A-Fa-f]:%04X %*X %*X:%*X %*X:%*X %*X %*d %*d %ld %*512s\n",
		 &local_port, &rem_port, &inode);
	if (matches != 3) {
		do_debug(LOG_ERROR, "Unexpected buffer: '%s'\n",buffer);
		exit(1);
	}
	if (inode == 0) {
		/* connection is in TIME_WAIT state. We rely on 
		 * the old data still in the table. */
		return;
	}
	inode_port_tmp->addNode( inode, (unsigned short)local_port);
	sockNodePortSize++;
}

void inodeport::test()
{
 	refreshinodeport();	
	inode_port->analyse();	
}
