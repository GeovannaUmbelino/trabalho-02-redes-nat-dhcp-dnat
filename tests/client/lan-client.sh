#!/bin/sh
# Rodar em um CLIENTE DA LAN (Linux ou BSD; o ping sem timeout demora alguns segundos quando falha), depois de pegar IP via DHCP.
#   sh lan-client.sh [IP_GATEWAY] [IP_DNS]
GW=${1:-10.10.0.1}; DNS=${2:-164.41.101.4}
ok() { printf '  [ OK ]  %s\n' "$1"; }; bad() { printf '  [FALHA] %s\n' "$1"; F=1; }; F=0
echo "== Cliente LAN =="
ping -c 2  "$GW" >/dev/null 2>&1 && ok "ping no gateway $GW funciona" || bad "ping no gateway $GW"
if command -v host >/dev/null; then host unb.br "$DNS" >/dev/null 2>&1; else nslookup unb.br "$DNS" >/dev/null 2>&1; fi \
  && ok "consulta DNS via $DNS (passa pelo NAT)" || bad "consulta DNS via $DNS"
ping -c 2  "$DNS" >/dev/null 2>&1 && bad "ping para FORA deveria estar BLOQUEADO" || ok "ping para fora bloqueado (esperado)"
exit $F
