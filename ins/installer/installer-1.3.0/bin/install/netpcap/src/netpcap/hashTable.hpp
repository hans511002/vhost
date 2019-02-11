// ==============================================================
//progame      Common:HashTable 
//company      hans
//copyright    Copyright (c) hans  2007-2010
//version      1.0
//Author       hans
//date         2007
//description  Common namespace
//				This library is free software. Permission to use, copy,
//				modify and redistribute it for any purpose is hereby granted
//				without fee, provided that the above copyright notice appear
//				in all copies.
//funcation		文件数据库hash表。
// ==============================================================

#ifndef __Common_HashTable_H__
#define __Common_HashTable_H__
#include <assert.h>
#include <assert.h>

namespace Common
{
#define HASHMATH_METHOD1(s)  hashMath::hashsp(s)
#define HASHMATH_METHOD2(s)  hashMath::hashsp2(s)
#define HASHMATH_METHOD3(s)  hashMath::hashpjw(s)

#define FORMAT_LINE char p[40];int len=sprintf(p,"%d",__LINE__); 

#ifndef EXP
#define EXP(msg){FORMAT_LINE string MSG=string(  __FILE__)+string(":")+  string(p)  +string("\n");  cout<< MSG<<endl ; }
// {FORMAT_LINE string MSG=string(  __FILE__)+string(":")+  string(p)  +string("\n");/* cout<<__FILE__<<": error  on line "<< __LINE__<<endl ;*/throw std::exception(MSG+msg);}
#endif
//#define hashTable HashTable
	template <class KEYT,class VALUET> class HashTable
	{
	public:
		struct HashNode
		{
		public:
			unsigned long long next;					//链表 下一个位置
			unsigned int hashCode;						//hash值
			unsigned int hashCode2;						//hash值  用于字符串校验
			VALUET  val;									/* 当前节点数据位置*/
			unsigned int hashCode3;						//hash值  用于字符串校验
			HashNode():hashCode(0),next(0),val(VALUET()),hashCode2(0),hashCode3(0){};
			HashNode(const KEYT &key):next(0),val(VALUET())
			{
				hashCode=HASHMATH_METHOD1(key);
				hashCode2=HASHMATH_METHOD2(key);
				hashCode3=HASHMATH_METHOD3(key);
			};
			HashNode(const KEYT &key,const VALUET &val):next(0),val(val)
			{
				hashCode=HASHMATH_METHOD1(key);
				hashCode2=HASHMATH_METHOD2(key);
				hashCode3=HASHMATH_METHOD3(key);
			};
		};
		HashNode * nodes;
		unsigned int hashSize;
		unsigned nodeNum;
	public:
		HashTable(int _size=0):hashSize(_size),nodes(NULL),nodeNum(0){};
		~HashTable(){clear();};
		//  添加节点到HashTable中
		inline bool addNode(HashNode * node)
		{
			if(nodes==NULL)
			{
				if(this->hashSize==0)EXP("addNode未设置hash初始化大小");
				try
				{
					nodes=new HashNode[this->hashSize];	//分配存储空间
				}
				catch(...)
				{
					EXP("hash表内存空间分配失败");
				}
			}
			if(node->hashCode==0){delete node;return false;}
			unsigned int curIndex=node->hashCode%this->hashSize;					//取索引位置;
			if(nodes[curIndex].hashCode==0)
			{
				nodes[curIndex]=*node;
				delete node;
				node=NULL;
				nodeNum++;
				return true;
			}
			else
			{
				if(nodes[curIndex].hashCode==node->hashCode						//相同key不再处理
					&& nodes[curIndex].hashCode2==node->hashCode2
					&& nodes[curIndex].hashCode3==node->hashCode3 )
				{
					delete node;
					return false;
				}
				HashNode * pNode;
				pNode=&(nodes[curIndex]);
				while(pNode->next)
				{
					pNode=(HashNode *)(pNode->next);
					if(pNode->hashCode==node->hashCode						//相同key不再处理
						&& pNode->hashCode2==node->hashCode2
						&& pNode->hashCode3==node->hashCode3
						)
					{
						delete node;
						return false;
					}
				}
				pNode->next=(unsigned long long)node;nodeNum++;
				return true;
			}
		};
		//  添加节点到HashTable中
		inline bool addNode(const KEYT &key,const VALUET &val)
		{
			HashNode *node=getHashNode(key,val);
			return addNode(node);
		};
		//  重新设置容器大小,每调用一次都会引起已有数据的拷贝移动
		inline void resize(int hashSize)
		{
			if(hashSize>this->hashSize)
			{
				int oldSize=this->hashSize;
				this->hashSize=hashSize;
				HashNode *tempNodes=nodes;
				nodes=new HashNode[this->hashSize];
				for(int i=0;i<oldSize;i++)
				{
					if(tempNodes[i].hashCode==0)continue;									//存在数据
					unsigned int curIndex=tempNodes[i].hashCode%this->hashSize;				//取索引位置;
					HashNode * node=new HashNode();
					(*node)=tempNodes[i];
					node->next=0;
					addNode(node);

					HashNode * pNode = (HashNode *)(tempNodes[i].next);
					HashNode * tpNode;
					while(pNode)
					{
						node=new HashNode();
						(*node)=*pNode;
						node->next=0;
						addNode(node);
						tpNode=pNode;
						pNode=(HashNode *)(pNode->next);
						delete tpNode;
					}
				}
				delete []tempNodes;
			}
		};
		//	重设大小,不保留以前值
		inline void setSize(int hashSize)
		{
			if(this->nodes==NULL)
				this->hashSize=hashSize;
		};
		//	返回hash表大小
		inline int getSize(){return this->hashSize;};
		//  清理数据
		inline void clear()
		{
			if(nodes)
			{
				HashNode * pNode,* nextNode;
				for(int i=0;i<this->hashSize;i++)
				{
					if(this->nodes[i].next)
					{
						nextNode=(HashNode *)this->nodes[i].next;
						while(nextNode)
						{
							pNode=nextNode;
							nextNode=(HashNode *)nextNode->next;
							delete pNode;
						}
					}
				}
				delete []nodes;
			}
			nodes=NULL;
			nodeNum=0;
		}
		//移除一个关键字
		inline bool remove(const KEYT &key)
		{
			if(nodes==NULL)return false;
			unsigned int hashCode,hashCode2,hashCode3,curIndex;
			hashCode=HASHMATH_METHOD1(key);
			hashCode2=HASHMATH_METHOD2(key);
			hashCode3=HASHMATH_METHOD3(key);
			curIndex=hashCode%this->hashSize;
			HashNode * pNode=nodes + curIndex;
			if(pNode->hashCode==hashCode
				&& pNode->hashCode2==hashCode2 
				&& pNode->hashCode3==hashCode3
				)
			{
				if(pNode->next==0)//无后续节点
				{
					pNode->hashCode=0;
					pNode->hashCode2=0;
					pNode->hashCode3=0;
				}
				else
				{
					HashNode * priNode=pNode;
					pNode=(HashNode *)pNode->next;
					(*priNode)=(*pNode);
					delete pNode;
				}
				nodeNum--;
				return true;
			}
			HashNode * priNode=pNode;
			pNode=(HashNode *)pNode->next;
			while(pNode)
			{
				if(pNode->hashCode==hashCode
					&& pNode->hashCode2==hashCode2 
					&& pNode->hashCode3==hashCode3
					)
				{
					if(pNode->next)
					{
						priNode->next=pNode->next;
					}
					else
					{
						priNode->next=0;
					}
					delete pNode;
					nodeNum--;
					return true;
				}
				priNode=pNode;
				pNode=(HashNode *)pNode->next;
			}
			return false;
		}

		//	操作符重载,返回值引用
		inline VALUET &operator[](const KEYT &key)
		{
			if(nodes==NULL)
			{
				if(this->hashSize==0)EXP("operator[]未设置hash初始化大小");
				try
				{
					nodes=new HashNode[this->hashSize];	//分配存储空间
				}
				catch(...)
				{
					EXP("hash表内存空间分配失败");
				}
			}
			HashNode *node=getHashNode(key);
			unsigned int curIndex=node->hashCode%this->hashSize;
			HashNode * pNode;
			HashNode * curNode=nodes + curIndex;
			if(curNode->hashCode==0)
			{
				*curNode=*node;
				delete node;
				return curNode->val;
			}
			pNode=curNode;
			while(pNode)
			{
				if(pNode->hashCode==node->hashCode
					&& pNode->hashCode2==node->hashCode2 
					&& pNode->hashCode3==node->hashCode3
					)
				{
					delete node;									//已经存在
					return pNode->val;
				}
				curNode=pNode;
				pNode=(HashNode *)pNode->next;
			}
			curNode->next=(unsigned long long)node;
			return node->val;
		};
		//	从内存查找
		inline bool find(const KEYT &key,VALUET &val)
		{
			if(nodes==NULL)return false;
			unsigned int hashCode,hashCode2,hashCode3,curIndex;
			hashCode=HASHMATH_METHOD1(key);
			hashCode2=HASHMATH_METHOD2(key);
			hashCode3=HASHMATH_METHOD3(key);
			curIndex=hashCode%this->hashSize;
			HashNode * pNode=nodes + curIndex;
			
			while(pNode)
			{
				if(pNode->hashCode==hashCode
					&& pNode->hashCode2==hashCode2 
					&& pNode->hashCode3==hashCode3					//三次hash相等
					)
				{
					val=pNode->val;
					return true;
				}
				pNode=(HashNode *)pNode->next;
			}
			return false;
		};
		//验证一个KEY是否存在
		inline bool contain(const KEYT &key)
		{
			if(nodes==NULL)return false;
			unsigned int hashCode,hashCode2,hashCode3,curIndex;
			hashCode=HASHMATH_METHOD1(key);
			hashCode2=HASHMATH_METHOD2(key);
			hashCode3=HASHMATH_METHOD3(key);
			curIndex=hashCode%this->hashSize;
			HashNode * pNode=nodes + curIndex;
			
			while(pNode)
			{
				if(pNode->hashCode==hashCode
					&& pNode->hashCode2==hashCode2 
					&& pNode->hashCode3==hashCode3					//三次hash相等
					)
				{
					return true;
				}
				pNode=(HashNode *)pNode->next;
			}
			return false;
		};
		//     从文件查找
		inline static bool find(FILE *pkeyFile,const KEYT &key,VALUET &val,int hashSize)
		{
			if(!pkeyFile)return false;
			unsigned int hashCode,hashCode2,hashCode3,curIndex;
			hashCode=HASHMATH_METHOD1(key);
			hashCode2=HASHMATH_METHOD2(key);
			hashCode3=HASHMATH_METHOD3(key);
			HashNode tempNode;
			curIndex=hashCode%hashSize;			
			long long curPos=NodeSize*curIndex;
			fseek(pkeyFile, curPos, SEEK_SET);
			int len= fread(&tempNode,1,NodeSize,pkeyFile);//return false;
			if(len!=NodeSize)	EXP("read key data error .");
			while(tempNode.hashCode%hashSize==curIndex)
			{
				if(tempNode.hashCode==hashCode
					&& tempNode.hashCode2==hashCode2 
					&& tempNode.hashCode3==hashCode3					//三次hash相等
					)
				{
					val=tempNode.val;
					return true;
				}
				if(!tempNode.next)return false;
				fseek(pkeyFile, tempNode.next, SEEK_SET);
				fread(&tempNode,1,NodeSize,pkeyFile);
				if(tempNode.hashCode==0)
				{
					return false;						//未找到
				}
			}
			return false;
		};
		//
		// 摘要:
		//	从文件查找key
		//
		inline bool find(FILE *pkeyFile,const KEYT &key,VALUET &val)
		{
			return find(pkeyFile,key,val,this->hashSize);
		};
		//     将HashTable数据写成文件,写完后会删除HashTable 中的内存数据
		inline int writeFile(FILE *pkeyFile,bool printAnalyse=false)					//写入文件
		{
			if(printAnalyse)
			{
				Array<int> distributing;
				int res=writeFile(pkeyFile,&distributing);
				cout<<"hash链表深度: "<< distributing[0] <<endl;
				int countPos=0;
				for(int i=1;i<distributing.size();i++)
				{
					countPos+=distributing[i];
				}
				for(int i=1;i<distributing.size();i++)
				{
					cout<<"hash "<<i<<" times: "<< distributing[i] <<" per: "<< (double)distributing[i]/countPos <<endl;
				}
				cout<<"hash table use rate: "<< (double)distributing[1]*100/this->hashSize <<endl;
				return res;
			}
			else
				return writeFile(pkeyFile,(Array<int> *)NULL);
		};
		inline int writeFile(FILE *pkeyFile,Array<int> *distributing)					//写入文件
		{
			if(nodes==NULL)
			{
				if(this->hashSize==0)EXP("writeFile未设置hash初始化大小");
				try
				{
					nodes=new HashNode[this->hashSize];	//分配存储空间
				}
				catch(...)
				{
					EXP("hash表内存空间分配失败");
				}
			}
			long long curPos=0;
			int repeatCount=0,len=0;
			HashNode * pNode,* curNode,*nextNode;

			HashNode tempNode=HashNode();
			fseek(pkeyFile,(this->hashSize-1) * NodeSize ,SEEK_SET);			//直接写入最大长度
			len=fwrite(&tempNode,1,NodeSize,pkeyFile);
			fflush(pkeyFile);
			long fileSize=ftell(pkeyFile);
			if(len!=NodeSize || fileSize!=this->hashSize*NodeSize)
				EXP("初始化hash文件大小发生错误.");
			for(int i=0;i<this->hashSize;i++)
			{
				if(nodes[i].hashCode==0)continue;
				int depth=0;
				if(distributing)(*distributing)[depth++]++;
				curNode=&(nodes[i]);
				if(curNode->next)
				{
					nextNode=(HashNode *)(curNode->next);
					curNode->next=(repeatCount+this->hashSize) * NodeSize;
					curPos= i * NodeSize;
					fseek(pkeyFile, curPos, SEEK_SET);
					len=fwrite(curNode,1,NodeSize,pkeyFile);
					if(len!=NodeSize)	EXP("写入hash文件发生错误.");
					while(nextNode)
					{
						if(distributing)(*distributing)[depth++]++;
						repeatCount++;
						pNode=(HashNode *)(nextNode->next);
						unsigned long long nPos=((nextNode->next!=0)?1:0) * (repeatCount+this->hashSize) * NodeSize;
						nextNode->next=nPos;
						fseek(pkeyFile, 0, SEEK_END);
						len=fwrite(nextNode,1,NodeSize,pkeyFile);
						assert(len==NodeSize);
						delete nextNode;
						nextNode=pNode;
					}
				}
				else
				{
					curPos= i * NodeSize;
					fseek(pkeyFile, curPos, SEEK_SET);
					len=fwrite(curNode,1,NodeSize,pkeyFile);
					if(len!=NodeSize)
						EXP("写入hash文件发生错误.");
				}
			}
			delete [] nodes;
			nodes=NULL;
			return repeatCount;
		};
		//     直接将KEY写入文件
		inline static int writeFile(FILE *pkeyFile,const KEYT &key,const VALUET &val,int &repeatCount,int hashSize)
		{
			if(!pkeyFile)EXP("key文件指针为空.");
			//直接写入文件
			int len=0;
			HashNode node(key,val);
			if(node.hashCode==0)return -1;
			unsigned int curIndex=node.hashCode % hashSize;					//取索引位置;
			long long curPos=NodeSize*curIndex;
			fseek(pkeyFile, curPos, SEEK_SET);
			HashNode tempNode;
			len= fread(&tempNode,1,NodeSize,pkeyFile);
			if(len!=NodeSize)	EXP("读取key数据发生错误,未读取到指定长度的数据.");
			if(tempNode.hashCode==0)
			{
				fseek(pkeyFile, curPos, SEEK_SET);
				len=fwrite(&node,1,NodeSize,pkeyFile);
				if(len!=NodeSize)	EXP("写入hash文件发生错误.");
			}
			else
			{
				if(tempNode.hashCode=node.hashCode && tempNode.hashCode2==node.hashCode2 && tempNode.hashCode3==node.hashCode3)
					return 0;
				unsigned long long nPos=curPos;
				while(tempNode.next)
				{
					nPos=tempNode.next;
					fseek(pkeyFile, tempNode.next, SEEK_SET);
					len = fread(&tempNode,1,NodeSize,pkeyFile);
					if(tempNode.hashCode==node.hashCode && tempNode.hashCode2==node.hashCode2 && tempNode.hashCode3==node.hashCode3)
						return 0;
				}
				fseek(pkeyFile,0, SEEK_END);
				tempNode.next=ftell(pkeyFile);
				fseek(pkeyFile, nPos, SEEK_SET);
				len=fwrite(&tempNode,1,NodeSize,pkeyFile);
				assert(len==NodeSize);
				fseek(pkeyFile, 0, SEEK_END);
				len=fwrite(&node,1,NodeSize,pkeyFile);
				assert(len==NodeSize);
				repeatCount++;
			}
			return 1;
		};
		//	获取新hash节点的指针
		static HashNode * getHashNode(const KEYT &key,const VALUET &val)
		{
			return new HashNode(key,val);
		};
		//	获取新hash节点的指针
		static HashNode * getHashNode(const KEYT &key)
		{
			HashNode *node=new HashNode(key);
			return node;
		};
		//	分析hash表
		inline void analyse()
		{
			vector<int> distributing;
			distributing.push_back(1);
			if(nodes)
			{
				HashNode * pNode,* nextNode;
				for(int i=0;i<this->hashSize;i++)
				{
					if(this->nodes[i].hashCode!=0)
					{
						int depth=1;
						if(depth>=distributing.size())
							distributing.push_back(1);
						else
							distributing.at(depth)++;
						if(this->nodes[i].next)
						{
							nextNode=(HashNode *)this->nodes[i].next;
							while(nextNode)
							{
								depth++;
								if(depth>=distributing.size())
									distributing.push_back(1);
								else
									distributing.at(depth)++;
								pNode=nextNode;
								nextNode=(HashNode *)nextNode->next;
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
					cout<<"hash "<<i<<" times: "<< distributing[i] <<" per: "<< (double)distributing[i]/countPos <<endl;
				}
				cout<<"hash table Use rate: "<< (double)distributing[1]*100/this->hashSize <<endl;
			}
			else
			{
				cout<<"not exists hash node! " <<endl;
			}
			distributing.clear();
		};
		//	获取hash表深度
		inline int getDepth()
		{
			int depth=1;
			if(nodes)
			{
				HashNode * pNode,* nextNode;
				for(int i=0;i<this->hashSize;i++)
				{
					int depth2=1;
					if(this->nodes[i].next)
					{
						nextNode=(HashNode *)this->nodes[i].next;
						while(nextNode)
						{
							depth++;
							pNode=nextNode;
							nextNode=(HashNode *)nextNode->next;
						}
						if(depth<depth2)depth=depth2;
					}
				}
			}
			return depth;
		};
		static const long long NodeSize;//=sizeof(NODE);
		static const int hashType;
	};
	template <class KEYT,class VALUET> const long long HashTable<KEYT,VALUET>::NodeSize=sizeof(HashTable<KEYT,VALUET>::HashNode);
	template <class KEYT,class VALUET> const int HashTable<KEYT,VALUET>::hashType=11;
	template <class KEYT,class VALUET> class hashTable:public HashTable<KEYT,VALUET>
	{
	public:
		hashTable(int _size=0){HashTable<KEYT,VALUET>::hashSize=_size;};
		~hashTable(){HashTable<KEYT,VALUET>::clear();};
	};
}
#endif

