#!/bin/sh
# [Modulo 3] Firewall: bloqueia ping da LAN para fora do segmento.
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd); . "$ROOT_DIR/lib/common.sh"
require_root; require_freebsd
pf_install 50-icmp.conf
pf_reload
log "Firewall: ICMP echo-request LAN -> fora bloqueado"
