#!/bin/bash

################################################
## yangpengcheng
## Mod 2017-10-09 15:02:03
## UTF-8
## Unix Format
## ver 1.0
## 后台运行 nohup ./xx.sh >/dev/null 2>&1 &
################################################

Shell_Dir=$(cd `dirname $0`; pwd)

##MySQL数据库管理员的用户名、密码
MySQLUserName="sdba"
MySQLPassWord="sdba"
MySQLHost=$(hostname)
MySQLPort="3307"
MySQLDBName="hivedb"

##MongoDB数据库管理员的用户名、密码
#MongoDBUserName=""
#MongoDBPassWord=""
MongoDBHost="localhost"
MongoDBPort=""
MongoDBName="hivedb"

Date=$(date +%F)
test -d $Shell_Dir/output || mkdir -p $Shell_Dir/output
test -f $Shell_Dir/output/worklog.log && rm -f $Shell_Dir/output/worklog.log

echo "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------" >> $Shell_Dir/output/worklog.log
echo "$(date "+%Y-%m-%d_%H-%M-%S"), $(hostname), start to work... "
echo "$(date "+%Y-%m-%d_%H-%M-%S"), $(hostname), start to work... " >> $Shell_Dir/output/worklog.log

function show_mysql_hivedb_tables()
{
	test -d $Shell_Dir/output/cfg || mkdir -p $Shell_Dir/output/cfg
	mysql --host=$MySQLHost --port=$MySQLPort --user=$MySQLUserName --password=$MySQLPassWord --database=$MySQLDBName -e 'SHOW TABLES' | grep -v "_[0-9]\w*" | grep -v 'Tables' > $Shell_Dir/output/cfg/mysql_hivedb_all_exist_tables 
}

function backup_mysql_hivedb_tab_structure_and_data()
{
	test -f $Shell_Dir/output/$Date/MySQL_Export/hivedb/mysql_hivedb_tab-structure-and-data_AllinOne_$Action_Date.sql && rm -f $Shell_Dir/output/$Date/MySQL_Export/hivedb/mysql_hivedb_tab-structure-and-data_AllinOne_$Action_Date.sql
	test -d $Shell_Dir/output/$Date/MySQL_Export/hivedb || mkdir -p $Shell_Dir/output/$Date/MySQL_Export/hivedb
	local Action_Date=$(date "+%Y-%m-%d_%H-%M-%S")

	for tables in $(cat $Shell_Dir/output/cfg/mysql_hivedb_all_exist_tables) ; do
		mysqldump --host=$MySQLHost --port=$MySQLPort --user=$MySQLUserName --password=$MySQLPassWord $MySQLDBName $tables >> $Shell_Dir/output/$Date/MySQL_Export/hivedb/mysql_hivedb_tab-structure-and-data_AllinOne_$Action_Date.sql
	done
	cd $Shell_Dir/output/$Date/MySQL_Export/hivedb
	gzip mysql_hivedb_tab-structure-and-data_AllinOne_$Action_Date.sql
	
}

function backup_mysql_all_db_exclude_hivedb()
{
	test -d $Shell_Dir/output/$Date/MySQL_Export || mkdir -p $Shell_Dir/output/$Date/MySQL_Export
	local Action_Date=$(date "+%Y-%m-%d_%H-%M-%S")
	cd $Shell_Dir/output/$Date/MySQL_Export
	mysql --host=$MySQLHost --port=$MySQLPort --user=$MySQLUserName --password=$MySQLPassWord -e 'show databases' | grep -Ev '\<Database\>|\<information_schema\>|\<mysql\>|\<performance_schema\>|\<test\>|\<hivedb\>' | xargs mysqldump --host=$MySQLHost --port=$MySQLPort --user=$MySQLUserName --password=$MySQLPassWord --skip-triggers --databases | gzip > $Shell_Dir/output/$Date/MySQL_Export/mysqldump_all-databases_exclude_hivedb_$Action_Date.sql.gz
}

function main()
{
	
	show_mysql_hivedb_tables >> $Shell_Dir/output/worklog.log 2>&1
	backup_mysql_hivedb_tab_structure_and_data >> $Shell_Dir/output/worklog.log 2>&1
	backup_mysql_all_db_exclude_hivedb >> $Shell_Dir/output/worklog.log 2>&1
}

main

if [[ $? -eq 0 ]]; then
	echo "$(date "+%Y-%m-%d_%H-%M-%S"), $(hostname), dump complete... "
	echo "$(date "+%Y-%m-%d_%H-%M-%S"), $(hostname), dump complete... " >> $Shell_Dir/output/worklog.log
else
	echo "$(date "+%Y-%m-%d_%H-%M-%S"), $(hostname), failed "
	echo "$(date "+%Y-%m-%d_%H-%M-%S"), $(hostname), failed... " >> $Shell_Dir/output/worklog.log
fi

exit $?
