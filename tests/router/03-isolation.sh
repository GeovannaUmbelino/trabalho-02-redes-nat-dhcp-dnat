#!/bin/sh
# Teste 3 - Isolamento de segmento (regras). O teste ativo é tests/client/wan-client.sh
ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd); . "$ROOT_DIR/lib/common.sh"; . "$ROOT_DIR/tests/lib.sh"
echo "== 03 Isolamento =="
check "bloqueio padrão de entrada na WAN" sh -c "pfctl -sr | grep -q 'block drop in on $WAN_IF'"
summary
