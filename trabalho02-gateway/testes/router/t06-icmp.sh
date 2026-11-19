#!/bin/sh
# TESTE 06 - Firewall: sem ping da LAN para fora
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/testes/router/lib.sh"
titulo "TESTE 06 - Bloqueio de ICMP (ping) para fora da LAN"

t_icmp() { pfctl -sr 2>/dev/null | grep -Eq "block.*quick on $LAN_IF .*icmp.*echoreq"; }
t_notlan() { pfctl -sr 2>/dev/null | grep -E "quick on $LAN_IF .*icmp" | grep -q '!'; }

check "regra: block in quick de ICMP echo na LAN ($LAN_IF)" t_icmp
check "regra usa 'to ! rede-da-LAN' (ping ao gateway $LAN_IP continua OK)" t_notlan
info "Prova pratica no CLIENTE da LAN: sh testes/cliente/lan-client.sh"
resumo
