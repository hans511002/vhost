CC = g++
LFLAGS        = -w #-ggdb3
#-Wall -Wextra 
#INCPATH       = -I/usr/share/qt4/mkspecs/linux-g++ -I. -I/usr/include/qt4/QtCore -I/usr/include/qt4/QtGui -I/usr/include/qt4 -I. -I.
LINK          = g++
#LIBS          = -L/usr/lib/i386-linux-gnu  -L/usr/local/lib  -lpcap -lQtGui -lQtCore -lpthread 
LIBS          =  -L/usr/local/lib64  -lpcap -lpthread -lncurses 

OBJ           =  packet.o inodeport.o main.o process.o cui.o 
#maindialog.o
TERGET        =  netpcap

netpcap: $(OBJ)
	$(LINK) -o $@ $(OBJ) $(LIBS)  $(LFLAGS)

packet.o: packet_cap.cpp  packet_cap.h mempool.h
	$(CC) -c packet_cap.cpp -o packet.o $(LFLAGS)

inodeport.o: inodeport.cpp inodeport.h
	$(CC) -c inodeport.cpp -o inodeport.o $(LFLAGS)

main.o:main.cpp 
	$(CC) -c main.cpp $(LFLAGS) $(INCPATH)

process.o: process.cpp process.h
	$(CC) -c process.cpp $(LFLAGS)

cui.o : cui.h cui.cpp
	$(CC) -c cui.cpp $(LFLAGS) $(INCPATH)

clean:
	rm -f $(OBJ) $(TERGET)
	rm -f *~
	
	





