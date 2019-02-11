#!/usr/bin/env bash
#

#cpu:
#--cpu-shares 1024 权重
# --cpuset-cpus=0,1 CPU 核心索引
#docker run -it --rm -m 210m --memory-swap 10G --memory-reservation 60M --oom-kill-disable --memory-swappiness=100
# --cpu-shares 1024 --cpuset-cpus=0,1

#--oom-kill-disable oom不kill
#-m --memory 硬性限制
#--memory-reservation 会尽可能回收到这个限制下
#--memory-swappiness=0 交换内存使用百分比
#--memory-swap 总的内存大小，交换内存大小=总的-物理内存
#

# 磁盘在run时只能设定权重
# --blkio-weight=0 Block IO (relative weight), between 10 and 1000
#
#将IO带宽限制为10M/s：
#echo "253:1 10485760" > /sys/fs/cgroup/blkio/docker/$CONTAINER_ID/blkio.throttle.write_bps_device
#或者
#/usr/bin/nsenter --target $(docker inspect -f '{{ .State.Pid }}' $CONTAINER_ID) --mount --uts --ipc --net --pid mount | head -1 | awk '{ print $1 }'
#systemctl set-property --runtime docker-d2115072c442b0453b3df3b16e8366ac9fd3defd4cecd182317a6f195dab3b88.scope "BlockIOWriteBandwidth=/dev/mapper/docker-253:0-3408580-d2115072c442b0453b3df3b16e8366ac9fd3defd4cecd182317a6f195dab3b88 10M"
#
# docker 1.10 支持
# --blkio-weight Block IO (relative weight), between 10 and 1000
# --blkio-weight-device=[] Block IO weight (relative device weight)
# --device=[] Add a host device to the container
# --device-read-bps=[] Limit read rate (bytes per second) from a device
# --device-read-iops=[] Limit read rate (IO per second) from a device
# --device-write-bps=[] Limit write rate (bytes per second) to a device
# --device-write-iops=[] Limit write rate (IO per second) to a device
#
# 
#此文件因在环境初始化调用, 不能有输出信息, 并且不能报错 


cpus=`grep -c "processor.*:.*[0-9]" /proc/cpuinfo`
totalMems=`grep MemTotal /proc/meminfo |awk '{print $2}'` #kb
if [ "$totalMems" -gt "10240000" ] ; then # gt 10G
    totalMems=`expr $totalMems \* 10 / 1000 / 1024 / 100 \* 100 `
else
    totalMems=`expr $totalMems \* 10 / 1000 / 1024 / 10 \* 10 `
fi
#echo "cpu processors $cpus"
#echo "totalMems=${totalMems}00M"
# cpuArg="--cpu-shares 1024"
cpuArg=""
if [ "$cpus" = "32" ] ; then
    export MYSQL_RESOURCES="$cpuArg                  --cpuset-cpus=4-12 "
    export MONGO_RESOURCES="$cpuArg                  --cpuset-cpus=4-14 "
    export CODIS_RESOURCES="$cpuArg                  --cpuset-cpus=8-16 "
    export FTENGINE2_RESOURCES="$cpuArg              --cpuset-cpus=12-17 "
    export KAFKA_RESOURCES="$cpuArg                  --cpuset-cpus=15-18 "
    export HIVECORE_RESOURCES="$cpuArg               --cpuset-cpus=14-20 "
    export HIVEPMP_RESOURCES="$cpuArg                --cpuset-cpus=20-24 "
    export NEBULA_RESOURCES="$cpuArg                 --cpuset-cpus=19-23 "
    export EAGLES_RESOURCES="$cpuArg                 --cpuset-cpus=24-29 "
    export LOGSTASH_RESOURCES="$cpuArg               --cpuset-cpus=25-26 "
    export KIBANA_RESOURCES="$cpuArg                 --cpuset-cpus=25-26 "
    export CMSERVER_RESOURCES="$cpuArg               --cpuset-cpus=20-24 "
    export CMWEB_RESOURCES="$cpuArg                  --cpuset-cpus=20-24 "
    export INGESTDBSVR_RESOURCES="$cpuArg            --cpuset-cpus=27-31 "
    export INGESTMSGSVR_RESOURCES="$cpuArg           --cpuset-cpus=27-31 "
    export MOSGATEWAY_RESOURCES="$cpuArg             --cpuset-cpus=27-31 "
    export JOVE_RESOURCES="$cpuArg                   --cpuset-cpus=24-29 "
    export OTCSERVER_RESOURCES="$cpuArg              --cpuset-cpus=27-31 "
    export FLOATINGLICENSESERVER_RESOURCES="$cpuArg  --cpuset-cpus=27-31 "
    export INFOSHARE_RESOURCES="$cpuArg              --cpuset-cpus=22-30 "
    export NTAG_RESOURCES="$cpuArg                   --cpuset-cpus=27-31 "
elif [ "$cpus" = "40" ] ; then 
    export MYSQL_RESOURCES="$cpuArg                  --cpuset-cpus=6-18 "
    export MONGO_RESOURCES="$cpuArg                  --cpuset-cpus=7-19 "
    export CODIS_RESOURCES="$cpuArg                  --cpuset-cpus=10-16 "
    export FTENGINE2_RESOURCES="$cpuArg              --cpuset-cpus=10-18 "
    export KAFKA_RESOURCES="$cpuArg                  --cpuset-cpus=16-23 "
    export HIVECORE_RESOURCES="$cpuArg               --cpuset-cpus=19-28 "
    export HIVEPMP_RESOURCES="$cpuArg                --cpuset-cpus=20-26 "
    export NEBULA_RESOURCES="$cpuArg                 --cpuset-cpus=30-39 "
    export EAGLES_RESOURCES="$cpuArg                 --cpuset-cpus=28-39 "
    export LOGSTASH_RESOURCES="$cpuArg               --cpuset-cpus=25-27 "
    export KIBANA_RESOURCES="$cpuArg                 --cpuset-cpus=25-27 "
    export CMSERVER_RESOURCES="$cpuArg               --cpuset-cpus=20-30 "
    export CMWEB_RESOURCES="$cpuArg                  --cpuset-cpus=25-30 "
    export INGESTDBSVR_RESOURCES="$cpuArg            --cpuset-cpus=22-26 "
    export INGESTMSGSVR_RESOURCES="$cpuArg           --cpuset-cpus=22-25 "
    export MOSGATEWAY_RESOURCES="$cpuArg             --cpuset-cpus=22-26 "
    export JOVE_RESOURCES="$cpuArg                   --cpuset-cpus=25-32 "
    export OTCSERVER_RESOURCES="$cpuArg              --cpuset-cpus=37-39 "
    export FLOATINGLICENSESERVER_RESOURCES="$cpuArg  --cpuset-cpus=33-36 "
    export INFOSHARE_RESOURCES="$cpuArg              --cpuset-cpus=20-25 "
    export NTAG_RESOURCES="$cpuArg                   --cpuset-cpus=26-32 "
elif [ "$cpus" -gt "40" ] ; then
    cpus="`expr $cpus - 8`"
    A="8-`expr $cpus / 4 + 8`"
    B="`expr $cpus / 4 + 8`-`expr $cpus / 2 + 8`" 
    B="`expr $cpus / 2 + 8`-`expr $cpus \* 3 / 4 + 8`" 
    D="`expr $cpus \* 3 / 4 + 8`-`expr $cpus - 1 + 8`" 

    export MYSQL_RESOURCES="$cpuArg                  --cpuset-cpus=$A "
    export MONGO_RESOURCES="$cpuArg                  --cpuset-cpus=$B "
    export CODIS_RESOURCES="$cpuArg                  --cpuset-cpus=$C "
    export FTENGINE2_RESOURCES="$cpuArg              --cpuset-cpus=$C "
    export KAFKA_RESOURCES="$cpuArg                  --cpuset-cpus=$D "
    export HIVECORE_RESOURCES="$cpuArg               --cpuset-cpus=$B "
    export HIVEPMP_RESOURCES="$cpuArg                --cpuset-cpus=$B "
    export NEBULA_RESOURCES="$cpuArg                 --cpuset-cpus=$A "
    export EAGLES_RESOURCES="$cpuArg                 --cpuset-cpus=$D "
    export LOGSTASH_RESOURCES="$cpuArg               --cpuset-cpus=$C "
    export KIBANA_RESOURCES="$cpuArg                 --cpuset-cpus=$D "
    export CMSERVER_RESOURCES="$cpuArg               --cpuset-cpus=$D "
    export CMWEB_RESOURCES="$cpuArg                  --cpuset-cpus=$C "
    export INGESTDBSVR_RESOURCES="$cpuArg            --cpuset-cpus=$B "
    export INGESTMSGSVR_RESOURCES="$cpuArg           --cpuset-cpus=$C "
    export MOSGATEWAY_RESOURCES="$cpuArg             --cpuset-cpus=$C "
    export JOVE_RESOURCES="$cpuArg                   --cpuset-cpus=$A "
    export OTCSERVER_RESOURCES="$cpuArg              --cpuset-cpus=$D "
    export FLOATINGLICENSESERVER_RESOURCES="$cpuArg  --cpuset-cpus=$D "
    export INFOSHARE_RESOURCES="$cpuArg              --cpuset-cpus=$A "
    export NTAG_RESOURCES="$cpuArg                   --cpuset-cpus=$D "
else # if [ "$cpus" -lt "32" ] ; then  # 24c 16c
    A="0-`expr $cpus / 2`"
    B="`expr $cpus / 2`-`expr $cpus - 1`"
    export MYSQL_RESOURCES="$cpuArg                  --cpuset-cpus=$A "
    export MONGO_RESOURCES="$cpuArg                  --cpuset-cpus=$B "
    export CODIS_RESOURCES="$cpuArg                  --cpuset-cpus=$A "
    export FTENGINE2_RESOURCES="$cpuArg              --cpuset-cpus=$A "
    export KAFKA_RESOURCES="$cpuArg                  --cpuset-cpus=$B "
    export HIVECORE_RESOURCES="$cpuArg               --cpuset-cpus=$B "
    export HIVEPMP_RESOURCES="$cpuArg                --cpuset-cpus=$B "
    export NEBULA_RESOURCES="$cpuArg                 --cpuset-cpus=$A "
    export EAGLES_RESOURCES="$cpuArg                 --cpuset-cpus=$A "
    export LOGSTASH_RESOURCES="$cpuArg               --cpuset-cpus=$B "
    export KIBANA_RESOURCES="$cpuArg                 --cpuset-cpus=$A "
    export CMSERVER_RESOURCES="$cpuArg               --cpuset-cpus=$B "
    export CMWEB_RESOURCES="$cpuArg                  --cpuset-cpus=$A "
    export INGESTDBSVR_RESOURCES="$cpuArg            --cpuset-cpus=$B "
    export INGESTMSGSVR_RESOURCES="$cpuArg           --cpuset-cpus=$B "
    export MOSGATEWAY_RESOURCES="$cpuArg             --cpuset-cpus=$A "
    export JOVE_RESOURCES="$cpuArg                   --cpuset-cpus=$A "
    export OTCSERVER_RESOURCES="$cpuArg              --cpuset-cpus=$B "
    export FLOATINGLICENSESERVER_RESOURCES="$cpuArg  --cpuset-cpus=$B "
    export INFOSHARE_RESOURCES="$cpuArg              --cpuset-cpus=$A "
    export NTAG_RESOURCES="$cpuArg                   --cpuset-cpus=$B "
fi

#memory limit
# memoryArg="--memory-swappiness=0"
#某些虚拟机不支持此参数，置空
memoryArg=""
if [ "$totalMems" -lt "400" ] ; then
    export MYSQL_RESOURCES="$MYSQL_RESOURCES                                    -m `expr  $totalMems \* 80  `m $memoryArg "
    export MONGO_RESOURCES="$MONGO_RESOURCES                                    -m `expr  $totalMems \* 80  `m $memoryArg "
    export CODIS_RESOURCES="$CODIS_RESOURCES                                    -m `expr  $totalMems \* 80  `m $memoryArg "
    export FTENGINE2_RESOURCES="$FTENGINE2_RESOURCES                            -m `expr  $totalMems \* 80  `m $memoryArg "
    export KAFKA_RESOURCES="$KAFKA_RESOURCES                                    -m `expr  $totalMems \* 80  `m $memoryArg "
    export HIVECORE_RESOURCES="$HIVECORE_RESOURCES                              -m `expr  $totalMems \* 80  `m $memoryArg "
    export HIVEPMP_RESOURCES="$HIVEPMP_RESOURCES                                -m `expr  $totalMems \* 80  `m $memoryArg "
    export NEBULA_RESOURCES="$NEBULA_RESOURCES                                  -m `expr  $totalMems \* 80  `m $memoryArg "
    export EAGLES_RESOURCES="$EAGLES_RESOURCES                                  -m `expr  $totalMems \* 80  `m $memoryArg "
    export LOGSTASH_RESOURCES="$LOGSTASH_RESOURCES                              -m `expr  $totalMems \* 80  `m $memoryArg "
    export KIBANA_RESOURCES="$KIBANA_RESOURCES                                  -m `expr  $totalMems \* 80  `m $memoryArg "
    export CMSERVER_RESOURCES="$CMSERVER_RESOURCES                              -m `expr  $totalMems \* 80  `m $memoryArg "
    export CMWEB_RESOURCES="$CMWEB_RESOURCES                                    -m `expr  $totalMems \* 80  `m $memoryArg "
    export INGESTDBSVR_RESOURCES="$INGESTDBSVR_RESOURCES                        -m `expr  $totalMems \* 80  `m $memoryArg "
    export INGESTMSGSVR_RESOURCES="$INGESTMSGSVR_RESOURCES                      -m `expr  $totalMems \* 80  `m $memoryArg "
    export MOSGATEWAY_RESOURCES="$MOSGATEWAY_RESOURCES                          -m `expr  $totalMems \* 80  `m $memoryArg "
    export JOVE_RESOURCES="$JOVE_RESOURCES                                      -m `expr  $totalMems \* 80  `m $memoryArg "
    export OTCSERVER_RESOURCES="$OTCSERVER_RESOURCES                            -m `expr  $totalMems \* 80  `m $memoryArg "
    export FLOATINGLICENSESERVER_RESOURCES="$FLOATINGLICENSESERVER_RESOURCES    -m `expr  $totalMems \* 80  `m $memoryArg "
    export INFOSHARE_RESOURCES="$INFOSHARE_RESOURCES                            -m `expr  $totalMems \* 80  `m $memoryArg "
    export NTAG_RESOURCES="$NTAG_RESOURCES                                      -m `expr  $totalMems \* 80  `m $memoryArg "
elif [ "$totalMems" -le "600" ] ; then
    export MYSQL_RESOURCES="$MYSQL_RESOURCES                                    -m `expr  $totalMems \* 30  `m $memoryArg "
    export MONGO_RESOURCES="$MONGO_RESOURCES                                    -m `expr  $totalMems \* 30  `m $memoryArg "
    export CODIS_RESOURCES="$CODIS_RESOURCES                                    -m `expr  $totalMems \* 15  `m $memoryArg "
    export FTENGINE2_RESOURCES="$FTENGINE2_RESOURCES                            -m `expr  $totalMems \* 15  `m $memoryArg "
    export KAFKA_RESOURCES="$KAFKA_RESOURCES                                    -m `expr  $totalMems \* 05  `m $memoryArg "
    export HIVECORE_RESOURCES="$HIVECORE_RESOURCES                              -m `expr  $totalMems \* 30  `m $memoryArg "
    export HIVEPMP_RESOURCES="$HIVEPMP_RESOURCES                                -m `expr  $totalMems \* 20  `m $memoryArg "
    export NEBULA_RESOURCES="$NEBULA_RESOURCES                                  -m `expr  $totalMems \* 05  `m $memoryArg "
    export EAGLES_RESOURCES="$EAGLES_RESOURCES                                  -m `expr  $totalMems \* 30  `m $memoryArg "
    export LOGSTASH_RESOURCES="$LOGSTASH_RESOURCES                              -m `expr  $totalMems \* 04  `m $memoryArg "
    export KIBANA_RESOURCES="$KIBANA_RESOURCES                                  -m `expr  $totalMems \* 04  `m $memoryArg "
    export CMSERVER_RESOURCES="$CMSERVER_RESOURCES                              -m `expr  $totalMems \* 10  `m $memoryArg "
    export CMWEB_RESOURCES="$CMWEB_RESOURCES                                    -m `expr  $totalMems \* 04  `m $memoryArg "
    export INGESTDBSVR_RESOURCES="$INGESTDBSVR_RESOURCES                        -m `expr  $totalMems \* 04  `m $memoryArg "
    export INGESTMSGSVR_RESOURCES="$INGESTMSGSVR_RESOURCES                      -m `expr  $totalMems \* 04  `m $memoryArg "
    export MOSGATEWAY_RESOURCES="$MOSGATEWAY_RESOURCES                          -m `expr  $totalMems \* 04  `m $memoryArg "
    export JOVE_RESOURCES="$JOVE_RESOURCES                                      -m `expr  $totalMems \* 05  `m $memoryArg "
    export OTCSERVER_RESOURCES="$OTCSERVER_RESOURCES                            -m `expr  $totalMems \* 04  `m $memoryArg "
    export FLOATINGLICENSESERVER_RESOURCES="$FLOATINGLICENSESERVER_RESOURCES    -m `expr  $totalMems \* 04  `m $memoryArg "
    export INFOSHARE_RESOURCES="$INFOSHARE_RESOURCES                            -m `expr  $totalMems \* 15  `m $memoryArg "
    export NTAG_RESOURCES="$NTAG_RESOURCES                                      -m `expr  $totalMems \* 04  `m $memoryArg "   
    
# elif [ "$totalMems" -lt "400" ] ; then

    # export MYSQL_RESOURCES="$MYSQL_RESOURCES                                    -m `expr  $totalMems \* 25  `m $memoryArg "
    # export MONGO_RESOURCES="$MONGO_RESOURCES                                    -m `expr  $totalMems \* 35  `m $memoryArg "
    # export CODIS_RESOURCES="$CODIS_RESOURCES                                    -m `expr  $totalMems \* 20  `m $memoryArg "
    # export FTENGINE2_RESOURCES="$FTENGINE2_RESOURCES                            -m `expr  $totalMems \* 25  `m $memoryArg "
    # export KAFKA_RESOURCES="$KAFKA_RESOURCES                                    -m `expr  $totalMems \* 10  `m $memoryArg "
    # export HIVECORE_RESOURCES="$HIVECORE_RESOURCES                              -m `expr  $totalMems \* 20  `m $memoryArg "
    # export NEBULA_RESOURCES="$NEBULA_RESOURCES                                  -m `expr  $totalMems \* 10  `m $memoryArg "
    # export EAGLES_RESOURCES="$EAGLES_RESOURCES                                  -m `expr  $totalMems \* 25  `m $memoryArg "
    # export LOGSTASH_RESOURCES="$LOGSTASH_RESOURCES                              -m `expr  $totalMems \* 05  `m $memoryArg "
    # export KIBANA_RESOURCES="$KIBANA_RESOURCES                                  -m `expr  $totalMems \* 05  `m $memoryArg "
    # export CMSERVER_RESOURCES="$CMSERVER_RESOURCES                              -m `expr  $totalMems \* 10  `m $memoryArg "
    # export CMWEB_RESOURCES="$CMWEB_RESOURCES                                    -m `expr  $totalMems \* 05  `m $memoryArg "
    # export INGESTDBSVR_RESOURCES="$INGESTDBSVR_RESOURCES                        -m `expr  $totalMems \* 05  `m $memoryArg "
    # export INGESTMSGSVR_RESOURCES="$INGESTMSGSVR_RESOURCES                      -m `expr  $totalMems \* 05  `m $memoryArg "
    # export MOSGATEWAY_RESOURCES="$MOSGATEWAY_RESOURCES                          -m `expr  $totalMems \* 05  `m $memoryArg "
    # export JOVE_RESOURCES="$JOVE_RESOURCES                                      -m `expr  $totalMems \* 10  `m $memoryArg "
    # export OTCSERVER_RESOURCES="$OTCSERVER_RESOURCES                            -m `expr  $totalMems \* 10  `m $memoryArg "
    # export FLOATINGLICENSESERVER_RESOURCES="$FLOATINGLICENSESERVER_RESOURCES    -m `expr  $totalMems \* 05  `m $memoryArg "
    # export INFOSHARE_RESOURCES="$INFOSHARE_RESOURCES                            -m `expr  $totalMems \* 15  `m $memoryArg "
    # export NTAG_RESOURCES="$NTAG_RESOURCES                                      -m `expr  $totalMems \* 05  `m $memoryArg "

elif [ "$totalMems" -lt "640" ] ; then
    export MYSQL_RESOURCES="$MYSQL_RESOURCES                                    -m `expr  $totalMems \* 20  `m $memoryArg "
    export MONGO_RESOURCES="$MONGO_RESOURCES                                    -m `expr  $totalMems \* 30  `m $memoryArg "
    export CODIS_RESOURCES="$CODIS_RESOURCES                                    -m `expr  $totalMems \* 15  `m $memoryArg "
    export FTENGINE2_RESOURCES="$FTENGINE2_RESOURCES                            -m `expr  $totalMems \* 15  `m $memoryArg "
    export KAFKA_RESOURCES="$KAFKA_RESOURCES                                    -m `expr  $totalMems \* 05  `m $memoryArg "
    export HIVECORE_RESOURCES="$HIVECORE_RESOURCES                              -m `expr  $totalMems \* 15  `m $memoryArg "
    export HIVEPMP_RESOURCES="$HIVEPMP_RESOURCES                                -m `expr  $totalMems \* 10  `m $memoryArg "
    export NEBULA_RESOURCES="$NEBULA_RESOURCES                                  -m `expr  $totalMems \* 05  `m $memoryArg "
    export EAGLES_RESOURCES="$EAGLES_RESOURCES                                  -m `expr  $totalMems \* 20  `m $memoryArg "
    export LOGSTASH_RESOURCES="$LOGSTASH_RESOURCES                              -m `expr  $totalMems \* 04  `m $memoryArg "
    export KIBANA_RESOURCES="$KIBANA_RESOURCES                                  -m `expr  $totalMems \* 04  `m $memoryArg "
    export CMSERVER_RESOURCES="$CMSERVER_RESOURCES                              -m `expr  $totalMems \* 10  `m $memoryArg "
    export CMWEB_RESOURCES="$CMWEB_RESOURCES                                    -m `expr  $totalMems \* 04  `m $memoryArg "
    export INGESTDBSVR_RESOURCES="$INGESTDBSVR_RESOURCES                        -m `expr  $totalMems \* 04  `m $memoryArg "
    export INGESTMSGSVR_RESOURCES="$INGESTMSGSVR_RESOURCES                      -m `expr  $totalMems \* 04  `m $memoryArg "
    export MOSGATEWAY_RESOURCES="$MOSGATEWAY_RESOURCES                          -m `expr  $totalMems \* 04  `m $memoryArg "
    export JOVE_RESOURCES="$JOVE_RESOURCES                                      -m `expr  $totalMems \* 05  `m $memoryArg "
    export OTCSERVER_RESOURCES="$OTCSERVER_RESOURCES                            -m `expr  $totalMems \* 04  `m $memoryArg "
    export FLOATINGLICENSESERVER_RESOURCES="$FLOATINGLICENSESERVER_RESOURCES    -m `expr  $totalMems \* 04  `m $memoryArg "
    export INFOSHARE_RESOURCES="$INFOSHARE_RESOURCES                            -m `expr  $totalMems \* 15  `m $memoryArg "
    export NTAG_RESOURCES="$NTAG_RESOURCES                                      -m `expr  $totalMems \* 04  `m $memoryArg "
else
    export MYSQL_RESOURCES="$MYSQL_RESOURCES                                    -m `expr  $totalMems \* 15  `m $memoryArg "
    export MONGO_RESOURCES="$MONGO_RESOURCES                                    -m `expr  $totalMems \* 25  `m $memoryArg "
    export CODIS_RESOURCES="$CODIS_RESOURCES                                    -m `expr  $totalMems \* 15  `m $memoryArg "
    export FTENGINE2_RESOURCES="$FTENGINE2_RESOURCES                            -m `expr  $totalMems \* 15  `m $memoryArg "
    export KAFKA_RESOURCES="$KAFKA_RESOURCES                                    -m `expr  $totalMems \* 05  `m $memoryArg "
    export HIVECORE_RESOURCES="$HIVECORE_RESOURCES                              -m `expr  $totalMems \* 15  `m $memoryArg "
    export HIVEPMP_RESOURCES="$HIVEPMP_RESOURCES                                -m `expr  $totalMems \* 10  `m $memoryArg "
    export NEBULA_RESOURCES="$NEBULA_RESOURCES                                  -m `expr  $totalMems \* 05  `m $memoryArg "
    export EAGLES_RESOURCES="$EAGLES_RESOURCES                                  -m `expr  $totalMems \* 20  `m $memoryArg "
    export LOGSTASH_RESOURCES="$LOGSTASH_RESOURCES                              -m `expr  $totalMems \* 04  `m $memoryArg "
    export KIBANA_RESOURCES="$KIBANA_RESOURCES                                  -m `expr  $totalMems \* 04  `m $memoryArg "
    export CMSERVER_RESOURCES="$CMSERVER_RESOURCES                              -m `expr  $totalMems \* 08  `m $memoryArg "
    export CMWEB_RESOURCES="$CMWEB_RESOURCES                                    -m `expr  $totalMems \* 03  `m $memoryArg "
    export INGESTDBSVR_RESOURCES="$INGESTDBSVR_RESOURCES                        -m `expr  $totalMems \* 03  `m $memoryArg "
    export INGESTMSGSVR_RESOURCES="$INGESTMSGSVR_RESOURCES                      -m `expr  $totalMems \* 02  `m $memoryArg "
    export MOSGATEWAY_RESOURCES="$MOSGATEWAY_RESOURCES                          -m `expr  $totalMems \* 03  `m $memoryArg "
    export JOVE_RESOURCES="$JOVE_RESOURCES                                      -m `expr  $totalMems \* 05  `m $memoryArg "
    export OTCSERVER_RESOURCES="$OTCSERVER_RESOURCES                            -m `expr  $totalMems \* 04  `m $memoryArg "
    export FLOATINGLICENSESERVER_RESOURCES="$FLOATINGLICENSESERVER_RESOURCES    -m `expr  $totalMems \* 04  `m $memoryArg "
    export INFOSHARE_RESOURCES="$INFOSHARE_RESOURCES                            -m `expr  $totalMems \* 10  `m $memoryArg "
    export NTAG_RESOURCES="$NTAG_RESOURCES                                      -m `expr  $totalMems \* 04  `m $memoryArg "
fi
