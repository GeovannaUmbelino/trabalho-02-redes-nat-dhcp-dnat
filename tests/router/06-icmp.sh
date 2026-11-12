#!/bin/sh
# Teste 6 - Firewall ICMP (regras). O teste ativo é tests/client/lan-client.sh
ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd); . "$ROOT_DIR/lib/common.sh"; . "$ROOT_DIR/tests/lib.sh"
echo "== 06 Firewall ICMP =="
check "bloqueio de echo-request LAN->fora" sh -c "pfctl -sr | grep block | grep -q 'icmp-type echoreq'"
summary
