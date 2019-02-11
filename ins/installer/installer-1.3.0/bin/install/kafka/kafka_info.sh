#! /bin/bash
. /etc/bashrc
bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin">/dev/null; pwd`
cd $bin

if [ $# -lt 1 ] ; then
  echo "usetag:kafka_info.sh <ls|desc> [type<json|row>]
  exp:kafka_info.sh 
"
  exit 1
fi
. ${APP_BASE}/install/funs.sh


cmd=$1
kafkaHosts=(${kafka_hosts//,/ })
COUNT=${#kafkaHosts[@]}
kafkaHost=

getKafkaHost()
{
    for HOST in ${kafka_hosts//,/ } ; do
        runned=`ssh $HOST docker ps |grep kafka-$HOST | wc -l `
        if [ "$runned" != "1" ] ; then
            continue
        fi
        kafkaHost="$HOST"
        break
    done
}

getKafkaHost

#echo "kafkaHost=$kafkaHost"

getKafkaTopics()
{
    ssh $kafkaHost docker exec -i kafka-$kafkaHost  /kafka/bin/kafka-topics.sh --list --zookeeper $ZOOKEEPER_URL
}


getKafkaTopicDescribe()
{
    ssh $kafkaHost docker exec -i kafka-$kafkaHost  /kafka/bin/kafka-topics.sh --describe --zookeeper $ZOOKEEPER_URL
}

if [ "$cmd" = "ls" ] ; then
    getKafkaTopics
    #kafkaTopics=`getKafkaTopics`
    #echo "$kafkaTopics"
elif [ "$cmd" = "desc" ] ; then
    #getKafkaTopicDescribe
    kafkaTopicDesc=`getKafkaTopicDescribe`
    if [ "$kafkaTopicDesc" = "" ] ; then
        echo "get kafka topic error"
        exit 1
    fi 
    IFS='
'
    PartitionCount=0
    echo -n "{"
    ISFIRST_TOPIC=true
    for LINE in ${kafkaTopicDesc} ; do
        LINE="${LINE//: /:}"
        #LINE=`echo "$LINE"|sed -e 's|\t| |' `
        #echo "line=$LINE"
        IFS='	'
        Partition=
        Leader=
        Replicas=
        Isr=
        START_TOPIC=false
        if [ "${LINE}" != "${LINE//PartitionCount:/}" ] ; then
            if [ "$PartitionCount" -lt "0" ] ; then  #output last row
                echo -n "]}"
            fi
            PartitionCount=0
            TopicName=
            ReplicationFactor=
            Configs=
            START_TOPIC=true
        fi
        for KV in ${LINE} ; do
            #echo "KV=$KV"
            key="${KV//:*/}"
            val="${KV//*:/}"
            if [ "$key" = "Topic" ] ; then
                TopicName="$val"
            elif [ "$key" = "PartitionCount" ] ; then
                PartitionCount="$val"
            elif [ "$key" = "ReplicationFactor" ] ; then
                ReplicationFactor="$val"
            elif [ "$key" = "Configs" ] ; then
                Configs="$val"
            elif [ "$key" = "Partition" ] ; then
                Partition="$val"
            elif [ "$key" = "Leader" ] ; then
                Leader="$val"
            elif [ "$key" = "Replicas" ] ; then
                Replicas="$val"
            elif [ "$key" = "Isr" ] ; then
                Isr="$val"
            fi
            #echo "$key=$val"
        done
        if [ "$START_TOPIC" = "true" ] ; then
            if [ "$ISFIRST_TOPIC" = "false" ] ; then
                echo -n "]},"
            fi 
            echo -n "\"$TopicName\":{\"ReplicationFactor\":$ReplicationFactor,\"PartitionCount\":$PartitionCount,\"Configs\":\"$Configs\","
        else
            if [ "${LINE}" != "${LINE//Partition:0/}" ] ; then
                echo -n "\"Partitions\":["
            else
                echo -n ","
            fi 
            echo -n "{\"Partition\":$Partition,\"Leader\":$Leader,\"Replicas\":[$Replicas],\"Isr\":[$Isr]}"
        fi
        ISFIRST_TOPIC=false 
        IFS='
'
    done
    echo -e "]}}"
    #echo "$kafkaTopicDesc"
fi

#Topic:reBuildIndexFetchMessage "PartitionCount":3	ReplicationFactor:3	Configs:cleanup.policy=compact
#   Topic:reBuildIndexFetchMessage	Partition:0	Leader:192	Replicas:192,193,191	Isr:192,193,191
#   Topic:reBuildIndexFetchMessage	Partition:1	Leader:193	Replicas:193,191,192	Isr:192,193,191
#   Topic:reBuildIndexFetchMessage	Partition:2	Leader:191	Replicas:191,192,193	Isr:192,193,191
