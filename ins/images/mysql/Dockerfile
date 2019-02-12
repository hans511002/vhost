FROM centos
RUN  echo "root:hans" | chpasswd && groupadd -r mysql && useradd -r -g mysql mysql \
 && mkdir -p /etc/mysql/ /var/lib/mysql/ && mkdir -p /var/log/mysql \
 && chown -R mysql:mysql /var/log/mysql && mkdir -p /var/lib/mysql && chown -R mysql:mysql /var/lib/mysql  && \
  mkdir -p /var/run/mysqld && chown -R mysql:mysql /var/run/mysqld
COPY files/ /etc/mysql/

RUN chmod +x /etc/mysql/mysqld.sh && mv /etc/mysql/_my.cnf /usr/my.cnf \
&& rpm --import "http://releases.galeracluster.com/GPG-KEY-galeracluster.com" \
&& yum install -y yum-utils  \
&& yum-config-manager --add-repo http://releases.galeracluster.com/mysql-wsrep-5.6/centos/7/x86_64/ \
&& yum-config-manager --add-repo http://releases.galeracluster.com/galera-3/centos/7/x86_64/

RUN yum install -y which galera-3 rsync lsof tcping \
&& rm -rf /etc/yum.repos.d/releases.galeracluster.com_centos_7_x86_64_.repo \
&& yum install -y mysql-wsrep-5.6 \
&& yum clean all && rm -rf /var/lib/mysql/* /tmp/* /etc/my.cnf /usr/my.cnf /usr/my-new.cnf
WORKDIR /etc/mysql
EXPOSE 3306 4444 4567 4568
CMD ["/etc/mysql/mysqld.sh","--defaults-file=/etc/mysql/my.cnf"]
