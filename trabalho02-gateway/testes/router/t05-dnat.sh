#!/bin/sh
# TESTE 05 - DNAT (WAN:80 -> LAN:8080)
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/testes/router/lib.sh"
titulo "TESTE 05 - DNAT ($DNAT_PUBLIC_PORT -> $DNAT_TARGET_IP:$DNAT_TARGET_PORT)"

t_rdr()  { regras | grep -E 'rdr' | grep -q "$DNAT_TARGET_IP"; }
t_pass() { pfctl -sr 2>/dev/null | grep -Eq "pass in on $WAN_IF .*$DNAT_TARGET_IP.*port = ($DNAT_TARGET_PORT|http-alt)"; }
t_pf_on() { pfctl -si 2>/dev/null | grep -q 'Status: Enabled'; }

check "pf habilitado" t_pf_on
check "regra rdr para $DNAT_TARGET_IP carregada" t_rdr
check "regra pass libera o destino traduzido (porta $DNAT_TARGET_PORT)" t_pass
WANIP=$(ifconfig "$WAN_IF" | awk '$1=="inet"{print $2; exit}')
info "IP da WAN do roteador (use no telnet): $WANIP"
info "1) no cliente $DNAT_TARGET_IP (LAN):   while true; do nc -l $DNAT_TARGET_PORT; done"
info "2) em OUTRO PC da WAN:                 telnet $WANIP $DNAT_PUBLIC_PORT     (digite: oi)"
if pfctl -ss 2>/dev/null | grep -q "$DNAT_TARGET_IP:$DNAT_TARGET_PORT"; then
  printf '[ OK ] ha estado de DNAT ativo:\n'; PASS=$((PASS+1))
  pfctl -ss 2>/dev/null | grep "$DNAT_TARGET_IP:$DNAT_TARGET_PORT" | head -3
else
  info "ainda sem conexao DNAT. Depois do telnet, repita este teste."
fi
resumo
