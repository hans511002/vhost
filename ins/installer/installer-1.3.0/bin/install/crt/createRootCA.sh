#!/usr/bin/expect

# createRootCA.sh  hans /root/ssl sobey system sobey.com system@sobey.com 
#mkdir ~/ssl/
#openssl genrsa -des3 -out ~/ssl/rootCA.key 2048
#openssl req -x509 -new -nodes -key ~/ssl/rootCA.key -sha256 -days 1024 -out ~/ssl/rootCA.pem

set passwd [lindex $argv 0]
set sslDir [lindex $argv 1]
set cfgFile [lindex $argv 2]
 
if { $sslDir == ""  } {
	set sslDir "/root/ssl"
} 
if { $cfgFile == ""  } {
	set cfgFile "$sslDir/v3.cnf"
}
spawn -noecho /bin/bash

send_user "build rootCA  to $sslDir   \n "
sleep 0.1
send "mkdir -p $sslDir \n "
sleep 0.1
spawn openssl genrsa -des3 -out $sslDir/rootCA.key 2048
#send "openssl genrsa -des3 -out $sslDir/rootCA.key 2048 \n"
set timeout 3
expect {
    "$sslDir/rootCA.key:" { send "$passwd\n" }
}
sleep 0.2
set timeout 3
expect {
	"Verifying*$sslDir/rootCA.key:" { send "$passwd\n" }
}
set timeout 3
sleep 2
send_user "\n end build rootCA  to $sslDir   \n\n "

spawn openssl req -x509 -new -nodes -key $sslDir/rootCA.key -sha256 -days 102400 -out $sslDir/rootCA.crt  -config  $cfgFile
set timeout 5
expect {
	"Enter pass phrase*" { send "$passwd\n" }
}
sleep 0.2 
sleep 2
send_user "\n end build rootCA.pem  to $sslDir   \n\n "
sleep 1
send "ls -l $sslDir"
sleep 1
exit 0
