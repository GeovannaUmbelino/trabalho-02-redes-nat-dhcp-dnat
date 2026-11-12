#!/bin/sh
# Teste 4 - DHCP. Leases e logs são exibidos ao final.
ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd); . "$ROOT_DIR/lib/common.sh"; . "$ROOT_DIR/tests/lib.sh"
echo "== 04 DHCP =="
check "dhcpd ativo"                  service isc-dhcpd status
check "reserva $STATIC_HOST_IP configurada" sh -c "grep -q 'fixed-address $STATIC_HOST_IP' $DHCP_CONF"
check "arquivo de leases existe"     test -f "$DHCP_LEASES"
echo "  Leases concedidos ($DHCP_LEASES):"
grep -E '^lease|hardware ethernet' "$DHCP_LEASES" | tail -12 | sed 's/^/    /' || true
echo "  Log ($DHCP_LOG):"
tail -8 "$DHCP_LOG" | sed 's/^/    /' || true
summary
