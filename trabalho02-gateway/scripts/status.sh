#!/bin/sh
# status.sh - mostra tudo que o professor pode pedir para ver
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/lib/common.sh"
need_root
echo "=== valores usados ==="; echo "WAN=$WAN_IF ($WAN_MODE)  LAN=$LAN_IF ($LAN_IP)  DNS=$DNS_SERVER  MAC fixo=${STATIC_HOST_MAC:-(nao definido)} -> $STATIC_HOST_IP"
echo "=== interfaces ==="; ifconfig "$WAN_IF" | grep -E 'inet |status'; ifconfig "$LAN_IF" | grep -E 'inet |status'
echo "=== forwarding ==="; sysctl net.inet.ip.forwarding
echo "=== rota default ==="; netstat -rn -f inet | grep '^default'
echo "=== pf ==="; pfctl -si 2>/dev/null | head -2
echo "=== NAT/DNAT (pfctl -sn) ==="; pfctl -sn 2>/dev/null
echo "=== regras (pfctl -sr) ==="; pfctl -sr 2>/dev/null
echo "=== estados traduzidos (NAT) ==="; pfctl -ss 2>/dev/null | grep -E '\([0-9.]+:[0-9]+\)' || echo "(nenhum ainda)"
echo "=== estados do DNAT ==="; pfctl -ss 2>/dev/null | grep "$DNAT_TARGET_IP:$DNAT_TARGET_PORT" || echo "(nenhum ainda)"
echo "=== dhcpd ==="; service isc-dhcpd status
echo "=== leases (/var/db/dhcpd/dhcpd.leases) ==="; cat /var/db/dhcpd/dhcpd.leases
echo "=== log (/var/log/dhcpd.log) ==="; tail -20 /var/log/dhcpd.log
