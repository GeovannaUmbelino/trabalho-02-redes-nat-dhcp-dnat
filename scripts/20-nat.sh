#!/bin/sh
# [Modulo 1] NAT (nat on) + isolamento da WAN, via fragmentos do pf.
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd); . "$ROOT_DIR/lib/common.sh"
require_root; require_freebsd
pf_install 10-nat.conf
pf_install 30-isolamento.conf
pf_reload
