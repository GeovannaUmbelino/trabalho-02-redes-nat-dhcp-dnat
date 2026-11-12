#!/bin/sh
# Teste 1 - Conectividade (rodar no ROTEADOR)
ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd); . "$ROOT_DIR/lib/common.sh"; . "$ROOT_DIR/tests/lib.sh"
echo "== 01 Conectividade =="
check "LAN_IF tem $LAN_GW_IP"        sh -c "ifconfig $LAN_IF | grep -q 'inet $LAN_GW_IP '"
check "WAN_IF tem IPv4"              sh -c "ifconfig $WAN_IF | grep -q 'inet '"
check "forwarding IPv4 ligado"       sh -c '[ "$(sysctl -n net.inet.ip.forwarding)" = 1 ]'
check "rota default existe"          route -n get default
check "gateway padrão responde ping" sh -c 'ping -c 1 -t 3 $(route -n get default | awk "/gateway:/{print \$2}")'
check "DNS $DNS_SERVER responde"     sh -c "host unb.br $DNS_SERVER || drill unb.br @$DNS_SERVER"
summary
