#!/bin/sh
# 02-dhcp.sh - servidor DHCP (ISC dhcpd) na LAN + log das leases
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/lib/common.sh"
need_root; need_freebsd
need_iface "$LAN_IF"

echo "=== 02-dhcp: dhcpd na $LAN_IF ($LAN_NET), DNS $DNS_SERVER ==="
[ -x /usr/local/sbin/dhcpd ] || die "dhcpd nao instalado. Instale (com internet): pkg install -y isc-dhcp44-server"
ifconfig "$LAN_IF" | grep -q "inet $LAN_IP " || die "a $LAN_IF nao tem $LAN_IP. Rode antes: sh scripts/01-rede.sh"

backup_once /usr/local/etc/dhcpd.conf
render "$ROOT/templates/dhcpd.conf.tpl" /tmp/dhcpd.conf.novo
dhcpd -t -cf /tmp/dhcpd.conf.novo >/tmp/dhcpd.teste 2>&1 || { cat /tmp/dhcpd.teste; die "dhcpd.conf com erro (nada foi aplicado)"; }
cp /tmp/dhcpd.conf.novo /usr/local/etc/dhcpd.conf
good "dhcpd.conf validado e instalado"

# arquivos de leases e log dedicado
mkdir -p /var/db/dhcpd
touch /var/db/dhcpd/dhcpd.leases /var/log/dhcpd.log
printf 'local7.*\t\t\t\t/var/log/dhcpd.log\n' > /etc/syslog.d/dhcpd.conf
service syslogd restart >/dev/null 2>&1
good "log do DHCP: /var/log/dhcpd.log"

sysrc dhcpd_enable=YES >/dev/null
sysrc "dhcpd_ifaces=${LAN_IF}" >/dev/null
service isc-dhcpd restart
sleep 2
if pgrep -x dhcpd >/dev/null 2>&1; then
  good "dhcpd rodando"
else
  tail -20 /var/log/messages 2>/dev/null
  die "dhcpd nao subiu (veja as mensagens acima)"
fi
if [ -n "$STATIC_HOST_MAC" ]; then
  good "reserva ativa: $STATIC_HOST_MAC -> $STATIC_HOST_IP"
else
  warn "sem reserva de IP fixo ainda. Depois que o cliente pedir IP: sh scripts/reserva.sh <MAC>"
fi
exit 0
