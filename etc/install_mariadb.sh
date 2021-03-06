#!/bin/bash
# -*- coding: utf-8 -*-
# vim: tabstop=4 shiftwidth=4 softtabstop=4
NAMEHOST=$HOSTNAME
if [  -e ${TOPDIR}/lib/openstack-log.sh ]
then	
	source ${TOPDIR}/lib/openstack-log.sh
else
	echo -e "\033[41;37m ${TOPDIR}/openstack-log.sh is not exist. \033[0m"
	exit 1
fi
#input variable
if [  -e ${TOPDIR}/lib/installrc ]
then	
	source ${TOPDIR}/lib/installrc 
else
	echo -e "\033[41;37m ${TOPDIR}/lib/installr is not exist. \033[0m"
	exit 1
fi
if [  -e /etc/openstack_tag/computer.tag  ]
then
	echo -e "\033[41;37m Oh no ! you can't execute this script on computer node.  \033[0m"
	log_error "Oh no ! you can't execute this script on computer node. "
	exit 1 
fi

if [ -f  /etc/openstack_tag/presystem.tag ]
then 
	log_info "config system have installed ."
else
	echo -e "\033[41;37m you should config system first. \033[0m"
	exit
fi

if [ -f  /etc/openstack_tag/install_mariadb.tag ]
then 
	echo -e "\033[41;37m you haved config Basic environment \033[0m"
	log_info "you have  been  install mariadb."
	exit
fi

#test network
function fn_test_network () {
if [ -f ${TOPDIR}/lib/proxy.sh ]
then 
	source  ${TOPDIR}/lib/proxy.sh
fi
curl www.baidu.com >/dev/null   
fn_log "curl www.baidu.com >/dev/null "
}



if  [ -f /etc/yum.repos.d/repo.repo ]
then
	log_info " use local yum."
else 
	fn_test_network
fi


yum install python-openstackclient -y
fn_log " yum install python-openstackclient -y"
yum clean all && yum install openstack-selinux -y
fn_log "yum clean all && yum install openstack-selinux -y"
FIRST_ETH_IP=${MANAGER_IP}


function fn_install_mariadb () {
yum clean all &&  yum install mariadb mariadb-server python2-PyMySQL  -y
fn_log "yum clean all &&  yum install mariadb mariadb-server python2-PyMySQL  -y"
rm -rf /etc/my.cnf.d/openstack.cnf &&  cp -a ${TOPDIR}/lib/mariadb_openstack.cnf /etc/my.cnf.d/openstack.cnf
fn_log "cp -a ${TOPDIR}/lib/mariadb_openstack.cnf /etc/my.cnf.d/openstack.cnf"
echo " " >>/etc/my.cnf.d/openstack.cnf
fn_log "echo " " >>/etc/my.cnf.d/openstack.cnf"
echo "bind-address = 0.0.0.0  >>/etc/my.cnf.d/openstack.cnf
fn_log "echo "bind-address = 0.0.0.0  >>/etc/my.cnf.d/openstack.cnf"

#start mariadb
systemctl enable mariadb.service &&  systemctl start mariadb.service 
fn_log "systemctl enable mariadb.service &&  systemctl start mariadb.service"
mysql_secure_installation <<EOF

y
${ALL_PASSWORD}
${ALL_PASSWORD}
y
y
y
y
EOF
fn_log "mysql_secure_installation"
}
MARIADB_STATUS=`service mariadb status | grep Active | awk -F "("  '{print$2}' | awk -F ")"  '{print$1}'`
if [ "${MARIADB_STATUS}"  = running ]
then
	log_info "mairadb have  been  installl."
else
	fn_install_mariadb
fi



function fn_install_rabbit () {
yum clean all && yum install rabbitmq-server -y
fn_log "yum clean all && yum install rabbitmq-server -y"

#start rabbitmq-server.service
systemctl enable rabbitmq-server.service &&  systemctl start rabbitmq-server.service 
fn_log "systemctl enable rabbitmq-server.service &&  systemctl start rabbitmq-server.service"

rabbitmqctl add_user openstack ${ALL_PASSWORD}
fn_log "rabbitmqctl add_user openstack ${ALL_PASSWORD}"
rabbitmqctl set_permissions openstack ".*" ".*" ".*"
fn_log "rabbitmqctl set_permissions openstack ".*" ".*" ".*""
}
function fn_test_rabbit () {
RABBIT_STATUS=`rabbitmqctl list_users | grep openstack | awk -F " " '{print$1}'`
if [ ${RABBIT_STATUS}x  = openstackx ]
then 
	log_info "rabbit have  been  installed."
else
	fn_install_rabbit
fi
}
if [ -f /usr/sbin/rabbitmqctl  ]
then
	log_info "rabbit have  been  installed."
else
	fn_test_rabbit
fi
yum  -y install memcached python-memcached
fn_log "yum  -y install memcached python-memcached"
systemctl enable memcached.service && systemctl restart memcached.service
fn_log "systemctl enable memcached.service && systemctl restart memcached.service"


echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###   Install Mariadb and Rabbitmq Sucessed.#### \033[0m"
echo -e "\033[32m ################################################ \033[0m"
if  [ ! -d /etc/openstack_tag ]
then 
	mkdir -p /etc/openstack_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack_tag/install_mariadb.tag
