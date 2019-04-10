#!/bin/sh -x

# This script sets up Foreman Master with DHCP, DNS, and PXE. 
# It assumes a development environment with no FQDN on master or node1. Most commands should be run with sudo. Vagrant does this automatically. If running script manually add sudo to it before running. 

# VARIABLES
DOMAIN=example.com
MASTER_HOSTNAME=foreman
MASTER_IP=192.168.33.10
REVERSE_DNS_ZONE=33.168.192.in-addr.arpa
DHCP_RANGE="192.168.33.101 192.168.33.150"
NODE1_HOSTNAME=node1
NODE1_IP=192.168.33.20

MASTER_FQDN=$MASTER_HOSTNAME.$DOMAIN
NODE1_FQDN=$NODE1_HOSTNAME.$DOMAIN

# Uncomment if you want to update everything first.
# yum update -y

# Change the following to you hostname
hostnamectl set-hostname $MASTER_FQDN

# Comment out these lines if your host has a FQDN.
echo "$MASTER_IP $MASTER_FQDN" | tee -a /etc/hosts

# Comment out if not running DHCP or DNS on Foreman Master and want to test a node out.
echo "$NODE1_IP $NODE1_FQDN" | tee -a /etc/hosts

# Firewall
systemctl start firewalld 
systemctl enable firewalld
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-port=69/tcp
firewall-cmd --permanent --add-port=67-69/udp
firewall-cmd --permanent --add-port=53/tcp
firewall-cmd --permanent --add-port=53/udp
firewall-cmd --permanent --add-port=3000/tcp
firewall-cmd --permanent --add-port=3306/tcp
firewall-cmd --permanent --add-port=5910-5930/tcp
firewall-cmd --permanent --add-port=5432/tcp
firewall-cmd --permanent --add-port=8140/tcp
firewall-cmd --permanent --add-port=8443/tcp
firewall-cmd --reload

# Repositories
yum -y install https://yum.puppetlabs.com/puppet5/puppet5-release-el-7.noarch.rpm
yum -y install http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum -y install https://yum.theforeman.org/releases/1.21/el7/x86_64/foreman-release.rpm

# Install Foreman
yum -y install foreman-installer
foreman-installer \
--foreman-proxy-tftp=true \
--foreman-proxy-tftp-managed=true \
--foreman-proxy-tftp-servername=$MASTER_IP \
--foreman-proxy-dhcp=true \
--foreman-proxy-dhcp-managed=true \
--foreman-proxy-dhcp-interface=eth1 \
--foreman-proxy-dhcp-gateway=$MASTER_IP \
--foreman-proxy-dhcp-range="192.168.33.101 192.168.33.150" \
--foreman-proxy-dhcp-nameservers=$MASTER_IP \
--foreman-proxy-dhcp-server $MASTER_IP \
--foreman-proxy-dns=true \
--foreman-proxy-dns-managed=true \
--foreman-proxy-dns-interface=eth1 \
--foreman-proxy-dns-zone=$DOMAIN \
--foreman-proxy-dns-reverse=$REVERSE_DNS_ZONE \
--foreman-proxy-dns-forwarders="8.8.8.8; 1.1.1.1" \
--foreman-proxy-dns-server $MASTER_IP \
--puppet-autosign-entries="*.$DOMAIN" \
--enable-foreman-plugin-ansible \
--enable-foreman-proxy-plugin-ansible \
--enable-foreman-plugin-discovery \
--enable-foreman-proxy-plugin-discovery \
--foreman-proxy-plugin-discovery-install-images=true \
--enable-foreman-plugin-remote-execution \
--enable-foreman-proxy-plugin-remote-execution-ssh
# -–enable-foreman-plugin-docker

# Initialize Node
while [ -f /opt/puppetlabs/puppet/cache/state/agent_catalog_run.lock ]
do
  sleep 2
done
/opt/puppetlabs/bin/puppet agent --test