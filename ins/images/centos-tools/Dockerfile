#centos base
FROM centos
ENV TERM Xterm
ADD files/0alias.sh /etc/profile.d/ 
RUN localedef -i zh_CN -f UTF-8 -A /usr/share/locale/locale.alias zh_CN && localedef -i en_US -f UTF-8 -A /usr/share/locale/locale.alias en_US \
    && echo "LANG=\"en_US.UTF-8\"" > /etc/locale.conf  \
    && yum -y install epel-release  \
    && yum install -y less which curl nmap nc bc wget socat lsof lsscsi net-tools psmisc nfs-utils  iproute traceroute  bind-utils net-tools  \
    && yum clean all 
