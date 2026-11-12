#!/bin/sh
# Desfaz tudo que o projeto instalou e restaura os arquivos originais (.pre-t2).
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd); . "$ROOT_DIR/lib/common.sh"
require_root; require_freebsd

rm -rf "$PF_DIR"
restore_or_remove /etc/pf.conf
if [ -f /etc/pf.conf ]; then pfctl -f /etc/pf.conf || true; else pfctl -d 2>/dev/null || true; fi

service isc-dhcpd stop 2>/dev/null || true
restore_or_remove "$DHCP_CONF"
rm -f /etc/syslog.d/dhcpd.conf; service syslogd restart || true

ifconfig "$LAN_IF" inet "$LAN_GW_IP" delete 2>/dev/null || true
if [ -f /etc/rc.conf.pre-t2 ]; then mv /etc/rc.conf.pre-t2 /etc/rc.conf; fi
sysctl net.inet.ip.forwarding=0
log "Limpeza concluída (rc.conf restaurado). Reinicie para voltar ao estado original de rede."
