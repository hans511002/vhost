#!/bin/bash

# Based on install_hawq_toolchain.bash in Pivotal-DataFabric/ci-infrastructure repo

setup_ssh_for_user() {
  local user="${1}"
  local home_dir
  home_dir=$(eval echo "~${user}")

  mkdir -p "${home_dir}"/.ssh
  touch "${home_dir}/.ssh/authorized_keys" "${home_dir}/.ssh/known_hosts" "${home_dir}/.ssh/config"
  ssh-keygen -t rsa -N "" -f "${home_dir}/.ssh/id_rsa"
  cat "${home_dir}/.ssh/id_rsa.pub" >> "${home_dir}/.ssh/authorized_keys"
  chmod 0600 "${home_dir}/.ssh/authorized_keys"
  cat << 'NOROAMING' >> "${home_dir}/.ssh/config"
Host *
  UseRoaming no
  StrictHostKeyChecking no
NOROAMING
  chown -R "${user}" "${home_dir}/.ssh"
}

transfer_ownership() {
  chown -R gpadmin:gpadmin /workspace/gpdb
  chown -R gpadmin:gpadmin /usr/local/gpdb
}

setup_user() {
  auser="$1"
  apass="$2"
  apass=${apass:=$auser}
  /usr/sbin/useradd $auser
  echo "$auser:$apass" | chpasswd
  #echo -e "password\npassword" | passwd gpadmin
  groupadd supergroup
  usermod -a -G supergroup,root $auser
  setup_ssh_for_user $auser
  #transfer_owner ship
}

setup_sshd() {
  test -e /etc/ssh/ssh_host_key || /bin/ssh-keygen -f /etc/ssh/ssh_host_key -N '' -t rsa1
  test -e /etc/ssh/ssh_host_rsa_key || /bin/ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa
  test -e /etc/ssh/ssh_host_dsa_key || /bin/ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa
  test -e /etc/ssh/ssh_host_ecdsa_key || /bin/ssh-keygen -f /etc/ssh/ssh_host_ecdsa_key -N '' -t ecdsa
  test -e /etc/ssh/ssh_host_ed25519_key || /bin/ssh-keygen -f /etc/ssh/ssh_host_ed25519_key -N '' -t ed25519
  
  sed -i -e 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' /etc/pam.d/sshd 
  sed -i -e 's/UsePAM yes/#UsePAM yes/g' -e 's/#UsePAM no/UsePAM no/g'  \
     -e 's/PermitRootLogin no/PermitRootLogin yes/g' \
     -e 's/PasswordAuthentication no/PasswordAuthentication yes/'  /etc/ssh/sshd_config

  # Disable password authentication so builds never hang given bad keys
  #sed -ri 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
  setup_ssh_for_user root
}

 
if [ "$#" = "0" ] ; then
setup_sshd
else
setup_user $@
fi

 

