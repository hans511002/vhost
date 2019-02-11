FROM openjdk
#gcc make expat-devel openssl-devel 
RUN yum install  -y apr apr-iconv apr-devel apr-util openssl \
&& mkdir /app \
&& yum clean all

ADD tomcat9.tar.gz /app/
WORKDIR /app/tomcat-9
CMD ["bin/catalina.sh","run"]

#RUN cd /app/tomcat-9/bin/ && tar xf tomcat-native.tar.gz && cd /app/tomcat-9/bin/tomcat-native-1.2.19-src/native \
#&& ./configure --prefix=/app/tomcat-9 --with-java-home=/usr/local/jdk1.8.0_201 && make && make install && cd /app/tomcat-9 \
#&& rm -rf /app/tomcat-9/bin/tomcat-native-1.2.19-src


