#!/bin/sh
# [Modulo 2] Servidor DHCP (ISC dhcpd, pacote isc-dhcp44-server) na interface da LAN.
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd); . "$ROOT_DIR/lib/common.sh"
require_root; require_freebsd; require_iface "$LAN_IF"

if ! pkg info -e isc-dhcp44-server; then
  log "Instalando isc-dhcp44-server (precisa de internet; ideal é instalar antes do dia do teste)"
  pkg install -y isc-dhcp44-server || die "falha ao instalar isc-dhcp44-server"
fi

backup_once "$DHCP_CONF"
render "$ROOT_DIR/templates/dhcpd.conf.tpl" "$DHCP_CONF"
mkdir -p "$(dirname "$DHCP_LEASES")"; [ -f "$DHCP_LEASES" ] || touch "$DHCP_LEASES"

# Log dedicado: o syslog padrão do FreeBSD ignora mensagens "info" do dhcpd.
mkdir -p /etc/syslog.d
printf 'local7.*\t\t\t\t\t%s\n' "$DHCP_LOG" > /etc/syslog.d/dhcpd.conf
[ -f "$DHCP_LOG" ] || touch "$DHCP_LOG"
service syslogd restart

sysrc dhcpd_enable=YES
sysrc "dhcpd_ifaces=$LAN_IF"
sysrc "dhcpd_conf=$DHCP_CONF"
service isc-dhcpd restart || service isc-dhcpd start
service isc-dhcpd status || die "dhcpd não subiu: veja $DHCP_LOG e /var/log/messages"
log "DHCP ativo em $LAN_IF (faixa $DHCP_RANGE_START-$DHCP_RANGE_END; reserva $STATIC_HOST_MAC -> $STATIC_HOST_IP)"
