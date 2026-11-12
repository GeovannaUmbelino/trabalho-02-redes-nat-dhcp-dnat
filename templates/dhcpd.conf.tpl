# /usr/local/etc/dhcpd.conf - gerado por trabalho02-gateway
option domain-name-servers @DNS_SERVER@;
default-lease-time 600;
max-lease-time 7200;
authoritative;
log-facility local7;      # vai para /var/log/dhcpd.log (ver scripts/30-dhcp.sh)

subnet @LAN_NET_ADDR@ netmask @LAN_MASK@ {
  option routers @LAN_GW_IP@;
  option subnet-mask @LAN_MASK@;
  range @DHCP_RANGE_START@ @DHCP_RANGE_END@;

  # Reserva: esta maquina recebe SEMPRE o mesmo IP
  host @STATIC_HOST_NAME@ {
    hardware ethernet @STATIC_HOST_MAC@;
    fixed-address @STATIC_HOST_IP@;
  }
}
