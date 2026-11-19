# lib/common.sh - funcoes comuns (POSIX sh, FreeBSD). Uso: ROOT=...; . lib/common.sh
. "$ROOT/config.sh"
if [ -f "$ROOT/config.auto" ]; then . "$ROOT/config.auto"; fi

log()  { printf '[..] %s\n' "$*"; }
good() { printf '[OK] %s\n' "$*"; }
warn() { printf '[AVISO] %s\n' "$*"; }
die()  { printf '[ERRO] %s\n' "$*" >&2; exit 1; }

need_root()    { [ "$(id -u)" -eq 0 ] || die "execute como root"; }
need_freebsd() { [ "$(uname -s)" = "FreeBSD" ] || die "estes scripts sao para FreeBSD"; }
need_iface()   { ifconfig "$1" >/dev/null 2>&1 || die "interface '$1' nao existe. Veja: ifconfig -l"; }
is_ipv4()      { echo "$1" | grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'; }

# setauto NOME VALOR : grava/atualiza um valor em config.auto
setauto() {
  { if [ -f "$ROOT/config.auto" ]; then grep -v "^$1=" "$ROOT/config.auto"; fi
    printf '%s="%s"\n' "$1" "$2"; } > "$ROOT/config.auto.tmp" \
    && mv "$ROOT/config.auto.tmp" "$ROOT/config.auto"
}

# Onde config.sh diz "auto", usa o valor detectado (config.auto)
t2_resolve() {
  if [ "$WAN_IF" = "auto" ];      then WAN_IF=${AUTO_WAN_IF:-auto}; fi
  if [ "$LAN_IF" = "auto" ];      then LAN_IF=${AUTO_LAN_IF:-auto}; fi
  if [ "$WAN_MODE" = "auto" ];    then WAN_MODE=${AUTO_WAN_MODE:-auto}; fi
  if [ "$DNS_SERVER" = "auto" ];  then DNS_SERVER=${AUTO_DNS_SERVER:-auto}; fi
  case "$STATIC_HOST_MAC" in auto|"") STATIC_HOST_MAC=${AUTO_STATIC_HOST_MAC:-} ;; esac
}
t2_resolve

# Se ainda faltar algo, roda a deteccao automatica (exceto dentro do proprio 00-detectar)
_t2_pend=0
for _v in WAN_IF LAN_IF WAN_MODE DNS_SERVER; do
  eval "_x=\$$_v"
  if [ "$_x" = "auto" ]; then _t2_pend=1; fi
done
if [ "$_t2_pend" = 1 ] && [ -z "$T2_NO_AUTODETECT" ]; then
  sh "$ROOT/scripts/00-detectar.sh" || exit 1
  . "$ROOT/config.auto"
  . "$ROOT/config.sh"
  t2_resolve
fi

backup_once() {
  if [ -e "$1" ] && [ ! -e "$1.pre-t2" ]; then cp -p "$1" "$1.pre-t2"; fi
  return 0
}

# render MODELO DESTINO : troca @VARIAVEL@ pelos valores do config.sh
render() {
  _tpl=$1; _out=$2; _args=""
  for _v in WAN_IF LAN_IF LAN_IP LAN_MASK LAN_NET LAN_NETADDR LAN_BROADCAST \
            DHCP_RANGE_START DHCP_RANGE_END DNS_SERVER STATIC_HOST_NAME \
            STATIC_HOST_MAC STATIC_HOST_IP DNAT_TARGET_IP DNAT_PUBLIC_PORT \
            DNAT_TARGET_PORT; do
    eval "_val=\${$_v}"
    _args="$_args -e s|@${_v}@|${_val}|g"
  done
  sed $_args "$_tpl" > "$_out.tmp" || die "falha ao gerar $_out"
  if [ -z "$STATIC_HOST_MAC" ]; then
    sed '/BEGIN-RESERVA/,/END-RESERVA/d' "$_out.tmp" > "$_out.tmp2" && mv "$_out.tmp2" "$_out.tmp"
  fi
  if grep -q '@[A-Z_]*@' "$_out.tmp"; then die "variavel sem valor em $_tpl"; fi
  mv "$_out.tmp" "$_out"
}
