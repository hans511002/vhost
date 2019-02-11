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
//funcation		�ļ����ݿ�hash��
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
			unsigned long long next;					//���� ��һ��λ��
			unsigned int hashCode;						//hashֵ
			unsigned int hashCode2;						//hashֵ  �����ַ���У��
			VALUET  val;									/* ��ǰ�ڵ�����λ��*/
			unsigned int hashCode3;						//hashֵ  �����ַ���У��
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
		//  ��ӽڵ㵽HashTable��
		inline bool addNode(HashNode * node)
		{
			if(nodes==NULL)
			{
				if(this->hashSize==0)EXP("addNodeδ����hash��ʼ����С");
				try
				{
					nodes=new HashNode[this->hashSize];	//����洢�ռ�
				}
				catch(...)
				{
					EXP("hash���ڴ�ռ����ʧ��");
				}
			}
			if(node->hashCode==0){delete node;return false;}
			unsigned int curIndex=node->hashCode%this->hashSize;					//ȡ����λ��;
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
				if(nodes[curIndex].hashCode==node->hashCode						//��ͬkey���ٴ���
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
					if(pNode->hashCode==node->hashCode						//��ͬkey���ٴ���
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
		//  ��ӽڵ㵽HashTable��
		inline bool addNode(const KEYT &key,const VALUET &val)
		{
			HashNode *node=getHashNode(key,val);
			return addNode(node);
		};
		//  ��������������С,ÿ����һ�ζ��������������ݵĿ����ƶ�
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
					if(tempNodes[i].hashCode==0)continue;									//��������
					unsigned int curIndex=tempNodes[i].hashCode%this->hashSize;				//ȡ����λ��;
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
		//	�����С,��������ǰֵ
		inline void setSize(int hashSize)
		{
			if(this->nodes==NULL)
				this->hashSize=hashSize;
		};
		//	����hash���С
		inline int getSize(){return this->hashSize;};
		//  ��������
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
		//�Ƴ�һ���ؼ���
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
				if(pNode->next==0)//�޺����ڵ�
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

		//	����������,����ֵ����
		inline VALUET &operator[](const KEYT &key)
		{
			if(nodes==NULL)
			{
				if(this->hashSize==0)EXP("operator[]δ����hash��ʼ����С");
				try
				{
					nodes=new HashNode[this->hashSize];	//����洢�ռ�
				}
				catch(...)
				{
					EXP("hash���ڴ�ռ����ʧ��");
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
					delete node;									//�Ѿ�����
					return pNode->val;
				}
				curNode=pNode;
				pNode=(HashNode *)pNode->next;
			}
			curNode->next=(unsigned long long)node;
			return node->val;
		};
		//	���ڴ����
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
					&& pNode->hashCode3==hashCode3					//����hash���
					)
				{
					val=pNode->val;
					return true;
				}
				pNode=(HashNode *)pNode->next;
			}
			return false;
		};
		//��֤һ��KEY�Ƿ����
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
					&& pNode->hashCode3==hashCode3					//����hash���
					)
				{
					return true;
				}
				pNode=(HashNode *)pNode->next;
			}
			return false;
		};
		//     ���ļ�����
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
					&& tempNode.hashCode3==hashCode3					//����hash���
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
					return false;						//δ�ҵ�
				}
			}
			return false;
		};
		//
		// ժҪ:
		//	���ļ�����key
		//
		inline bool find(FILE *pkeyFile,const KEYT &key,VALUET &val)
		{
			return find(pkeyFile,key,val,this->hashSize);
		};
		//     ��HashTable����д���ļ�,д����ɾ��HashTable �е��ڴ�����
		inline int writeFile(FILE *pkeyFile,bool printAnalyse=false)					//д���ļ�
		{
			if(printAnalyse)
			{
				Array<int> distributing;
				int res=writeFile(pkeyFile,&distributing);
				cout<<"hash�������: "<< distributing[0] <<endl;
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
		inline int writeFile(FILE *pkeyFile,Array<int> *distributing)					//д���ļ�
		{
			if(nodes==NULL)
			{
				if(this->hashSize==0)EXP("writeFileδ����hash��ʼ����С");
				try
				{
					nodes=new HashNode[this->hashSize];	//����洢�ռ�
				}
				catch(...)
				{
					EXP("hash���ڴ�ռ����ʧ��");
				}
			}
			long long curPos=0;
			int repeatCount=0,len=0;
			HashNode * pNode,* curNode,*nextNode;

			HashNode tempNode=HashNode();
			fseek(pkeyFile,(this->hashSize-1) * NodeSize ,SEEK_SET);			//ֱ��д����󳤶�
			len=fwrite(&tempNode,1,NodeSize,pkeyFile);
			fflush(pkeyFile);
			long fileSize=ftell(pkeyFile);
			if(len!=NodeSize || fileSize!=this->hashSize*NodeSize)
				EXP("��ʼ��hash�ļ���С��������.");
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
					if(len!=NodeSize)	EXP("д��hash�ļ���������.");
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
						EXP("д��hash�ļ���������.");
				}
			}
			delete [] nodes;
			nodes=NULL;
			return repeatCount;
		};
		//     ֱ�ӽ�KEYд���ļ�
		inline static int writeFile(FILE *pkeyFile,const KEYT &key,const VALUET &val,int &repeatCount,int hashSize)
		{
			if(!pkeyFile)EXP("key�ļ�ָ��Ϊ��.");
			//ֱ��д���ļ�
			int len=0;
			HashNode node(key,val);
			if(node.hashCode==0)return -1;
			unsigned int curIndex=node.hashCode % hashSize;					//ȡ����λ��;
			long long curPos=NodeSize*curIndex;
			fseek(pkeyFile, curPos, SEEK_SET);
			HashNode tempNode;
			len= fread(&tempNode,1,NodeSize,pkeyFile);
			if(len!=NodeSize)	EXP("��ȡkey���ݷ�������,δ��ȡ��ָ�����ȵ�����.");
			if(tempNode.hashCode==0)
			{
				fseek(pkeyFile, curPos, SEEK_SET);
				len=fwrite(&node,1,NodeSize,pkeyFile);
				if(len!=NodeSize)	EXP("д��hash�ļ���������.");
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
		//	��ȡ��hash�ڵ��ָ��
		static HashNode * getHashNode(const KEYT &key,const VALUET &val)
		{
			return new HashNode(key,val);
		};
		//	��ȡ��hash�ڵ��ָ��
		static HashNode * getHashNode(const KEYT &key)
		{
			HashNode *node=new HashNode(key);
			return node;
		};
		//	����hash��
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
		//	��ȡhash�����
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

