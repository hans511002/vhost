#!/usr/bin/expect

#createselfsignedcertificate.sh hans /sobeyhive/app/install/crt hive_crt /etc/haproxy/test2 /etc/haproxy/test2/v3.cnf /etc/haproxy/test2/v3.ext 


#openssl req -new -sha256 -nodes -out server.csr -newkey rsa:2048 -keyout server.key -config <( cat v3.cnf )
#openssl x509 -req -in server.csr -CA ~/ssl/rootCA.pem -CAkey ~/ssl/rootCA.key -CAcreateserial -out server.crt -days 500 -sha256 -extfile v3.ext

set passwd [lindex $argv 0]
set sslDir [lindex $argv 1]
set destName [lindex $argv 2]
set destDir [lindex $argv 3]
set cfgFile [lindex $argv 4]
set extFile [lindex $argv 5]

if { $destDir == ""  } {
	set destDir "$sslDir"
}
if { $cfgFile == ""  } {
	set cfgFile "$destDir/v3.cnf"
}
if { $extFile == ""  } {
	set extFile "$destDir/v3.ext"
}

spawn -noecho /bin/bash
spawn ls /
sleep 0.1
send_user "build https crt  to $destDir \n "
sleep 0.5
set timeout 20
spawn /usr/bin/openssl req -new -sha256 -nodes -out $destDir/$destName.csr -newkey rsa:2048 -keyout $destDir/$destName.key -config  $cfgFile 
#send "/usr/bin/openssl req -new -sha256 -nodes -out $destDir/$destName.csr -newkey rsa:2048 -keyout $destDir/$destName.key -config <( cat $cfgFile ) \n "
set timeout 3
sleep 2
send "ls -l $destDir \n "
send_user "\n"

sleep 0.2

send_user "\n \n end build $destName.csr $destName.key  to $destDir   \n\n "
sleep 0.1
set timeout 3
spawn /usr/bin/openssl x509 -req -in $destDir/$destName.csr -CA $sslDir/rootCA.crt -CAkey $sslDir/rootCA.key -CAcreateserial -out $destDir/$destName.crt -days 102400 -sha256 -extfile $extFile  
#send "/usr/bin/openssl x509 -req -in $destDir/$destName.csr -CA $sslDir/rootCA.crt -CAkey $sslDir/rootCA.key -CAcreateserial -out $destDir/$destName.crt -days 10240 -sha256 -extfile $extFile   \n\n "
set timeout 3
expect {
    "*rootCA.key:" { send "$passwd\n" }
}
sleep 2
send_user "\n"

#build pkcs12
#echo "openssl pkcs12 -export -clcerts -out $WORK_DIR/server.pfx -inkey $WORK_DIR/$CRTNAME.key -in $WORK_DIR/$CRTNAME.crt -password pass:$CAPAASWD"

set timeout 3
spawn openssl pkcs12 -export -clcerts -out $destDir/$destName.pfx -inkey $sslDir/$destName.key -in $sslDir/$destName.crt 
# -password pass:$passwd
expect {
    "Enter Export Password:" { send "$passwd\n" }
}
sleep 1
expect {
    "*Enter Export Password:" { send "$passwd\n" }
}
send_user "\n"
sleep 2
send_user "\n"
exit 0




