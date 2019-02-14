#!/bin/bash
BIN=$(cd $(dirname $0); pwd)
cd $BIN
yum install -y yum-utils 
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    # ins host
    dockerVersion=`yum list docker-ce|grep docker-ce.x86_64 |sed -e "s|docker-ce.x86_64 *||" -e "s| .*||" -e "s|.*:||" -e "s|-.*||"`
    scp -rp docker-version docker-$dockerVersion
    tar zcf docker-$dockerVersion.tar.gz docker-$dockerVersion

