#!/bin/sh
# Teste 2 - Tradução de endereço (NAT). Antes: no cliente LAN rode `host unb.br <DNS>`.
ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd); . "$ROOT_DIR/lib/common.sh"; . "$ROOT_DIR/tests/lib.sh"
echo "== 02 NAT =="
check "pf habilitado"                sh -c "pfctl -si | grep -q 'Status: Enabled'"
check "regra nat carregada"          sh -c "pfctl -sn | grep -q 'nat on $WAN_IF'"
echo "  Estados traduzidos (formato: IP_WAN:porta (IP_LAN:porta) -> destino):"
pfctl -ss | grep '(' | head -5 | sed 's/^/    /' || true
summary
