#!/bin/sh
# Teste 5 - DNAT (regras). O teste ativo é tests/client/wan-client.sh
ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd); . "$ROOT_DIR/lib/common.sh"; . "$ROOT_DIR/tests/lib.sh"
echo "== 05 DNAT =="
check "regra rdr carregada para $DNAT_TARGET_IP" sh -c "pfctl -sn | grep rdr | grep -q '$DNAT_TARGET_IP'"
summary
