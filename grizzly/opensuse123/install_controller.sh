#!/bin/bash

## Links
## http://en.opensuse.org/SDB:Cloud_OpenStack_Quickstart
## http://docs.openstack.org/grizzly/basic-install/apt/content/basic-install_controller.html
## http://docs.openstack.org/install/

## Para o Dashboard

zypper ar http://download.opensuse.org/repositories/Cloud:/OpenStack:/Grizzly/openSUSE_12.3/Cloud:OpenStack:Grizzly.repo
zypper clean
zypper refresh

echo 'net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0' >> /etc/sysctl.conf



zypper in -y ntp openstack-dashboard patterns-OpenStack-controller
zypper in -y memcached openstack-nova-novncproxy openstack-nova-vncproxy

zypper in -y mysql-community-server
/etc/init.d/mysql start

zypper in -y python-mysql rabbitmq-server


MYSQL_PASSWD=openstack

mysqladmin -u root password $MYSQL_PASSWD
/etc/init.d/mysql restart


/etc/init.d/rabbitmq-server start
rabbitmqctl change_password guest $MYSQL_PASSWD 

mysql -u root -p$MYSQL_PASSWD <<EOF
CREATE DATABASE nova;
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY "$MYSQL_PASSWD";
CREATE DATABASE cinder;
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY "$MYSQL_PASSWD";
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY "$MYSQL_PASSWD";
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY "$MYSQL_PASSWD";
CREATE DATABASE quantum;
GRANT ALL PRIVILEGES ON quantum.* TO 'quantum'@'localhost' IDENTIFIED BY "$MYSQL_PASSWD";
GRANT ALL PRIVILEGES ON quantum.* TO 'quantum'@'%' IDENTIFIED BY "$MYSQL_PASSWD";
FLUSH PRIVILEGES;
EOF



## OpenStack Identity Service
cp /etc/keystone/keystone.conf /etc/keystone/keystone.conf.orig

sed -i -e "s|sqlite:////var/lib/keystone/keystone.db|mysql://keystone:${MYSQL_PASSWD}@localhost/keystone|" /etc/keystone/keystone.conf
sed -i -e "s|# admin_token = ADMIN|admin_token = ${MYSQL_PASSWD}|" /etc/keystone/keystone.conf
sed -i -e "s|# debug = False|debug = True|" /etc/keystone/keystone.conf 

rcopenstack-keystone restart
keystone-manage db_sync

echo 'export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=openstack
export OS_AUTH_URL="http://localhost:5000/v2.0/"
export SERVICE_ENDPOINT="http://localhost:35357/v2.0"
export SERVICE_TOKEN=openstack' >> ~/.bashrc



## OpenStack Image Service
cp /etc/glance/glance-api.conf /etc/glance/glance-api.conf.orig
sed -i -e "s|sqlite:///glance.sqlite|mysql://glance:${MYSQL_PASSWD}@localhost/glance|" /etc/glance/glance-api.conf
sed -i -e "s|sqlite:////var/lib/glance/glance.db|mysql://glance:${MYSQL_PASSWD}@localhost/glance|" /etc/glance/glance-api.conf
sed -i -e "s|%SERVICE_TENANT_NAME%|service|" /etc/glance/glance-api.conf
sed -i -e "s|%SERVICE_USER%|glance|" /etc/glance/glance-api.conf
sed -i -e "s|%SERVICE_PASSWORD%|${MYSQL_PASSWD}|" /etc/glance/glance-api.conf


cp /etc/glance/glance-registry.conf /etc/glance/glance-registry.conf.orig
sed -i -e "s|sqlite:///glance.sqlite|mysql://glance:${MYSQL_PASSWD}@localhost/glance|" /etc/glance/glance-registry.conf
sed -i -e "s|sqlite:////var/lib/glance/glance.db|mysql://glance:${MYSQL_PASSWD}@localhost/glance|" /etc/glance/glance-registry.conf
sed -i -e "s|%SERVICE_TENANT_NAME%|service|" /etc/glance/glance-registry.conf
sed -i -e "s|%SERVICE_USER%|glance|" /etc/glance/glance-registry.conf
sed -i -e "s|%SERVICE_PASSWORD%|${MYSQL_PASSWD}|" /etc/glance/glance-registry.conf


rcopenstack-glance-api restart
rcopenstack-glance-registry restart
glance-manage db_sync


a2enmod wsgi
systemctl enable apache2.service
systemctl start apache2.service



