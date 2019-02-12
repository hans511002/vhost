FROM  centos
ADD haproxy* /usr/sbin/
#RUN yum install -y socat && yum clean all 
ENTRYPOINT ["/usr/sbin/haproxy-systemd-wrapper","-p","/run/haproxy.pid"]
CMD ["-f","/etc/haproxy/haproxy.cfg"]
