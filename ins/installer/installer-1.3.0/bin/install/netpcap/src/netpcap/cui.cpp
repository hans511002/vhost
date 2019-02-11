#include <ncurses.h>
#include "cui.h"

Cui::Cui()
{
	WINDOW * screen = initscr();
	raw();
	noecho();
	cbreak();
	nodelay(screen, TRUE);
	caption = "PLNM";
}

Cui::~Cui()
{
	clear();
	endwin();
}

void Cui::show_title(int proNum)
{
	//clear();
	mvprintw (0, 0, "%s active process %d    cur socket num %d", caption, proNum,statis.cur_socket_num);
	attron(A_REVERSE);
	if(conf.includeProName){
	    mvprintw (2, 0, "  PID    PROGRAM                                                         TOTAL_SENT          TOTAL_REC           SENT_RATE       REC_RATE   ");
	}else{
	    mvprintw (2, 0, "  PID      TOTAL_SENT          TOTAL_REC           SENT_RATE       REC_RATE   ");
	}
	attroff(A_REVERSE);
}
void Cui::show_line(const struct line& l, int row)
{
	mvprintw(3+row, 1, "%d  ", l.pid);
	int pos=0;
	if(conf.includeProName){
    	mvprintw(3+row, 1+6,  "  %s  ", l.name);
    	int nlen=strlen(l.name)+2;
    	pos=64;
    	if(nlen<pos){
    	    for (int n=0; n<pos-nlen+2; n++){
                 mvprintw(3+row, 7+nlen+n+1,  " ");
            }
    	}
    }
	mvprintw(3+row, 7+pos, "  %s  ", l.kbyteTout);
	mvprintw(3+row, 7+pos+20, "  %s  ", l.kbyteTin);
	mvprintw(3+row, 7+pos+20+20, "  %s  ", l.kbyteout);
	mvprintw(3+row, 7+pos+20+20+15, "  %s  ", l.kbytein);
}

void Cui::show(const vector<struct process  *>& pvec)
{
    for(int i = 0;i<30;i++)
	{
	    mvprintw(3+i, 0, "                                                                                                                                         ");
	}
	int c = pvec.size();
	int line=0;
	for(int i = 0;i<c;i++)
	{
	    process * p=pvec[i];
		if (p->total_in==0 && p->total_out==0) {
    		continue;
    	}
		struct line l( p );
		show_line(l, line++);
	}
	refresh();
}






