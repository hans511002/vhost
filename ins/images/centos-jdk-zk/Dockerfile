#zk:3.4.6 
FROM centos-jdk:1.8.0
MAINTAINER hans 
ADD zookeeper-3.4.6.tar.gz /
RUN mkdir /data && mkdir /logs && echo "1">/data/myid
EXPOSE 2181
CMD ["/zookeeper-3.4.6/bin/zkServer.sh","start-foreground"]



#docker run --name=docker_zk -p 2181:2181 --privileged=true -v /app/ins/app/docker_zk-3.4.6/conf:/zookeeper-3.4.6/conf -v /app/ins/app/docker_zk-3.4.6/data:/data -v /app/ins/app/docker_zk-3.4.6/logs:/logs --add-host=hnode01:172.16.131.36 --add-host=hnode02:172.16.131.37 --add-host=hnode03:172.16.131.39 -d sobey/zookeeper /run.sh
