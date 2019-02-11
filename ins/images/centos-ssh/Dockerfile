#centos base
FROM hans/centos
ENV TERM Xterm
CMD ["/usr/sbin/sshd","-D"]
RUN localedef -i zh_CN -f UTF-8 -A /usr/share/locale/locale.alias zh_CN && localedef -i en_US -f UTF-8 -A /usr/share/locale/locale.alias en_US \
    && echo "LANG=\"en_US.UTF-8\"" > /etc/locale.conf  \
    && echo "root:PassW0rd" | chpasswd && yum -y install epel-release \
    && yum install -y openssh-server openssh-clients which  && yum clean all 
ADD files/* /tmp/
RUN mkdir /var/run/sshd && chmod +x /tmp/*.sh \
 && cp /tmp/0*.sh /etc/profile.d/   \
 && cp /tmp/*.sh /bin/ \
 &&  /bin/prep_for_ssh.sh  \
 && rm -rf /tmp/*
