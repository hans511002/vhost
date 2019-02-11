#ifndef MEMPOOL
#define MEMPOOL
#include <cstdio>
#include <cstdlib>
#include <iostream>
using namespace std;



template<class T>
class mempool
{
private:
	enum{
		EXPANSION_SIZE = 1024
	};
	
	mempool<T>* next;
	size_t objsize;
private:	
	mempool<T>& operator=(const mempool<T>& );
	mempool(const mempool<T>& );
	mempool(size_t size = EXPANSION_SIZE);
	~mempool();	

	void expand(size_t size = EXPANSION_SIZE);
public:
	static class mempool<T>& GetInstance(size_t size=EXPANSION_SIZE){
		static mempool<T> instance(size);
		return instance;
	}
		
	void* alloc();	
	void free(void*);
};



template<class T>
mempool<T>::mempool(size_t size)
{
	next = NULL;
	objsize = sizeof(mempool<T>)>sizeof(T)?sizeof(mempool<T>):sizeof(T);
	expand(size);	
}

template<class T>
mempool<T>::~mempool()
{
	while(next)
	{
		char *p = (char*)next;
		next = next->next;
		delete []p;
	}
}

template<class T>
void* mempool<T>::alloc()
{
	if(!next)
		expand();
	void *r = (void*)next;
	next = next->next;
	return r;
}

template<class T>
void mempool<T>::free(void* p)
{
	mempool<T> *head = (mempool<T>*)p;
  	head->next  = next;
   	next = head;	
}

template<class T>
void mempool<T>::expand(size_t size)
{
	for(size_t i=0;i<size;i++)
	{
		mempool<T>* head = (mempool<T>*)new char[objsize];
		head->next = next;
		next = head;
	}	
}

#endif
