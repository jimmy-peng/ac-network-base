#!/bin/bash
set -x
UPLINK_MAC=$(ifconfig ${UPLINK_IFACE} | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')


mv /sbin/dhclient /usr/local/sbin/
/sbin/ip link set dev ${UPLINK_IFACE} mtu 1800
vconfig add ${UPLINK_IFACE} ${INFRA_VLAN}
/sbin/ip link set dev ${UPLINK_IFACE}"."${INFRA_VLAN} mtu 1600

cat > /etc/dhcp/dhclient.conf << EOF
# Configuration file for /sbin/dhclient.
#
# This is a sample configuration file for dhclient. See dhclient.conf's
#	man page for more information about the syntax of this file
#	and a more comprehensive list of the parameters understood by
#	dhclient.
#
# Normally, if the DHCP server provides reasonable information and does
#	not leave anything out (like the domain name, for example), then
#	few changes must be made to this file, if any.
#

interface "${UPLINK_IFACE}.${INFRA_VLAN}" {
    send host-name = gethostname();
    #send host-name "rancher-virtual-machine";
    send dhcp-client-identifier 1:${UPLINK_MAC};
}
option rfc3442-classless-static-routes code 121 = array of unsigned integer 8;

request subnet-mask, broadcast-address, time-offset, routers,
	domain-name, domain-name-servers, domain-search, host-name,
	dhcp6.name-servers, dhcp6.domain-search, dhcp6.fqdn, dhcp6.sntp-servers,
	netbios-name-servers, netbios-scope, interface-mtu,
	rfc3442-classless-static-routes, ntp-servers;

#send dhcp-client-identifier 1:0:a0:24:ab:fb:9c;
#send dhcp-lease-time 3600;
#supersede domain-name "fugue.com home.vix.com";
#prepend domain-name-servers 127.0.0.1;
#require subnet-mask, domain-name-servers;
timeout 300;
#retry 60;
#reboot 10;
#select-timeout 5;
#initial-interval 2;
#script "/sbin/dhclient-script";
#media "-link0 -link1 -link2", "link0 link1";
#reject 192.33.137.209;

#alias {
#  interface "eth0";
#  fixed-address 192.5.5.213;
#  option subnet-mask 255.255.255.255;
#}

#lease {
#  interface "eth0";
#  fixed-address 192.33.137.200;
#  medium "link0 link1";
#  option host-name "andare.swiftmedia.com";
#  option subnet-mask 255.255.255.0;
#  option broadcast-address 192.33.137.255;
#  option routers 192.33.137.250;
#  option domain-name-servers 127.0.0.1;
#  renew 2 2000/1/12 00:00:01;
#  rebind 2 2000/1/12 00:00:01;
#  expire 2 2000/1/12 00:00:01;
#}
EOF
/usr/local/sbin/dhclient ${UPLINK_IFACE}"."${INFRA_VLAN}
/sbin/route -nv add -net 224.0.0.0/4 dev ${UPLINK_IFACE}"."${INFRA_VLAN}
IP_POSTFIX=$(ifconfig eth0 | awk '/inet addr/{print substr($2,6)}' | awk -F '.' '{print $4}')
vconfig add ${UPLINK_IFACE} ${KUBEAPI_VLAN}
/sbin/ip link set dev ${UPLINK_IFACE}"."${KUBEAPI_VLAN} up
if [ $(pidof kube-apiserver) ]; then
    /sbin/ip a a ${API_SERVER_IP}"/"${ACI_NODE_SUBNET#*/} dev ${UPLINK_IFACE}"."${KUBEAPI_VLAN}
else
    /sbin/ip a a ${API_SERVER_IP%.*}"."${IP_POSTFIX}"/"${ACI_NODE_SUBNET#*/} dev ${UPLINK_IFACE}"."${KUBEAPI_VLAN}
fi
/sbin/ip link set dev ${UPLINK_IFACE}"."${KUBEAPI_VLAN} mtu 1800

ip r a ${ACI_NODE_SUBNET%.*}".0/"${ACI_NODE_SUBNET##*/} via ${ACI_NODE_SUBNET%/*} dev ${UPLINK_IFACE}"."${KUBEAPI_VLAN} 
ip r a ${ACI_SVC_GW%.*}".0/"${ACI_SVC_SUBNET_PREFIX} via ${ACI_NODE_SUBNET%/*} dev ${UPLINK_IFACE}"."${KUBEAPI_VLAN} 
ip r a ${ACI_POD_SUBNET%.*}".0/"${ACI_POD_SUBNET##*/} via ${ACI_NODE_SUBNET%/*} dev ${UPLINK_IFACE}"."${KUBEAPI_VLAN} 
ip r a ${ACI_EXTERNAL_STATIC_SUBNET%.*}".0/"${ACI_EXTERNAL_STATIC_SUBNET##*/} via ${ACI_NODE_SUBNET%/*} dev ${UPLINK_IFACE}"."${KUBEAPI_VLAN} 
ip r a ${ACI_EXTERNAL_DYNAMIC_SUBNET%.*}".0/"${ACI_EXTERNAL_DYNAMIC_SUBNET##*/} via ${ACI_NODE_SUBNET%/*} dev ${UPLINK_IFACE}"."${KUBEAPI_VLAN} 
sleep infinity
