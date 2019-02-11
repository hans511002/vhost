#!/bin/bash
. /etc/bashrc
exit 0


BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`
cd $BIN
if [ "${CLUSTER_HOST_LIST//,/ }" = "" ] ; then
    echo "cluster not init"
    exit 1
fi
. $APP_BASE/install/funs.sh

yum -y install openssl 

# req_extensions = v3_req # The extensions to add to a certificate request

sed -i -e "s|# req_extensions.*|req_extensions=v3_req|"  /etc/pki/tls/openssl.cnf
sed -i -e "s|req_extensions.*|req_extensions=v3_req|"  /etc/pki/tls/openssl.cnf

sed -i -e "s|basicConstraints.*CA:.*|basicConstraints=CA:TRUE|"  /etc/pki/tls/openssl.cnf
sed -i -e "s|countryName_default.*|countryName_default=CN|"  /etc/pki/tls/openssl.cnf
sed -i -e "s|#stateOrProvinceName_default.*|stateOrProvinceName_default=SiChuan|"  /etc/pki/tls/openssl.cnf
sed -i -e "s|stateOrProvinceName_default.*|stateOrProvinceName_default=SiChuan|"  /etc/pki/tls/openssl.cnf
sed -i -e "s|localityName_default.*|localityName_default=ChengDu|"  /etc/pki/tls/openssl.cnf
sed -i -e "s|0.organizationName_default.*|0.organizationName_default=sobey|"  /etc/pki/tls/openssl.cnf
sed -i -e "s|#organizationalUnitName_default.*|organizationalUnitName_default=system|"  /etc/pki/tls/openssl.cnf
sed -i -e "s|organizationalUnitName_default.*|organizationalUnitName_default=system|"  /etc/pki/tls/openssl.cnf
# need add 
sed -i "/commonName.*= Common Name/acommonName_default=$PRODUCT_DOMAIN"  /etc/pki/tls/openssl.cnf
sed -i "/emailAddress.*= Email Address/aemailAddress_default=hive@sobey.com"  /etc/pki/tls/openssl.cnf



rm -rf /etc/pki/CA/private/cakey.pem
/etc/pki/tls/misc/CA -newca
# server
openssl genrsa  -out server.key 2048
#openssl genrsa -des3 -out server.key 2048
openssl req -new -key server.key -out server.csr <<EOF









EOF
/etc/pki/tls/misc/CA -sign 
#client
openssl genrsa -out client.key 2048 
openssl req -new -key client.key -out client.csr <<EOF









EOF
/etc/pki/tls/misc/CA -sign 


expect -c "set timeout -1;
    spawn "/etc/pki/tls/misc/CA \-newca ";
    expect {
        *CA certificate filename* {send -- \r;}
        *Enter PEM pass phrase:* {send -- hive\r;}
        *Verifying - Enter PEM pass phrase:* {send -- hive\r;}
        *Country Name* {send -- \r;}
        *State or Province Name* {send -- \r;}
        *Locality Name* {send -- \r;}
        *Organization Name* {send -- \r;}
        *Organizational Unit Name* {send -- \r;}
        *Common Name* {send -- pf.hive.sobey.com\r;}
        *Email Address* {send -- hive@sobey.com\r;}
        *A challenge password* {send -- \r;}
        *An optional company name* {send -- \r;}
        *Enter pass phrase for*cakey.pem:* {send -- hive\r;}
        eof         {exit 1;}
    }
    " ;

rm -rf /etc/pki/CA/private/cakey.pem
/etc/pki/tls/misc/CA -newca <<EOF



hive
hive
CN
SiChuan
ChengDu
sobey
system
pf.hive.sobey.com
hive@sobey.com


hive

EOF



