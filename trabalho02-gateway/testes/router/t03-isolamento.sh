#!/bin/sh
# TESTE 03 - Isolamento de segmento
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/testes/router/lib.sh"
titulo "TESTE 03 - Isolamento de segmento"

t_block_wan() { pfctl -sr 2>/dev/null | grep -Eq "block.* in on $WAN_IF "; }
t_wan_no_lan() { pfx=$(echo "$LAN_NETADDR" | cut -d. -f1-2); ! ifconfig "$WAN_IF" | grep -q "inet ${pfx}\."; }
t_lan_ip()     { ifconfig "$LAN_IF" | grep -q "inet $LAN_IP "; }

check "regra: bloqueia entrada nova pela WAN ($WAN_IF)" t_block_wan
check "a WAN nao tem endereco da faixa da LAN" t_wan_no_lan
check "a LAN ($LAN_IF) esta em segmento proprio ($LAN_NET)" t_lan_ip
info "Prova pratica no PC da WAN (com rota para $LAN_NET via IP da WAN do roteador):"
info "    sh testes/cliente/wan-client.sh <IP_WAN_DO_ROTEADOR> <IP_CLIENTE_LAN>"
resumo
