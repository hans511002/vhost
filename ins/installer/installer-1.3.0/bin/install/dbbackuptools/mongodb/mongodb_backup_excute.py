# -*- coding: utf-8 -*-

"""
excute the backup action
"""

import os 
import sys
import re
import datetime
import logging
import shutil
import string
import mongodb_backup_manage as manage

def get_mongo_auth():
 # get mongo user and password
 # 从mongo的配置中读取，如果没安装则退出
 
    auth_status = False
    user = ''
    passwd = ''
    auther = ''
    MONGO_HOME = os.environ.get('MONGO_HOME')
    
    if MONGO_HOME:
            isMongoPasswd_cmd = "source /etc/profile.d/mongo.sh >/dev/null;cat $MONGO_HOME/mongo_cluster.conf |grep isMongoPasswd|awk -F '=' '{print $NF}'"
            isPass_status = os.popen(isMongoPasswd_cmd).read().strip()
            if isPass_status == "true":
                auth_status = True
                auther = "admin"
            
                user_cmd = "source /etc/profile.d/mongo.sh >/dev/null;cat $MONGO_HOME/mongo_cluster.conf |grep mongoUser|awk -F '=' '{print $NF}'"
                user = os.popen(user_cmd).read().strip()
                logs.info("The mongodb user content fetched from monggo_cluster.conf is :%s" % user)
            
                passwd_cmd = "source /etc/profile.d/mongo.sh >/dev/null;cat $MONGO_HOME/mongo_cluster.conf |grep mongoPasswd|awk -F '=' '{print $NF}'"
                passwd = os.popen(passwd_cmd).read().strip()
                logs.info("The mongodb passwd content fetched from monggo_cluster.conf is :%s" % passwd)

    else:
        LOCAL_HOST = os.environ.get('LOCAL_HOST')
        logs.error("Mongodb is not installed  in %s, can not fetch mongo user and passwd, exit now"  % LOCAL_HOST)
        sys.exit(1)
    return auth_status, user, passwd, auther
            
def find_slave_node(container_cfg_id, passwd_flag, user, passwd, auther):
    """
    find a slave node of the mongo cluster
    """
    
    status = False
    slave_name = ""
    if passwd_flag == True:
        mongo_cmd = " mongo -u " + "'" + user + "'" + " -p " + "'" + passwd + "'" + ' --authenticationDatabase ' + auther
    else:
        mongo_cmd = ' mongo'
    cmd = 'echo "rs.status()"|docker exec -i '+ container_cfg_id + mongo_cmd
    
    content = os.popen(cmd).read().decode('utf-8').strip().replace(' ', '').replace('\n', '').replace('\t', '')
    if '"ok":1' not in content:
        logs.error("Query the rs.status() is not ok, now exit. Query result is : %s" % content)
        return status, slave_name
    # SECONDARY   PRIMARY
        
    if  "SECONDARY" not in content:
        logs.error("There is no SECONDARY node in the mongodb cluster, now exit.")
        return status, slave_name
        
    re_list = re.split("_id", content)
    for item in re_list:
        patt = r'"name":"(.+?)(:)(\d+).*"stateStr":"SECONDARY"'
        result = re.search(patt, item)
        
        if result:
            slave_name = result.group(1)
            logs.info("SECONDARY node name item is :%r" % item)
            status = True
            break
        else:
            continue
    if not status:
        logs.error("There is no SECONDARY node in the mongodb cluster, now exit. The re.status() content is %s" % content)
    return status, slave_name


def check_host_name(node_name):
    """ 
    check the host name by the system config file
    """

    status = False
    cmd = "cat /bin/cmd.sh |grep 'for HOST'|sed -e 's/.*for HOST in//' -e 's/;do.*//'"
    result = os.popen(cmd).read().decode('utf-8').strip()
    if node_name in result:
        status = True
    return status
    

def backup_mongo(dest_path_tar, slave_name):
    """
    ssh to the slave to tar data
    """
    
    status = False
    mongo_src =  '${DATA_BASE}/mongo/*'
    
    logs.info("Start copy the mongo data to a tar .....")
    cmd = 'ssh root@' + slave_name + ' ' + 'tar -zcf ' + dest_path_tar + ' -C  ${DATA_BASE}/  mongo'
    logs.info(cmd)
    result = os.popen(cmd).read().decode('utf-8').strip()
    if result:
        logs.error("Excute command %s fail. Now end mongo backup this time." % cmd)
        return status
    else:
        status = True
        return status
    
# def delete_redundant_back(dest_path):
    # """
    # delete redundant by rar file number 
    # """
    # cmd = "ls " + dest_path + " |grep mongodb|grep tar.gz"
    # dirs_list = os.popen(cmd).read().decode('utf-8').strip().replace('\n', ' ').split(' ')
    # backup_list = []
    # pattern = r'mongodb_\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2}.tar.gz'
    # for item in dirs_list:
        # patt_result = re.match(pattern, item)
        # if patt_result is not None:
            # backup_list.append(item)
    # backup_list.sort()
    # logs.info("Backup list exist is :%r" % backup_list)
    # if len(backup_list) >= 2:
        # for i in range(0, len(backup_list)-1):
            # try:
                # tar_file = dest_path + '/' + backup_list[i]
                # os.remove(tar_file)
            # except Exception as e:
                # logs.error("Remove mongo backup folderfail.%s", e)
                
                
def get_mongo_stop_cmd():

    cmd = "source /etc/profile.d/mongo.sh >/dev/null;ls $MONGO_HOME/sbin|grep ^stop_mongo\.sh$"
    result = os.popen(cmd).read().strip().replace('\n', ' ')
    logs.info("Stop_mongo cmd result is: %r" % result)
    if result:
        stop_mongo_sh = "stop_mongo.sh"
    else:
        stop_mongo_sh = "stop_mongodb.sh"
    stop_mongo_cmd = 'ssh root@' + slave_name + ' ' + stop_mongo_sh
    return stop_mongo_cmd
    
    
def get_mongo_start_cmd():

    cmd = "source /etc/profile.d/mongo.sh >/dev/null;ls $MONGO_HOME/sbin|grep ^start_mongo\.sh$"
    result = os.popen(cmd).read().strip().replace('\n', ' ')
    logs.info("Start_mongo cmd result is: %r" % result)
    if result:
        start_mongo_sh = "start_mongo.sh"
    else:
        start_mongo_sh = "start_mongodb.sh"
    start_mongo_cmd = 'ssh root@' + slave_name + ' ' + start_mongo_sh
    return start_mongo_cmd                
                
def delete_redundant_back(dest_path):
    """
    delete redundant by rar time
    """
    cmd = " ls -l " + dest_path + " |grep '\<mongodb_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{2\}\.tar\.gz\>'|awk '{print $NF}'"
    date_today = datetime.datetime.now().date()
    rar_str =  os.popen(cmd).read().strip()
    if rar_str != '':
        rar_list = re.split('\n', rar_str)
        if len(rar_list) > 1:
            for item in rar_list:
                rar_day = re.split(r'[_ .]', string.strip(item))[1][0:10]
                rar_date = datetime.datetime.strptime(rar_day, "%Y-%m-%d").date()
                if (date_today - rar_date).days > 14:
                    del_file = dest_path + "/" + item
                    try:
                        logs.info("delete redundant file : %s" % del_file)
                        os.remove(del_file)
                    except OSError as exception:
                        logs.error("delete redundant error, may something wrong with file %s"  % del_file)


if __name__ == "__main__": 

    source_cmd = ". /etc/bashrc"
    os.popen(source_cmd)
    config_file = manage.config_file

    data_path = manage.data_path
    dest_path_tar = data_path + '/mongodb_' + datetime.datetime.now().strftime('%Y-%m-%d-%H-%M-%S') + '.tar.gz'
    logs_path = manage.logs_path
    logs = manage.logset(logs_path)
    cmd = r"docker  ps -a |grep mongo-cfg|awk '{print $1}'"
    container_cfg_id = os.popen(cmd).read().decode('utf-8').strip()
    if not container_cfg_id:
        logs.error("ERROR: Can not get the mongo-cfg container. Now end mongo backup this time")
        sys.exit(1)
        
    # # get mongo user and password, and check slave node
    isPasswd_flag, user, passwd, auther = get_mongo_auth()
    status, slave_name = find_slave_node(container_cfg_id, isPasswd_flag, user, passwd, auther)
    if not status:
        logs.error("ERROR: Can not find a slave node mongo container. Now end mongo backup this time")
        sys.exit(1)
    logs.info("Slave_name is %s" % slave_name)
    status = check_host_name(slave_name)
    if not status:
        logs.error("The slave mongo node name %s finded in rs.status() is not exists in cluster config. Now end mongo backup this time" % slave_name)
        sys.exit(1)

    cmd_stop_auto = 'ssh root@' + slave_name + ' ' + 'stop_hive_autostart.sh'
    cmd_start_auto = 'ssh root@' + slave_name + ' ' + 'start_hive_autostart.sh'
    result = os.system(cmd_stop_auto)
    if result == 0:
        logs.info('stop_hive_autostart.sh success')
    else:
        logs.info('stop_hive_autostart.sh failed')

    stop_mongo_cmd = get_mongo_stop_cmd()
    start_mongo_cmd = get_mongo_start_cmd()

    ## begin do backup process: stop mongodb and make tar
    
    status = os.system(stop_mongo_cmd)
    logs.info("Stop_mongo result is: %r" % status)
    if status != 0:
        logs.error("Stop mongo failed on node %s. Now end mongo backup this time." % slave_name)
        os.system(cmd_start_auto)
        os.system(start_mongo_cmd)
        sys.exit(1)
    else:
        delete_redundant_back(data_path)
        
        # begin tar the data, if failed then exit, else continue the process
        logs.info("Backup mongodb tar start!")
        status = backup_mongo(dest_path_tar, slave_name)
        if not status:
            os.system(cmd_start_auto)
            os.system(start_mongo_cmd)
            sys.exit(1)
        else:
            logs.info("Backup mongodb tar end!")
        
        # start mongo
        os.system(start_mongo_cmd)
        os.system(cmd_start_auto)