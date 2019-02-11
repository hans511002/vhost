#ifndef CUI
#define CUI

#include <cstdlib>
#include <cstring>
#include <vector>
#include "process.h"
using std::vector;

struct line{
	int pid;
	char*  kbyteTin;
	char*  kbyteTout;
	char*  kbytein;
	char*  kbyteout;
	char *name;
	line(const process * p)
	{
		pid = p->pid;
		kbyteTin = new char [32];
		kbyteTout = new char [32];
		sprintf(kbyteTin, "%.3f kb",(double)p->total_in/1024);
		sprintf(kbyteTout, "%.3f kb",(double)p->total_out/1024);
		kbytein = new char [32];
		kbyteout = new char [32];
		sprintf(kbytein, "%.3f kb/s",(double)p->rate_in/1024);
		sprintf(kbyteout, "%.3f kb/s",(double)p->rate_out/1024);
		name = p->name;
	}
	~line(){
		free(kbyteTin);
		free(kbyteTout);
		free(kbytein);
		free(kbyteout);
	}
};

class Cui
{
	char *caption;
	private:
		Cui(Cui& ){}
		const Cui&  operator=(const Cui& T)const{return T;}

		void show_line(const struct line& l, int row);
	public:
		static Cui& GetInstance(){
			static class Cui instance;
			return instance;
		}
		virtual void show(const vector<struct process *>& pvec );
		virtual void show_title(int proNum);
		Cui();
		virtual ~Cui();
};

#endif
