#!/bin/sh
# Biblioteca compartilhada por todos os módulos.
# Uso (no topo de cada script):
#   ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd); . "$ROOT_DIR/lib/common.sh"
set -eu
. "$ROOT_DIR/config/gateway.conf"

PF_DIR=/etc/pf.d
DHCP_CONF=/usr/local/etc/dhcpd.conf
DHCP_LEASES=/var/db/dhcpd/dhcpd.leases
DHCP_LOG=/var/log/dhcpd.log
TEMPLATE_VARS="WAN_IF LAN_IF WAN_MODE WAN_IP WAN_MASK WAN_GW LAN_NET LAN_NET_ADDR LAN_MASK \
LAN_PREFIX LAN_GW_IP DHCP_RANGE_START DHCP_RANGE_END DNS_SERVER STATIC_HOST_NAME \
STATIC_HOST_MAC STATIC_HOST_IP DNAT_WAN_PORT DNAT_TARGET_IP DNAT_TARGET_PORT"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { log "ERRO: $*" >&2; exit 1; }

require_root()    { [ "$(id -u)" -eq 0 ] || die "execute como root (su -)"; }
require_freebsd() { [ "$(uname -s)" = FreeBSD ] || die "projeto feito para FreeBSD (detectado: $(uname -s))"; }
require_iface()   { ifconfig "$1" >/dev/null 2>&1 || die "interface '$1' não existe (veja 'ifconfig -l' e ajuste config/gateway.conf)"; }

# Guarda cópia do arquivo original UMA vez (sufixo .pre-t2) para o teardown restaurar.
backup_once() {
  if [ -f "$1" ] && [ ! -f "$1.pre-t2" ]; then cp -p "$1" "$1.pre-t2"; fi
  return 0
}
# Restaura o original; se não havia original, remove o arquivo criado por nós.
restore_or_remove() {
  if [ -f "$1.pre-t2" ]; then mv "$1.pre-t2" "$1"; else rm -f "$1"; fi
  return 0
}

# render <template> <saida>: troca @VARIAVEL@ pelos valores de config/gateway.conf.
render() {
  _sedf=$(mktemp)
  for _v in $TEMPLATE_VARS; do
    eval "_val=\${$_v}"
    printf 's|@%s@|%s|g\n' "$_v" "$_val" >> "$_sedf"
  done
  sed -f "$_sedf" "$1" > "$2"
  rm -f "$_sedf"
  if grep -q '@[A-Z_]*@' "$2"; then die "variável não substituída em $2 (template $1)"; fi
}

# Instala um fragmento do pf: pf_install <nome-do-fragmento, ex.: 10-nat.conf>
pf_install() {
  mkdir -p "$PF_DIR"
  render "$ROOT_DIR/templates/pf/$1.tpl" "$PF_DIR/$1"
}

# Regera /etc/pf.conf incluindo todos os fragmentos de /etc/pf.d (ordem alfabética =
# ordem exigida pelo pf: opções -> nat/rdr -> filtros), valida e carrega.
# Se a validação falhar, NADA é aplicado.
pf_reload() {
  mkdir -p "$PF_DIR"
  render "$ROOT_DIR/templates/pf/00-macros.conf.tpl" "$PF_DIR/00-macros.conf"
  backup_once /etc/pf.conf
  {
    echo "# Gerado por trabalho02-gateway. Nao edite: altere config/ e templates/."
    for _f in "$PF_DIR"/*.conf; do echo "include \"$_f\""; done
  } > /etc/pf.conf.new
  pfctl -nf /etc/pf.conf.new || die "pf.conf inválido; nada foi aplicado (veja /etc/pf.conf.new)"
  mv /etc/pf.conf.new /etc/pf.conf
  sysrc -q pf_enable=YES pf_rules=/etc/pf.conf >/dev/null
  kldload -n pf 2>/dev/null || true
  service pf onestart >/dev/null 2>&1 || true
  pfctl -f /etc/pf.conf
  pfctl -e 2>/dev/null || true
  log "pf recarregado ($(ls "$PF_DIR" | wc -l | tr -d ' ') fragmentos)"
}
