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
#define ONE_READ_COUNT 5			//һ�ζ�ȡ��¼��
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
		// ժҪ:
		//     ��ӽڵ㵽hashTable��
		//
		// ����:
		//   node:
		//     numNode ����ָ�롣
		//
		inline bool addNode(numNode * &node)
		{
			if(nodes==NULL)
			{
				if(this->size==0)EXP("δ����hash��ʼ����С");
				nodes=new numNode[this->size];	//����洢�ռ�
			}
			if(node->key==0){delete node;return false;}
			unsigned int curIndex=abs(node->key)%this->size;					//ȡ����λ��;
			if(nodes[curIndex].key==0 && curIndex!=0)						//������key==0��ֵ,��curIndex==0ʱֱ�����������
			{
				nodes[curIndex]=*node;
				delete node;
				return true;
			}
			else
			{
				if(nodes[curIndex].key==node->key && curIndex!=0)						//��ͬkey���ٴ���
				{
					delete node;
					return false;
				}
				numNode * pNode;
				pNode=&(nodes[curIndex]);
				while(pNode->next)
				{
					pNode=(numNode *)(pNode->next);
					if(pNode->key==node->key)						//��ͬkey���ٴ���
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
		// ժҪ:
		//     ��������������С,ÿ����һ�ζ��������������ݵĿ����ƶ�
		//
		// ����:
		//   size:
		//     Ҫ�������õ�������С��Ŀ��
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
					if(tempNodes[i].key==0)continue;									//��������
					unsigned int curIndex=abs(tempNodes[i].key)%this->size;				//ȡ����λ��;
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
		// ժҪ:
		//	�����С,��������ǰֵ
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
		// ժҪ:
		//	����hash���С
		//
		inline int getSize(){return this->size;};
		//
		// ժҪ:
		//     ��������
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
		// ժҪ:
		//     ��ӽڵ㵽hashTable��
		//
		// ����:
		//   key:
		//     hash�ؼ��֡�
		//
		//   val:
		//     hash�ؼ��ֶ�Ӧֵ�� 			if(node->key==0){delete node;return false;}
		//
		inline bool addNode(const KEYT &key,const VALUE &val)
		{
			if(nodes==NULL)
			{
				if(this->size==0)EXP("δ����hash��ʼ����С");
				nodes=new numNode[this->size];	//����洢�ռ�
			}
			numNode *node=getNumNode(key,val);
			return addNode(node);
		};
		//�Ƴ�һ���ؼ���          ��Ҫ�ƶ�ָ��
		inline bool remove(const KEYT &key)
		{
			if(nodes==NULL)
				return false;
			unsigned int curIndex;
			curIndex=abs(key)%this->size;
			numNode * pNode=nodes + curIndex;
			if(curIndex!=0 && pNode->key==key)
			{
				if(pNode->next==0)//�޺����ڵ�
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
		// ժҪ:
		//	����������,����ֵ����
		//
		// ����:
		//   key:
		//     �ؼ���
		//
		// ���ؽ��:
		//     ����ֵ����
		//
		inline VALUE &operator[](const KEYT &key)
		{
			if(nodes==NULL)
			{
				if(this->size==0)EXP("δ����hash��ʼ����С");
				nodes=new numNode[this->size];	//����洢�ռ�
			}
			numNode *node=getNumNode(key);
			unsigned int curIndex=abs(node->key)%this->size;					//ȡ����λ��;
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
						delete node;									//�Ѿ�����
						return pNode->val;
					}
				}
				else
				{
					if(pNode->key==node->key)
					{
						delete node;									//�Ѿ�����
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
		// ժҪ:
		//	���ڴ����
		//
		inline bool find(const KEYT &key,VALUE &val,bool exp=false)
		{
			if(nodes==NULL)if(exp)EXP("û�г�ʼ���ڵ�����.")else return false;
			unsigned int curIndex;
			curIndex=abs(key)%this->size;
			numNode * pNode=nodes + curIndex;
			if(curIndex!=0 && pNode->key==0 )
			{
				return false;								//δ�ҵ�
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
			//	return false;								//δ�ҵ�
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
		// ժҪ:
		//     ���ļ�����
		//
		// ����:
		//   pkeyFile:
		//     �Ѵ򿪵Ĺؼ����ļ�ָ�롣
		//
		//   key:
		//     hash�ؼ��֡�
		//
		//   val:
		//     hash�ؼ��ֶ�Ӧ����ֵ��
		//
		//   size:
		//     hash��С��
		//
		// ���ؽ��:
		//     �Ƿ�ɹ����ҵ����ݡ�
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
			if(len!=1)	EXP("��ȡkey���ݷ�������,δ��ȡ��ָ�����ȵ�����.");
			if(curIndex!=0 && tempNode.key==0 )
			{
				return false;								//δ�ҵ�
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
		// ժҪ:
		//	���ļ�����key
		//
		inline static bool find(FILE *pkeyFile,const KEYT &key,VALUE &val,int size,bool isSeries)
		{
			if(!isSeries)							//�Ƿ�ʹ��һ��д��key�ļ�
				return find(pkeyFile,key,val,size);
			if(!pkeyFile)
				return false;
			unsigned int curIndex;
			numNode tempNode;
			curIndex=abs(key) % size;
			long long curPos=NodeSize*curIndex;
			fseek(pkeyFile, curPos, SEEK_SET);//return false;
			int len= fread(&tempNode,NodeSize,1,pkeyFile);//return false;
			if(len!=1)	EXP("��ȡkey���ݷ�������,δ��ȡ��ָ�����ȵ�����."+String(len));
			if(curIndex!=0 && tempNode.key==0 )
			{
				return false;								//δ�ҵ�
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
			//��ȡ����λ��ֵ,����I/O����
			numNode tempNodes[ONE_READ_COUNT];
			fseek(pkeyFile,tempNode.next, SEEK_SET);
			len= fread(&tempNodes,NodeSize,1,pkeyFile);
			if(len==0)	EXP("��ȡkey���ݷ�������,δ��ȡ���κ�����.");
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
		// ժҪ:
		//	���ļ�����key
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
			if(len!=1)	EXP("��ȡkey���ݷ�������,δ��ȡ��ָ�����ȵ�����.");
			if(curIndex!=0 && tempNode.key==0 )
			{
				return false;								//δ�ҵ�
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
		// ժҪ:
		//	���ļ�����key
		//
		inline bool find(FILE *pkeyFile,const KEYT &key,VALUE &val,bool isSeries)
		{
			if(!isSeries)							//�Ƿ�ʹ��һ��д��key�ļ�
				return find(pkeyFile,key,val);
			if(!pkeyFile)
				return false;
			unsigned int curIndex;
			numNode tempNode;
			curIndex=abs(key) % size;			
			long long curPos=NodeSize*curIndex;
			fseek(pkeyFile, curPos, SEEK_SET);
			int len= fread(&tempNode,NodeSize,1,pkeyFile);
			if(len!=1)	EXP("��ȡkey���ݷ�������,δ��ȡ��ָ�����ȵ�����.");
			if(tempNode.key==0 && curIndex!=0)
			{
				return false;								//δ�ҵ�
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
			//��ȡ����λ��ֵ,����I/O����
			numNode tempNodes[ONE_READ_COUNT];
			fseek(pkeyFile, tempNode.next, SEEK_SET);
			len= fread(&tempNodes,NodeSize,ONE_READ_COUNT,pkeyFile);
			if(len==0)	EXP("��ȡkey���ݷ�������,δ��ȡ���κ�����.");
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
		// ժҪ:
		//     ��hashTable����д���ļ�,д����ɾ��hashTable �е��ڴ�����
		//
		// ����:
		//   pkeyFile:
		//     �Ѵ򿪵Ĺؼ����ļ�ָ�롣
		//
		//   printAnalyse:
		//     �Ƿ��ӡhash���������
		//
		inline int writeFile(FILE *pkeyFile)					//д���ļ�
		{
			if(nodes==NULL)
			{
				if(this->size==0)EXP("δ����hash��ʼ����С");
				nodes=new numNode[this->size];	//����洢�ռ�
			}
			long long curPos=0;
			int repeatCount=0,len=0;
			numNode * pNode,* curNode,*nextNode;

			numNode tempNode=numNode();
			fseek(pkeyFile,(this->size-1) * NodeSize ,SEEK_SET);			//ֱ��д����󳤶�
			len=fwrite(&tempNode,NodeSize,1,pkeyFile);
			fflush(pkeyFile);
			long fileSize=ftell(pkeyFile);
			if(len!=1 || fileSize!=this->size*NodeSize)
				EXP("��ʼ��hash�ļ���С��������.");
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
					if(len!=1)	EXP("д��hash�ļ���������.");
					while(nextNode)
					{
						repeatCount++;
						pNode=(numNode *)(nextNode->next);
						unsigned long long nPos=((nextNode->next!=0)?1:0) * (repeatCount+this->size) * NodeSize;
						nextNode->next=nPos;
						fseek(pkeyFile, 0, SEEK_END);
						len=fwrite(nextNode,NodeSize,1,pkeyFile);
						if(len!=1)
							EXP("д��hash�ļ���������.");
						delete nextNode;
						nextNode=pNode;
					}
				}
				else
				{
					curPos= i * NodeSize;
					fseek(pkeyFile, curPos, SEEK_SET);
					len=fwrite(curNode,NodeSize,1,pkeyFile);
					if(len!=1)	EXP("д��hash�ļ���������.");
				}
			}
			delete [] nodes;
			nodes=NULL;
			return repeatCount;
		};
		//
		// ժҪ:
		//	д�ļ�
		//
		inline int writeFile(FILE *pkeyFile,bool printAnalyse)					//д���ļ�
		{
			if(nodes==NULL)
			{
				if(this->size==0)EXP("δ����hash��ʼ����С");
				nodes=new numNode[this->size];	//����洢�ռ�
			}
			if(!printAnalyse)
				return writeFile(pkeyFile);
			long long curPos=0;
			int repeatCount=0,len=0;
			numNode * pNode,* curNode,*nextNode;

			numNode tempNode=numNode();
			fseek(pkeyFile,(this->size-1) * NodeSize ,SEEK_SET);			//ֱ��д����󳤶�
			len=fwrite(&tempNode,NodeSize,1,pkeyFile);
			fflush(pkeyFile);
			long fileSize=ftell(pkeyFile);
			if(len!=1 || fileSize!=this->size*NodeSize)
				EXP("��ʼ��hash�ļ���С��������.");
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
					if(len!=1)	EXP("д��hash�ļ���������.");
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
							EXP("д��hash�ļ���������.");
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
					if(len!=1)	EXP("д��hash�ļ���������.");
				}
			}
			delete [] nodes;
			nodes=NULL;
			cout<<"hash�������: "<< distributing[0] <<endl;
			int countPos=0;
			for(int i=1;i<distributing.size();i++)
			{
				countPos+=distributing[i];
			}
			if(countPos>0)
			{
				for(int i=1;i<distributing.size();i++)
				{
					cout<<"hash "<<i<<" �ζ�λ��: "<< distributing[i] <<" ռ��: "<< (double)distributing[i]/countPos <<endl;
				}
			}
			cout<<"hash��ʹ����: "<< (double)distributing[1]*100/this->size <<endl;
			distributing.clear();
			return repeatCount;
		};
		//
		// ժҪ:
		//     ֱ�ӽ�KEYд���ļ�
		//
		// ����:
		//   pkeyFile:
		//     in �Ѵ򿪵Ĺؼ����ļ�ָ�롣
		//
		//   key:
		//     in hash�ؼ��֡�
		//
		//   val:
		//     in hash�ؼ��ֶ�Ӧ����ֵ��
		//
		//   repeatCount:
		//     in/out hash�����ظ�ֵ��С����һ�ε���ǰ�� 0
		//
		inline static void writeFile(FILE *pkeyFile,const KEYT &key,const VALUE &val,int &repeatCount,int size)
		{
			if(!pkeyFile)EXP("key�ļ�ָ��Ϊ��.");
			//ֱ��д���ļ�
			int len=0;
			numNode *node=getNumNode(key,val);
			unsigned int curIndex=abs(node->key) % size;					//ȡ����λ��;
			long long curPos=NodeSize*curIndex;
			fseek(pkeyFile, curPos, SEEK_SET);
			numNode tempNode;
			len= fread(&tempNode,NodeSize,1,pkeyFile);
			if(len!=1)	EXP("��ȡkey���ݷ�������,δ��ȡ��ָ�����ȵ�����.");
			if(tempNode.key==0 && curIndex!=0)
			{
				fseek(pkeyFile, curPos, SEEK_SET);
				len=fwrite(node,NodeSize,1,pkeyFile);
				if(len!=1)	EXP("д��hash�ļ���������.");
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
					EXP("����hash�ļ��нڵ㷢������.");
				fseek(pkeyFile, 0, SEEK_END);
				len=fwrite(node,NodeSize,1,pkeyFile);
				if(len!=1)
					EXP("д��hash�ļ���������.");
				delete node;
				repeatCount++;
			}
		};
		//
		// ժҪ:
		//	��ȡ��hash�ڵ��ָ��
		//
		inline static numNode * getNumNode(const KEYT &key,const VALUE &val)
		{
			return new numNode(key,val);
		};
		//
		// ժҪ:
		//	��ȡ��hash�ڵ��ָ��
		//
		inline static numNode * getNumNode(const KEYT &key)
		{
			return new numNode(key);
		};
		//
		// ժҪ:
		//	����hash��
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
		// ժҪ:
		//	��ȡhash�����
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
