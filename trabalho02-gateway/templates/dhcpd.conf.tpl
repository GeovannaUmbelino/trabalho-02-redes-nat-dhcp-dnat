authoritative;
default-lease-time 600;
max-lease-time 7200;
option domain-name-servers @DNS_SERVER@;
log-facility local7;

subnet @LAN_NETADDR@ netmask @LAN_MASK@ {
  range @DHCP_RANGE_START@ @DHCP_RANGE_END@;
  option routers @LAN_IP@;
  option subnet-mask @LAN_MASK@;
  option broadcast-address @LAN_BROADCAST@;
}

# BEGIN-RESERVA
host @STATIC_HOST_NAME@ {
  hardware ethernet @STATIC_HOST_MAC@;
  fixed-address @STATIC_HOST_IP@;
}
# END-RESERVA
