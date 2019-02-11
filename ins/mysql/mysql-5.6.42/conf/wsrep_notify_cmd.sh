#!/bin/bash
#
#
bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin">/dev/null; pwd`

DATE=`date +"%Y-%m-%d %H:%M:%S"`
PARAMS="`date +%s` $DATE $@"
echo "notify.log=$PARAMS"
echo "$PARAMS" >> /var/log/mysql/notify.log

LAST_STATUS=$PARAMS
LAST_STATUS=${LAST_STATUS// /;}

#容器中取不到
#$ZOOKEEPER_HOME/bin/zkCli.sh -server $ZOOKEEPER_URL <<EOF
#ls /
#create /mysql ""
#create /mysql/$HOSTNAME ""
#set /mysql/$HOSTNAME "$LAST_STATUS" 
#EOF


exit 0

#!/bin/sh -eu

# This is a simple example of wsrep notification script (wsrep_notify_cmd).
# It will create 'wsrep' schema and two tables in it: 'membeship' and 'status'
# and fill them on every membership or node status change.
#
# Edit parameters below to specify the address and login to server.
USER='sobeyhive'
PSWD='$0bEyHive&2o1Six'
HOST=$NEBULA_VIP
PORT=3307

SCHEMA="wsrep"
MEMB_TABLE="$SCHEMA.membership"
STATUS_TABLE="$SCHEMA.status"

BEGIN="
   SET wsrep_on=0;
   CREATE SCHEMA IF not EXISTS  $SCHEMA;
   CREATE TABLE IF not EXISTS $MEMB_TABLE (
      idx  INT ,
      uuid CHAR(40), /* node UUID */
      name VARCHAR(32),     /* node name */
      addr VARCHAR(256),     /* node address */
      host VARCHAR(256),   
      updt datetime 
   ) ENGINE=MEMORY;
   CREATE TABLE IF not EXISTS $STATUS_TABLE (
      size   INT,      /* component size   */
      idx    INT,      /* this node index  */
      status CHAR(16), /* this node status */
      uuid   CHAR(40), /* cluster UUID */
      prim   BOOLEAN,   /* if component is primary */
      host VARCHAR(256),   
      updt datetime 
  ) ENGINE=MEMORY;
   BEGIN;
   -- DELETE FROM $MEMB_TABLE;
   -- DELETE FROM $STATUS_TABLE;
"
END="COMMIT;"

configuration_change()
{
   echo "$BEGIN;"

   local idx=0

   for NODE in $(echo $MEMBERS | sed s/,/\ /g)
   do
      echo "INSERT INTO $MEMB_TABLE VALUES ( $idx, "
      # Don't forget to properly quote string values
      echo "'$NODE'" | sed  s/\\//\',\'/g
      echo ",'$HOSTNAME',now());"
      idx=$(( $idx + 1 ))
   done

   echo "
      INSERT INTO $STATUS_TABLE
      VALUES($idx, $INDEX,'$STATUS', '$CLUSTER_UUID', $PRIMARY,'$HOSTNAME',now());
   "

   echo "$END"
}

status_update()
{
   echo "
      SET wsrep_on=0;
      BEGIN;
      INSERT INTO $STATUS_TABLE  (size,idx,status,host,updt)
      VALUES($idx, $INDEX,'$STATUS', '$HOSTNAME',now());
      
     -- UPDATE $STATUS_TABLE SET status='$STATUS' ,host='$HOSTNAME',updt=now() ;
      COMMIT;
   "
}

COM=status_update # not a configuration change by default

while [ $# -gt 0 ]
do
   case $1 in
      --status)
         STATUS=$2
         shift
         ;;
      --uuid)
         CLUSTER_UUID=$2
         shift
         ;;
      --primary)
         [ "$2" = "yes" ] && PRIMARY="1" || PRIMARY="0"
         COM=configuration_change
         shift
         ;;
      --index)
         INDEX=$2
         shift
         ;;
      --members)
         MEMBERS=$2
         shift
         ;;
         esac
         shift
   done

# Undefined means node is shutting down
if [ "$STATUS" != "Undefined" ] ; then
   $COM
   $COM | mysql -B -u$USER -p$PSWD -h$HOST -P$PORT
fi

exit 0
 