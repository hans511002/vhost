mongoUser="sobeyhive"
mongoPasswd='$0bEyHive*2o1Six'

# query shardrs master
mongoUserOpts=" -u '$mongoUser'  -p '$mongoPasswd' --authenticationDatabase admin "
echo "echo \"rs.status().members;\" | docker exec -i mongo-mongos-$HOSTNAME  mongo hivedb --host `hostname` --port 27117 $mongoUserOpts"|sh|grep -B3 "stateStr.*PRIMARY"|grep "name.*$mongoPort"|awk -F'[": ]+' '{print $3}'

docker exec -ti mongo-cfg-$HOSTNAME mongo admin
#config_mongo_cfg.js
print('begin===> config_mongo_cfg.js');
rs.initiate();
sleep(5000);
cfg = rs.conf();
cfg.members[0].host = "hivenode01:27917";
rs.reconfig(cfg);
print('rs.add("hivenode02:27917");');
rs.add("hivenode02:27917");
print('rs.add("hivenode03:27917");');
rs.add("hivenode03:27917");
print('end===> config_mongo_cfg.js');




docker exec -ti mongo-shardrs1-$HOSTNAME mongo admin
#config_mongo_shardrs1.js
print('begin===> config_mongo_shardrs1.js');
rs.initiate();
sleep(5000);
cfg = rs.conf();
cfg.members[0].host = "hivenode03:27117";
rs.reconfig(cfg);
print('rs.add("hivenode01:27117");');
rs.add("hivenode01:27117");
print('rs.add("hivenode02:27117");');
rs.add("hivenode02:27117");
print('end===> config_mongo_shardrs1.js');



docker exec -ti mongo-mongos-$HOSTNAME mongo admin
# config_mongo_mongos.js
print('begin===> config_mongo_mongos.js');
print('sh.addShard("hiveshardrs-1/hivenode03:27117,hivenode01:27117,hivenode02:27117");');
sh.addShard("hiveshardrs-1/hivenode03:27117,hivenode01:27117,hivenode02:27117");
//#sh.addShard("hiveshardrs-2/hivenode01:27217,hivenode02:27217,hivenode03:27217");

sleep(10000);
db = connect( 'admin' );
db.runCommand({enablesharding: "hivedb"});
db.runCommand({shardcollection: "hivedb.SH_RLDATA", key: {"reId":"hashed"}});
db.runCommand({shardcollection: "hivedb.SH_D_ENTITYDATA", key: {"resourceId":"hashed"}});
db.runCommand({shardcollection: "hivedb.SH_D_FILEGROUPS", key: {"resourceId":"hashed"}});
sh.status();
print('end===> config_mongo_mongos.js');



#创建超级管理员
addMongoSuperUser(){
container_mongos=`docker ps -a | grep mongo-mongos | awk '{print $NF}'`
#echo "show dbs" | docker exec -i $container_mongos mongo || sleep 30
echo "db.createUser({user:\"${mongoUser}\",pwd:\"${mongoPasswd}\",roles:[{role:\"root\",db:\"admin\"}]})" | docker exec -i $container_mongos mongo admin
sleep 1
container_shards=`docker ps -a | grep mongo-shardrs | awk '{print $NF}'`
for shard in $container_shards; do
    shardIdx=`echo $shard | sed -e "s|mongo-shardrs||" -e "s|-.*||" ` #mongo-shardrs1-hivenode03
    masterNode=`echo "rs.status().members;"|docker exec -i $shard mongo|grep -B3 "stateStr.*PRIMARY"|grep "name.*27${shardIdx}17"|awk -F'[": ]+' '{print $3}'`
    echo "db.createUser({user:\"${mongoUser}\",pwd:\"${mongoPasswd}\",roles:[{role:\"root\",db:\"admin\"}]})" | ssh $masterNode docker exec -i ${shard//`hostname`/$masterNode} mongo admin
    sleep 1
done
}
