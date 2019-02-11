# -*- coding: utf-8 -*-

"""
dispatch the backup by config in loop
"""

import os 
import sys
import re
import time
import fcntl
import datetime
import logging
import stat
from logging.handlers import TimedRotatingFileHandler

root_path = '${SHARED_PATH}/backup'
config_file = root_path + '/config/hive_backup.cfg'
time_file = root_path + "/mongodb/auto/time.txt"
lockfile = root_path + '/mongodb/auto/lock'
data_path = root_path + '/mongodb/auto/data'
logs_path = root_path + '/mongodb/auto/log'
    
def logset(logs_path):
    """
    set the log format
    """
    
    log = logging.getLogger()
    log.setLevel(logging.INFO)
    log_fmt = '%(asctime)s %(filename)s %(levelname)-8s: %(message)s'
    formatter = logging.Formatter(log_fmt)
    log_file_handler = TimedRotatingFileHandler(filename=logs_path + '/mongo_backup_log', when='D', interval=7, backupCount=10)
    log_file_handler.suffix = "%Y-%m-%d-%H-%M.log"
    log_file_handler.extMatch = re.compile(r"^\d{4}-\d{2}-\d{2}-\d{2}-\d{2}.log$")
    log_file_handler.setFormatter(formatter)    
    log.addHandler(log_file_handler)
    return log

def read_config(config_file, item):
    """
    read the config of the dispatch 
    """
    
    content = ''
    if os.path.exists(config_file):
        try:
            with open(config_file, 'r') as fcon:
                lines = fcon.readlines()
                for line in lines:
                    if re.match(str(item),line) :
                        content = re.split('=', line)[1].strip().replace('\n', '').replace('\t', '')
                        break
                        
                    # if item in line:
                        # content = re.split('=', line)[1].strip().replace('\n', '').replace('\t', '')
                        # break
                if not content:
                    logs.error("The item of %s is not correctly configered!" % item)
        except IOError as e:
            logs.error("Read config_file failed. %s ", e)
    else:
        logs.error("No config_file exsits.")
    return content

def get_excute_time(time_file, new_excute_time):
    """
    if the time file is normal then set status to True
    else to False
    """
    
    excute_time = ''
    status = False
   
    if os.path.exists(time_file):
        os.chmod(time_file, stat.S_IRWXU|stat.S_IRWXG|stat.S_IRWXO)
        try:
            with open(time_file, 'r+') as fcon:
                excute_time = fcon.read().strip().replace('\n', '').replace('\t', '')
                match_result = re.match('\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2}', excute_time)
                if match_result is None:
                    logs.info("The excute time recored on the time file is not matched, write the current time as the new excute time to it.")
                else:
                    status = True
        except IOError as e:
            logs.error("Some error occured when read the excute_time file. %s", e)
    else:
        logs.info("The excute time is not exists. Make file now")
        try:
            with open(time_file, 'w+') as fcon:
                fcon.write(new_excute_time)
        except IOError as e:
            logs.error("Some error occured when write the excute_time file. %s", e)
    return status, excute_time
    
def write_excute_time(time_file, new_excute_time):
    """
    write the excute time to time file
    """

    if os.path.exists(time_file):
        os.chmod(time_file, stat.S_IRWXU|stat.S_IRWXG|stat.S_IRWXO)
    try:
        with open(time_file, 'w+') as fcon:
            fcon.write(new_excute_time)
    except IOError as e:
        logs.error("Some error occured when write the excute_time file in handle the write_excute_time. %s", e)
            
if __name__ == "__main__":


    loop_time = 1800
    filename= sys.argv[0]
    dirname = os.path.dirname(filename)
    script_path = os.path.abspath(dirname)
    
    if not os.path.exists(data_path):
        cmd = "mkdir -p  " + data_path
        status = os.system(cmd)
        if status != 0:
            sys.exit(1)
    if not os.path.exists(logs_path):
        cmd = "mkdir -p  " + logs_path
        status = os.system(cmd)
        if status != 0:
            sys.exit(1)
            
    logs = logset(logs_path)

    while True:
        time.sleep(loop_time)
        # get lock
        with open(lockfile, 'w') as f:
            try:
                fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
                logs.info("get lock success")
            except Exception:
                logs.info("get lock fail")
                continue     
            
            if os.path.exists(config_file):
                rate_day = read_config(config_file, 'MONGO_RATE')
                logs.info("Read MONGO_RATE from config file is: %s" % str(rate_day))
                if not rate_day:
                    logs.info("Set MONGO_RATE to a default value:1")
                    rate_day = 1

                mongo_time = read_config(config_file, 'MONGO_TIME').replace(':', '-')
                logs.info("Read MONGO_TIME from config file is: %s" % str(mongo_time))
                if not mongo_time:
                    logs.info("Set MONGO_TIME to a default value:00-00-00")
                    mongo_time = "00-00-00"
            else:
                logs.error("The backup config file:%s  is not exists" % config_file)
                continue

            new_excute_time = datetime.datetime.now().strftime('%Y-%m-%d-%H-%M-%S')
            
            #cur_path = os.getcwd()
            # get the last excute time
            status, excute_time = get_excute_time(time_file, new_excute_time)

            if status == False:
                # dispatch the backup
                logs.info("Time file status is false,begine backup right now.....")
                status = os.system("python " + script_path + "/mongodb_backup_excute.py ")
                logs.info("After do backup status is %d*******" % status)
                if status == 0:
                    time.sleep(loop_time)
            else:
                excute_time_day = datetime.datetime.strptime(re.match('\d{4}-\d{2}-\d{2}', excute_time).group(), '%Y-%m-%d')
                time_now_day = datetime.datetime.strptime(datetime.date.today().strftime('%Y-%m-%d'), '%Y-%m-%d')
                delta_days = (time_now_day-excute_time_day).days
                # waite time reach
                if delta_days >= rate_day:
                    
                    now_time = datetime.datetime.strptime(datetime.datetime.now().strftime('%H-%M-%S'), '%H-%M-%S')
                    mongo_time = datetime.datetime.strptime(mongo_time, '%H-%M-%S')
                    if 0 <= (now_time-mongo_time).seconds < loop_time:
                        write_excute_time(time_file, datetime.datetime.now().strftime('%Y-%m-%d-%H-%M-%S'))
                        # dispatch the backup
                        logs.info("Time reach .....")
                        status = os.system("python " + script_path + "/mongodb_backup_excute.py ")
                        logs.info("After do backup status is %d*******" % status)
                        if status == 0:
                            time.sleep(loop_time)
            try:
                f.close()
                logs.info("Unlock end")
            except:
                logs.error("Unlock fail")
                        
        
