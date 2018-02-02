FROM ubuntu:16.04

RUN apt-get update &&  DEBIAN_FRONTEND=noninteractive apt-get install -q -y net-tools isc-dhcp-client aptitude vlan\
&& rm -rf /var/lib/apt/lists/*

ADD entrypoint.sh /

CMD ["/entrypoint.sh"]
