#!/bin/sh
# TESTE 01 - Conectividade
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/testes/router/lib.sh"
titulo "TESTE 01 - Conectividade"

t_wan_ip()   { ifconfig "$WAN_IF" | grep -q 'inet '; }
t_wan_link() { ifconfig "$WAN_IF" | grep -q 'status: active'; }
t_lan_ip()   { ifconfig "$LAN_IF" | grep -q "inet $LAN_IP "; }
t_lan_link() { ifconfig "$LAN_IF" | grep -q 'status: active'; }
t_fwd()      { [ "$(sysctl -n net.inet.ip.forwarding)" = "1" ]; }
t_default()  { netstat -rn -f inet | grep -q '^default'; }
t_gw() {
  gw=$(route -n get default 2>/dev/null | awk '/gateway:/{print $2}')
  [ -n "$gw" ] && ping -c 1 -t 3 "$gw"
}
t_dns() {
  if command -v host >/dev/null 2>&1; then
    timeout 6 host unb.br "$DNS_SERVER" | grep -q 'has address'
  else
    timeout 6 drill unb.br "@$DNS_SERVER" | grep -q 'ANSWER SECTION'
  fi
}

check "WAN $WAN_IF tem IP" t_wan_ip
check "WAN $WAN_IF com cabo (status: active)" t_wan_link
check "LAN $LAN_IF tem o IP $LAN_IP" t_lan_ip
check "LAN $LAN_IF com cabo (status: active)" t_lan_link
check "forwarding ligado (net.inet.ip.forwarding=1)" t_fwd
check "rota default existe" t_default
check "gateway da WAN responde ping" t_gw
check "DNS $DNS_SERVER resolve unb.br" t_dns
info "WAN: $(ifconfig "$WAN_IF" | awk '$1=="inet"{print $2; exit}')   LAN: $LAN_IP"
resumo
