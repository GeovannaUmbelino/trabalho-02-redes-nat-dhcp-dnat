#!/bin/sh
# Orquestrador. Sem argumentos roda todos os módulos; com argumentos roda só os citados:
#   sh scripts/setup.sh                 # tudo
#   sh scripts/setup.sh 30-dhcp         # só o DHCP
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd); . "$ROOT_DIR/lib/common.sh"
require_root; require_freebsd
[ $# -gt 0 ] && MODULES="$*" || MODULES="10-network 20-nat 30-dhcp 40-dnat 50-firewall"
for m in $MODULES; do
  log "=== módulo $m ==="
  sh "$ROOT_DIR/scripts/$m.sh"
done
log "Pronto. Valide com: sh tests/run-all.sh"
