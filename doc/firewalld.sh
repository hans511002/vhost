firewall-cmd --list-all
firewall-cmd --zone=public --list-rich-rule

# 打开端口
firewall-cmd --zone=public --add-port=80/tcp --permanent
 
firewall-cmd --zone=public --add-interface=eth0

# 组播 vrrp
    firewall-cmd --direct  --add-rule ipv4 filter INPUT 0   --protocol vrrp -j ACCEPT 
    firewall-cmd --direct  --add-rule ipv4 filter INPUT 0   --protocol 112 -j ACCEPT 
    firewall-cmd --direct  --permanent --add-rule ipv4 filter INPUT 0   --protocol vrrp -j ACCEPT 
    firewall-cmd --direct  --permanent --add-rule ipv4 filter INPUT 0   --protocol 112 -j ACCEPT 
    
    
firewall-cmd --zone=public --add-port=3306/tcp
firewall-cmd --zone=public --add-rich-rule="rule family="ipv4" source address="172.16.131.0/24" port protocol="tcp" port="1-65535"  accept" 

firewall-cmd --zone=public --remove-rich-rule="rule family="ipv4" source address="172.16.130.0/24" port port="1-65535" protocol="tcp" accept" 


firewall-cmd --zone=public --add-rich-rule="rule family="ipv4" source address="172.16.130.0/24" port protocol="tcp" port="1-65535"  reject" 

firewall-cmd --zone=public --add-rich-rule="rule family="ipv4" source address="172.16.131.0/24" service name="vrrp"   accept" 

firewall-cmd --direct  --add-rule ipv4 filter INPUT 0  --in-interface eth0 --destination 172.16.131.130 --protocol vrrp -j ACCEPT 

firewall-cmd --direct  --add-rule ipv4 filter INPUT 0   --protocol 112 -j ACCEPT 


firewall-cmd --permanent --zone=public --add-rich-rule="rule family="ipv4" source address="172.16.131.0/24" port protocol="tcp" port="3306"  accept"
firewall-cmd --permanent --zone=public --add-rich-rule="rule family="ipv4" source address="172.16.130.0/24" port protocol="tcp" port="3306"  accept"
firewall-cmd --permanent --zone=public --add-rich-rule="rule family="ipv4" source address="172.16.130.0/24" port protocol="tcp" port="3306"  reject" 
 firewall-cmd --permanent --zone=public --add-rich-rule="rule family="ipv4" source address="172.16.130.0/24" service name="ssh" reject" 

 
firewall-cmd --reload #重启firewall
systemctl stop firewalld.service #停止firewall
systemctl disable firewalld.service #禁止firewall开机启动 


iptables -I INPUT -p tcp --dport 80 -j ACCEPT


查看版本：$ firewall-cmd --version
查看帮助：$ firewall-cmd --help
查看设置：
                显示状态：$ firewall-cmd --state
                查看区域信息: $ firewall-cmd --get-active-zones
                查看指定接口所属区域：$ firewall-cmd --get-zone-of-interface=eth0
拒绝所有包：# firewall-cmd --panic-on
取消拒绝状态：# firewall-cmd --panic-off
查看是否拒绝：$ firewall-cmd --query-panic
 
更新防火墙规则：# firewall-cmd --reload
               # firewall-cmd --complete-reload
    两者的区别就是第一个无需断开连接，就是firewalld特性之一动态添加规则，第二个需要断开连接，类似重启服务
 
将接口添加到区域，默认接口都在public
# firewall-cmd --zone=public --add-interface=eth0
# firewall-cmd --zone=public --change-interface=eth0
# firewall-cmd --zone=public --remove-interface=eth0
# firewall-cmd --zone=public --query-interface=eth0
永久生效再加上 --permanent 然后reload防火墙

设置默认接口区域
# firewall-cmd --set-default-zone=public
立即生效无需重启
 
打开端口（貌似这个才最常用）
查看所有打开的端口：
# firewall-cmd --zone=dmz --list-ports
加入一个端口到区域：
# firewall-cmd --zone=dmz --add-port=8080/tcp
若要永久生效方法同上
 
打开一个服务，类似于将端口可视化，服务需要在配置文件中添加，/etc/firewalld 目录下有services文件夹，这个不详细说了，详情参考文档
# firewall-cmd --zone=work --add-service=smtp
 
移除服务
# firewall-cmd --zone=work --remove-service=smtp

