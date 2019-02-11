// ==============================================================
//progame      Common:numMap 
//company      hans
//copyright    Copyright (c) hans  2007-4     2008-03
//version      1.0
//Author       hans
//date         2007-4     2008-03
//description  Common namespace
//				This library is free software. Permission to use, copy,
//				modify and redistribute it for any purpose is hereby granted
//				without fee, provided that the above copyright notice appear
//				in all copies.
// ==============================================================

#ifndef __Common_numMap__
#define __Common_numMap__
namespace Common
{
#ifndef EXP
#define EXP(msg) {cout<<__FILE__<<": error "<< " on line "<< __LINE__<<endl ;throw(string(msg));}
#endif
#ifndef ONE_READ_COUNT
#define ONE_READ_COUNT 5			//一次读取记录数
#endif
typedef void (*clearCallBack)(void *) ;


#define GET_ABS(T) T abs(T t){return (t>0)?t:-t;}
	inline GET_ABS(int)
	inline GET_ABS(long)
	inline GET_ABS(float)
	inline GET_ABS(double)
	inline GET_ABS(long long)
	inline GET_ABS(unsigned long)
	inline GET_ABS(unsigned int )
	inline GET_ABS(unsigned long long)

	template <class KEYT,class VALUE> class numMap
	{
	public:
		static const long NodeSize;
		struct numNode
		{
		public:
			unsigned long long next;
			KEYT   key;
			VALUE  val;
			numNode():next(0){key=KEYT();val=VALUE();};
			numNode(const KEYT& key):next(0),key(key),val(VALUE()){};
			numNode(const KEYT& key,const VALUE& val):next(0),key(key),val(val){};
		};
	protected:
		int size;
		numNode * nodes;
	public:
		numMap(int size=0)
		{
			nodes=NULL;
			this->size=size;
		};
		~numMap()
		{
			clear();
		};
		//
		// 摘要:
		//     添加节点到hashTable中
		//
		// 参数:
		//   node:
		//     numNode 类型指针。
		//
		inline bool addNode(numNode * &node)
		{
			if(nodes==NULL)
			{
				if(this->size==0)EXP("未设置hash初始化大小");
				nodes=new numNode[this->size];	//分配存储空间
			}
			if(node->key==0){delete node;return false;}
			unsigned int curIndex=abs(node->key)%this->size;					//取索引位置;
			if(nodes[curIndex].key==0 && curIndex!=0)						//主保存key==0的值,当curIndex==0时直接链接在最后
			{
				nodes[curIndex]=*node;
				delete node;
				return true;
			}
			else
			{
				if(nodes[curIndex].key==node->key && curIndex!=0)						//相同key不再处理
				{
					delete node;
					return false;
				}
				numNode * pNode;
				pNode=&(nodes[curIndex]);
				while(pNode->next)
				{
					pNode=(numNode *)(pNode->next);
					if(pNode->key==node->key)						//相同key不再处理
					{
						delete node;
						return false;
					}
				}
				pNode->next=(unsigned long long)node;
				return true;
			}
		};
		//
		// 摘要:
		//     重新设置容器大小,每调用一次都会引起已有数据的拷贝移动
		//
		// 参数:
		//   size:
		//     要重新设置的容器大小数目。
		//
		inline void resize(int size)
		{
			if(size>this->size)
			{
				int oldSize=this->size;
				this->size=size;
				numNode *tempNodes=nodes;
				nodes=new numNode[this->size];
				for(int i=0;i<oldSize;i++)
				{
					if(tempNodes[i].key==0)continue;									//存在数据
					unsigned int curIndex=abs(tempNodes[i].key)%this->size;				//取索引位置;
					numNode * node=new numNode();
					(*node)=tempNodes[i];
					addNode(node);

					numNode * pNode = (numNode *)(tempNodes[i].next);
					numNode * tpNode;
					while(pNode)
					{
						node=new numNode();
						(*node)=*pNode;
						addNode(node);
						tpNode=pNode;
						pNode=(numNode *)(pNode->next);
						delete tpNode;
					}
				}
				delete []tempNodes;
			}
		};
		//
		// 摘要:
		//	重设大小,不保留以前值
		//
		inline void setSize(int size)
		{
			if(this->size>0)
			{
				clear();
			}
			this->size=size;
		};
		//
		// 摘要:
		//	返回hash表大小
		//
		inline int getSize(){return this->size;};
		//
		// 摘要:
		//     清理数据
		//
		inline void clear(clearCallBack valCall=NULL)
		{
			if(nodes)
			{
				numNode * pNode,* nextNode;
				for(int i=0;i<this->size;i++)
				{
				    if(valCall){
				        valCall(&this->nodes[i].val);
				    }
					if(this->nodes[i].next)
					{
						nextNode=(numNode *)this->nodes[i].next;
						while(nextNode)
						{
						    if(valCall){
        				        valCall(&(nextNode->val));
        				    }
							pNode=nextNode;
							nextNode=(numNode *)nextNode->next;
							delete pNode;
						}
					}
				}
				delete []nodes;
			}
			nodes=NULL;
		}
		//
		// 摘要:
		//     添加节点到hashTable中
		//
		// 参数:
		//   key:
		//     hash关键字。
		//
		//   val:
		//     hash关键字对应值。 			if(node->key==0){delete node;return false;}
		//
		inline bool addNode(const KEYT &key,const VALUE &val)
		{
			if(nodes==NULL)
			{
				if(this->size==0)EXP("未设置hash初始化大小");
				nodes=new numNode[this->size];	//分配存储空间
			}
			numNode *node=getNumNode(key,val);
			return addNode(node);
		};
		//移除一个关键字          需要移动指针
		inline bool remove(const KEYT &key)
		{
			if(nodes==NULL)
				return false;
			unsigned int curIndex;
			curIndex=abs(key)%this->size;
			numNode * pNode=nodes + curIndex;
			if(curIndex!=0 && pNode->key==key)
			{
				if(pNode->next==0)//无后续节点
				{
					pNode->key=0;
				}
				else
				{
					numNode * priNode=pNode;
					pNode=(numNode *)pNode->next;
					(*priNode)=(*pNode);
					delete pNode;
				}
				return true;
			}
			numNode * priNode=pNode;
			pNode=(numNode *)pNode->next;
			while(pNode)
			{
				if(pNode->key==key)
				{
					if(pNode->next)
					{
						priNode->next=pNode->next;
					}
					delete pNode;
					return true;
				}
				priNode=pNode;
				pNode=(numNode *)pNode->next;
			}
			return false;
		}
		//
		// 摘要:
		//	操作符重载,返回值引用
		//
		// 参数:
		//   key:
		//     关键字
		//
		// 返回结果:
		//     返回值引用
		//
		inline VALUE &operator[](const KEYT &key)
		{
			if(nodes==NULL)
			{
				if(this->size==0)EXP("未设置hash初始化大小");
				nodes=new numNode[this->size];	//分配存储空间
			}
			numNode *node=getNumNode(key);
			unsigned int curIndex=abs(node->key)%this->size;					//取索引位置;
			numNode * pNode;
			numNode * curNode=nodes + curIndex;
			if(curNode->key==0 && curIndex!=0)
			{
				*curNode=*node;
				delete node;
				return curNode->val;
			}
			pNode=curNode;
			while(pNode)
			{
				if(curIndex==0)
				{
					curNode=pNode;
					pNode=(numNode *)pNode->next;
					if(pNode && pNode->key==node->key)
					{
						delete node;									//已经存在
						return pNode->val;
					}
				}
				else
				{
					if(pNode->key==node->key)
					{
						delete node;									//已经存在
						return pNode->val;
					}
					curNode=pNode;
					pNode=(numNode *)pNode->next;
				}
			}
			curNode->next=(unsigned long long)node;
			return node->val;
		};
		//
		// 摘要:
		//	从内存查找
		//
		inline bool find(const KEYT &key,VALUE &val,bool exp=false)
		{
			if(nodes==NULL)if(exp)EXP("没有初始化节点数据.")else return false;
			unsigned int curIndex;
			curIndex=abs(key)%this->size;
			numNode * pNode=nodes + curIndex;
			if(curIndex!=0 && pNode->key==0 )
			{
				return false;								//未找到
			}
			else if(curIndex!=0 && pNode->key==key)
			{
				val=pNode->val;
				return true;
			}
			else if(pNode->next==0)
			{
				return false;
			}
			pNode=(numNode *)pNode->next;
			while(pNode)
			{
				if(pNode->key==key)
				{
					val=pNode->val;
					return true;
				}
				pNode=(numNode *)pNode->next;
			}
			return false;
		};
		inline bool contain(const KEYT &key)
		{
			if(nodes==NULL)return false;
			unsigned int curIndex;
			curIndex=abs(key)%this->size;
			numNode * pNode=nodes + curIndex;
			//cout<<"pNode="<<(long)pNode<<"  pNode->val="<<pNode->val<<"  pNode->key="<<pNode->key<<" key="<<key<<endl;
			if(curIndex==0)
			{
				while(pNode)
				{
					pNode=(numNode *)pNode->next;
					if(pNode && pNode->key==key)
					{
						return true;
					}
				}
			}
			else
			{
				while(pNode)
				{
					if(pNode->key==key)
					{
						return true;
					}
					pNode=(numNode *)pNode->next;
				}
			}


			//if(curIndex!=0 && pNode->key==0 )
			//{
			//	return false;								//未找到
			//}
			//else if(curIndex!=0 && pNode->key==key)
			//{
			//	return true;
			//}
			//else if(pNode->next==0)
			//{
			//	return false;
			//}
			//pNode=(numNode *)pNode->next;
			//while(pNode)
			//{
			//	cout<<"pNode="<<(long)pNode<<"  pNode->val="<<pNode->val<<"  pNode->key="<<pNode->key<<" key="<<key<<endl;
			//	if(pNode->key==key)
			//	{
			//		return true;
			//	}
			//	pNode=(numNode *)pNode->next;
			//}
			return false;
		};
		//
		// 摘要:
		//     从文件查找
		//
		// 参数:
		//   pkeyFile:
		//     已打开的关键字文件指针。
		//
		//   key:
		//     hash关键字。
		//
		//   val:
		//     hash关键字对应返回值。
		//
		//   size:
		//     hash大小。
		//
		// 返回结果:
		//     是否成功查找到数据。
		//
		inline static bool find(FILE *pkeyFile,const KEYT &key,VALUE &val,int size)
		{
			if(!pkeyFile)return false;
			unsigned int curIndex;
			numNode tempNode;
			curIndex=abs(key) % size;			
			long long curPos=NodeSize*curIndex;
			fseek(pkeyFile, curPos, SEEK_SET);
			int len= fread(&tempNode,NodeSize,1,pkeyFile);
			if(len!=1)	EXP("读取key数据发生错误,未读取到指定长度的数据.");
			if(curIndex!=0 && tempNode.key==0 )
			{
				return false;								//未找到
			}
			else if(curIndex!=0 && tempNode.key==key)
			{
				val=tempNode.val;
				return true;
			}
			else if(tempNode.next==0)
			{
				return false;
			}
			while(tempNode.next)
			{
				fseek(pkeyFile, tempNode.next, SEEK_SET);
				fread(&tempNode,NodeSize,1,pkeyFile);
				if(tempNode.key==key)
				{
					val=tempNode.val;
					return true;
				}
			}
			return false;
		};
		//
		// 摘要:
		//	从文件查找key
		//
		inline static bool find(FILE *pkeyFile,const KEYT &key,VALUE &val,int size,bool isSeries)
		{
			if(!isSeries)							//是否使用一次写入key文件
				return find(pkeyFile,key,val,size);
			if(!pkeyFile)
				return false;
			unsigned int curIndex;
			numNode tempNode;
			curIndex=abs(key) % size;
			long long curPos=NodeSize*curIndex;
			fseek(pkeyFile, curPos, SEEK_SET);//return false;
			int len= fread(&tempNode,NodeSize,1,pkeyFile);//return false;
			if(len!=1)	EXP("读取key数据发生错误,未读取到指定长度的数据."+String(len));
			if(curIndex!=0 && tempNode.key==0 )
			{
				return false;								//未找到
			}
			else if(curIndex!=0 && tempNode.key==key)
			{
				val=tempNode.val;
				return true;
			}
			else if(tempNode.next==0)
			{
				return false;
			}
			//读取连续位置值,减少I/O交互
			numNode tempNodes[ONE_READ_COUNT];
			fseek(pkeyFile,tempNode.next, SEEK_SET);
			len= fread(&tempNodes,NodeSize,1,pkeyFile);
			if(len==0)	EXP("读取key数据发生错误,未读取到任何数据.");
			int index=0;
			while(abs(tempNodes[index].key)%size==curIndex)
			{
				if(tempNodes[index].key==key)
				{
					val=tempNodes[index].val;
					return true;
				}
				if(!tempNodes[index].next)return false;
				index++;
				if(index==ONE_READ_COUNT)
				{
					fseek(pkeyFile, tempNodes[index-1].next, SEEK_SET);
					len= fread(&tempNodes,NodeSize,ONE_READ_COUNT,pkeyFile);
					if(len==0)return false;
					index=0;
				}
			}
			return false;
		};
		//
		// 摘要:
		//	从文件查找key
		//
		inline bool find(FILE *pkeyFile,const KEYT &key,VALUE &val)
		{
			if(!pkeyFile)return false;
			unsigned int curIndex;
			numNode tempNode;
			curIndex=abs(key) % size;			
			long long curPos=NodeSize*curIndex;
			fseek(pkeyFile, curPos, SEEK_SET);
			int len= fread(&tempNode,NodeSize,1,pkeyFile);
			if(len!=1)	EXP("读取key数据发生错误,未读取到指定长度的数据.");
			if(curIndex!=0 && tempNode.key==0 )
			{
				return false;								//未找到
			}
			else if(curIndex!=0 && tempNode.key==key)
			{
				val=tempNode.val;
				return true;
			}
			else if(tempNode.next==0)
			{
				return false;
			}
			while(tempNode.next)
			{
				fseek(pkeyFile, tempNode.next, SEEK_SET);
				fread(&tempNode,NodeSize,1,pkeyFile);
				if(tempNode.key==key)
				{
					val=tempNode.val;
					return true;
				}
			}
			return false;
		};
		//
		// 摘要:
		//	从文件查找key
		//
		inline bool find(FILE *pkeyFile,const KEYT &key,VALUE &val,bool isSeries)
		{
			if(!isSeries)							//是否使用一次写入key文件
				return find(pkeyFile,key,val);
			if(!pkeyFile)
				return false;
			unsigned int curIndex;
			numNode tempNode;
			curIndex=abs(key) % size;			
			long long curPos=NodeSize*curIndex;
			fseek(pkeyFile, curPos, SEEK_SET);
			int len= fread(&tempNode,NodeSize,1,pkeyFile);
			if(len!=1)	EXP("读取key数据发生错误,未读取到指定长度的数据.");
			if(tempNode.key==0 && curIndex!=0)
			{
				return false;								//未找到
			}
			else if(tempNode.key==key)
			{
				val=tempNode.val;
				return true;
			}
			else if(tempNode.next==0)
			{
				return false;
			}
			//读取连续位置值,减少I/O交互
			numNode tempNodes[ONE_READ_COUNT];
			fseek(pkeyFile, tempNode.next, SEEK_SET);
			len= fread(&tempNodes,NodeSize,ONE_READ_COUNT,pkeyFile);
			if(len==0)	EXP("读取key数据发生错误,未读取到任何数据.");
			int index=0;
			while(abs(tempNodes[index].key)%size==curIndex)
			{
				if(tempNodes[index].key==key)
				{
					val=tempNodes[index].val;
					return true;
				}
				if(!tempNodes[index].next)return false;
				index++;
				if(index==ONE_READ_COUNT)
				{
					fseek(pkeyFile, tempNodes[index-1].next, SEEK_SET);
					len= fread(&tempNodes,NodeSize,ONE_READ_COUNT,pkeyFile);
					if(len==0)return false;
					index=0;
				}
			}
			return false;
		};
		//
		// 摘要:
		//     将hashTable数据写成文件,写完后会删除hashTable 中的内存数据
		//
		// 参数:
		//   pkeyFile:
		//     已打开的关键字文件指针。
		//
		//   printAnalyse:
		//     是否打印hash分析结果。
		//
		inline int writeFile(FILE *pkeyFile)					//写入文件
		{
			if(nodes==NULL)
			{
				if(this->size==0)EXP("未设置hash初始化大小");
				nodes=new numNode[this->size];	//分配存储空间
			}
			long long curPos=0;
			int repeatCount=0,len=0;
			numNode * pNode,* curNode,*nextNode;

			numNode tempNode=numNode();
			fseek(pkeyFile,(this->size-1) * NodeSize ,SEEK_SET);			//直接写入最大长度
			len=fwrite(&tempNode,NodeSize,1,pkeyFile);
			fflush(pkeyFile);
			long fileSize=ftell(pkeyFile);
			if(len!=1 || fileSize!=this->size*NodeSize)
				EXP("初始化hash文件大小发生错误.");
			for(int i=0;i<this->size;i++)
			{
				if(nodes[i].key==0 && i!=0)continue;
				curNode=&(nodes[i]);
				if(curNode->next)
				{
					nextNode=(numNode *)(curNode->next);
					curNode->next=(repeatCount+this->size) * NodeSize;
					curPos= i * NodeSize;
					fseek(pkeyFile, curPos, SEEK_SET);
					len=fwrite(curNode,NodeSize,1,pkeyFile);
					if(len!=1)	EXP("写入hash文件发生错误.");
					while(nextNode)
					{
						repeatCount++;
						pNode=(numNode *)(nextNode->next);
						unsigned long long nPos=((nextNode->next!=0)?1:0) * (repeatCount+this->size) * NodeSize;
						nextNode->next=nPos;
						fseek(pkeyFile, 0, SEEK_END);
						len=fwrite(nextNode,NodeSize,1,pkeyFile);
						if(len!=1)
							EXP("写入hash文件发生错误.");
						delete nextNode;
						nextNode=pNode;
					}
				}
				else
				{
					curPos= i * NodeSize;
					fseek(pkeyFile, curPos, SEEK_SET);
					len=fwrite(curNode,NodeSize,1,pkeyFile);
					if(len!=1)	EXP("写入hash文件发生错误.");
				}
			}
			delete [] nodes;
			nodes=NULL;
			return repeatCount;
		};
		//
		// 摘要:
		//	写文件
		//
		inline int writeFile(FILE *pkeyFile,bool printAnalyse)					//写入文件
		{
			if(nodes==NULL)
			{
				if(this->size==0)EXP("未设置hash初始化大小");
				nodes=new numNode[this->size];	//分配存储空间
			}
			if(!printAnalyse)
				return writeFile(pkeyFile);
			long long curPos=0;
			int repeatCount=0,len=0;
			numNode * pNode,* curNode,*nextNode;

			numNode tempNode=numNode();
			fseek(pkeyFile,(this->size-1) * NodeSize ,SEEK_SET);			//直接写入最大长度
			len=fwrite(&tempNode,NodeSize,1,pkeyFile);
			fflush(pkeyFile);
			long fileSize=ftell(pkeyFile);
			if(len!=1 || fileSize!=this->size*NodeSize)
				EXP("初始化hash文件大小发生错误.");
			vector<int> distributing;
			distributing.push_back(1);
			distributing.push_back(0);
			for(int i=0;i<this->size;i++)
			{
				if(nodes[i].key==0 && i!=0)continue;
				distributing.at(1)++;
				curNode=&(nodes[i]);
				if(curNode->next)
				{
					nextNode=(numNode *)(curNode->next);
					curNode->next=(repeatCount+this->size) * NodeSize;
					curPos= i * NodeSize;
					fseek(pkeyFile, curPos, SEEK_SET);
					len=fwrite(curNode,NodeSize,1,pkeyFile);
					if(len!=1)	EXP("写入hash文件发生错误.");
					int depth=1;
					while(nextNode)
					{
						depth++;
						if(depth>=distributing.size())
							distributing.push_back(1);
						else
							distributing.at(depth)++;
						repeatCount++;
						pNode=(numNode *)(nextNode->next);
						unsigned long long nPos=((nextNode->next!=0)?1:0) * (repeatCount+this->size) * NodeSize;
						nextNode->next=nPos;
						fseek(pkeyFile, 0, SEEK_END);
						len=fwrite(nextNode,NodeSize,1,pkeyFile);
						if(len!=1)
							EXP("写入hash文件发生错误.");
						delete nextNode;
						nextNode=pNode;
					}
					if(distributing.at(0)<depth)
						distributing.at(0)=depth;
				}
				else
				{
					curPos= i * NodeSize;
					fseek(pkeyFile, curPos, SEEK_SET);
					len=fwrite(curNode,NodeSize,1,pkeyFile);
					if(len!=1)	EXP("写入hash文件发生错误.");
				}
			}
			delete [] nodes;
			nodes=NULL;
			cout<<"hash链表深度: "<< distributing[0] <<endl;
			int countPos=0;
			for(int i=1;i<distributing.size();i++)
			{
				countPos+=distributing[i];
			}
			if(countPos>0)
			{
				for(int i=1;i<distributing.size();i++)
				{
					cout<<"hash "<<i<<" 次定位数: "<< distributing[i] <<" 占比: "<< (double)distributing[i]/countPos <<endl;
				}
			}
			cout<<"hash表使用率: "<< (double)distributing[1]*100/this->size <<endl;
			distributing.clear();
			return repeatCount;
		};
		//
		// 摘要:
		//     直接将KEY写入文件
		//
		// 参数:
		//   pkeyFile:
		//     in 已打开的关键字文件指针。
		//
		//   key:
		//     in hash关键字。
		//
		//   val:
		//     in hash关键字对应返回值。
		//
		//   repeatCount:
		//     in/out hash索引重复值大小。第一次调用前置 0
		//
		inline static void writeFile(FILE *pkeyFile,const KEYT &key,const VALUE &val,int &repeatCount,int size)
		{
			if(!pkeyFile)EXP("key文件指针为空.");
			//直接写入文件
			int len=0;
			numNode *node=getNumNode(key,val);
			unsigned int curIndex=abs(node->key) % size;					//取索引位置;
			long long curPos=NodeSize*curIndex;
			fseek(pkeyFile, curPos, SEEK_SET);
			numNode tempNode;
			len= fread(&tempNode,NodeSize,1,pkeyFile);
			if(len!=1)	EXP("读取key数据发生错误,未读取到指定长度的数据.");
			if(tempNode.key==0 && curIndex!=0)
			{
				fseek(pkeyFile, curPos, SEEK_SET);
				len=fwrite(node,NodeSize,1,pkeyFile);
				if(len!=1)	EXP("写入hash文件发生错误.");
				delete node;
			}
			else
			{
				if(curIndex!=0)
				{
					if(tempNode.key==key)
					{
						delete node;
						repeatCount++;
					}
				}
				unsigned long long nPos=curPos;
				while(tempNode.next)
				{
					nPos=tempNode.next;
					fseek(pkeyFile, tempNode.next, SEEK_SET);
					len = fread(&tempNode,NodeSize,1,pkeyFile);
					if(tempNode.key==key)
					{
						delete node;
						repeatCount++;
					}
				}
				fseek(pkeyFile,0, SEEK_END);
				tempNode.next=ftell(pkeyFile);
				fseek(pkeyFile, nPos, SEEK_SET);
				len=fwrite(&tempNode,NodeSize,1,pkeyFile);
				if(len!=1)
					EXP("更新hash文件中节点发生错误.");
				fseek(pkeyFile, 0, SEEK_END);
				len=fwrite(node,NodeSize,1,pkeyFile);
				if(len!=1)
					EXP("写入hash文件发生错误.");
				delete node;
				repeatCount++;
			}
		};
		//
		// 摘要:
		//	获取新hash节点的指针
		//
		inline static numNode * getNumNode(const KEYT &key,const VALUE &val)
		{
			return new numNode(key,val);
		};
		//
		// 摘要:
		//	获取新hash节点的指针
		//
		inline static numNode * getNumNode(const KEYT &key)
		{
			return new numNode(key);
		};
		//
		// 摘要:
		//	分析hash表
		//
		inline void analyse()
		{
			vector<int> distributing;
			distributing.push_back(1);
			if(nodes)
			{
				numNode * pNode,* nextNode;
				for(int i=0;i<this->size;i++)
				{
					if(this->nodes[i].key!=0 || i==0)
					{
						int depth=1;
						if(depth>=distributing.size())
							distributing.push_back(1);
						else
							distributing.at(depth)++;
						if(this->nodes[i].next)
						{
							nextNode=(numNode *)this->nodes[i].next;
							while(nextNode)
							{
								depth++;
								if(depth>=distributing.size())
									distributing.push_back(1);
								else
									distributing.at(depth)++;
								pNode=nextNode;
								nextNode=(numNode *)nextNode->next;
							}
							if(distributing.at(0)<depth)
								distributing.at(0)=depth;
						}
					}
				}
				cout<<"hash depth: "<< distributing[0] <<endl;
				int countPos=0;
				for(int i=1;i<distributing.size();i++)
				{
					countPos+=distributing[i];
				}
				for(int i=1;i<distributing.size();i++)
				{
					cout<<"hash find "<<i<<" times: "<< distributing[i] <<" per: "<< (double)distributing[i]/countPos <<endl;
				}
				cout<<"hash table use per: "<< (double)distributing[1]*100/this->size <<endl;
			}
			else
			{
				cout<<"not exist hash node! " <<endl;
			}
			distributing.clear();
		};
		//
		// 摘要:
		//	获取hash表深度
		//
		inline int getDepth()
		{
			int depth=1;
			if(nodes)
			{
				numNode * pNode,* nextNode;
				for(int i=0;i<this->size;i++)
				{
					int depth2=1;
					if(this->nodes[i].next)
					{
						nextNode=(numNode *)this->nodes[i].next;
						while(nextNode)
						{
							depth++;
							pNode=nextNode;
							nextNode=(numNode *)nextNode->next;
						}
						if(depth<depth2)depth=depth2;
					}
				}
			}
			return depth;
		};

	};

	template <class KEYT,class VALUE> const long numMap<KEYT,VALUE>::NodeSize=sizeof(numMap<KEYT,VALUE>::numNode);
}
#endif
