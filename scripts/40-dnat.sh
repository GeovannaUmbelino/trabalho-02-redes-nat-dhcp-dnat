#!/bin/sh
# [Modulo 3] DNAT: WAN:DNAT_WAN_PORT -> DNAT_TARGET_IP:DNAT_TARGET_PORT.
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd); . "$ROOT_DIR/lib/common.sh"
require_root; require_freebsd
pf_install 20-rdr.conf         # traducao (rdr)
pf_install 40-dnat-pass.conf   # filtro (libera o destino traduzido)
pf_reload
log "DNAT: WAN:$DNAT_WAN_PORT -> $DNAT_TARGET_IP:$DNAT_TARGET_PORT"
