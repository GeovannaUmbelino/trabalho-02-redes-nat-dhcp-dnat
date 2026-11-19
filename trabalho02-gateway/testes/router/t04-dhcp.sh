#!/bin/sh
# TESTE 04 - DHCP (servico, reserva, leases e log)
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/testes/router/lib.sh"
titulo "TESTE 04 - DHCP"

CONF=/usr/local/etc/dhcpd.conf
t_run()     { pgrep -x dhcpd; }
t_syntax()  { dhcpd -t -cf "$CONF"; }
t_subnet()  { grep -q "subnet $LAN_NETADDR netmask $LAN_MASK" "$CONF"; }
t_dns()     { grep -q "domain-name-servers $DNS_SERVER" "$CONF"; }
t_ifaces()  { [ "$(sysrc -n dhcpd_ifaces 2>/dev/null)" = "$LAN_IF" ]; }
t_reserva() { grep -qi "hardware ethernet $STATIC_HOST_MAC" "$CONF" && grep -q "fixed-address $STATIC_HOST_IP" "$CONF"; }
t_leases()  { [ -f /var/db/dhcpd/dhcpd.leases ]; }
t_log()     { [ -f /var/log/dhcpd.log ]; }

check "dhcpd esta rodando" t_run
check "dhcpd.conf valido (dhcpd -t)" t_syntax
check "sub-rede $LAN_NETADDR/$LAN_MASK declarada" t_subnet
check "DNS entregue: $DNS_SERVER" t_dns
check "dhcpd escuta so na LAN ($LAN_IF)" t_ifaces
if [ -n "$STATIC_HOST_MAC" ]; then
  check "reserva por MAC: $STATIC_HOST_MAC -> $STATIC_HOST_IP" t_reserva
else
  info "reserva de IP fixo ainda NAO configurada: sh scripts/reserva.sh <MAC>"
fi
check "arquivo de leases existe" t_leases
check "arquivo de log existe" t_log
info "leases ativas: $(grep -c '^lease' /var/db/dhcpd/dhcpd.leases 2>/dev/null)"
info "ultimas mensagens DHCP no log:"
grep -E 'DHCP(DISCOVER|OFFER|REQUEST|ACK)' /var/log/dhcpd.log 2>/dev/null | tail -4
info "para mostrar ao professor: cat /var/db/dhcpd/dhcpd.leases ; tail -20 /var/log/dhcpd.log"
resumo
