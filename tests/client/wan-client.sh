#!/bin/sh
# Rodar em OUTRO HOST DA WAN (rede do lab).
#   sh wan-client.sh <IP_WAN_DO_ROTEADOR> <IP_CLIENTE_LAN> [PORTA_WAN=80] [PORTA_LAN=8080]
# Pré-requisitos:
#   - no cliente LAN: while true; do nc -l 8080; done
#   - neste host:  route/ip route para 10.10.0.0/16 via IP_WAN_DO_ROTEADOR (para o teste de isolamento ser válido)
R=${1:?uso: $0 <ip_wan_roteador> <ip_cliente_lan> [porta_wan] [porta_lan]}; T=${2:?}
PW=${3:-80}; PL=${4:-8080}; F=0
ok() { printf '  [ OK ]  %s\n' "$1"; }; bad() { printf '  [FALHA] %s\n' "$1"; F=1; }
echo "== Host da WAN =="
nc -z -w 3 "$R" "$PW" >/dev/null 2>&1 && ok "DNAT: $R:$PW alcança o cliente da LAN" || bad "DNAT: $R:$PW sem resposta"
ping -c 2  "$T" >/dev/null 2>&1 && bad "isolamento: ping direto em $T NÃO deveria responder" || ok "isolamento: ping direto em $T falha (esperado)"
nc -z -w 3 "$T" "$PL" >/dev/null 2>&1 && bad "isolamento: TCP direto em $T:$PL NÃO deveria conectar" || ok "isolamento: TCP direto em $T:$PL falha (esperado)"
exit $F
