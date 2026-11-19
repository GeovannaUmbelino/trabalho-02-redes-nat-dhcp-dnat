#!/bin/sh
# TESTE 02 - Traducao de endereco (NAT)
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/testes/router/lib.sh"
titulo "TESTE 02 - NAT (traducao de endereco)"

t_pf_on()    { pfctl -si 2>/dev/null | grep -q 'Status: Enabled'; }
t_nat_rule() { regras | grep -Eq "nat on $WAN_IF|nat-to"; }
t_fwd()      { [ "$(sysctl -n net.inet.ip.forwarding)" = "1" ]; }

check "pf habilitado" t_pf_on
check "regra de NAT na WAN ($WAN_IF) carregada" t_nat_rule
check "forwarding ligado" t_fwd

if pfctl -ss 2>/dev/null | grep -Eq '\([0-9.]+:[0-9]+\)'; then
  printf '[ OK ] ha estados traduzidos (IP_WAN (IP_LAN) -> destino):\n'
  PASS=$((PASS+1))
  pfctl -ss 2>/dev/null | grep -E '\([0-9.]+:[0-9]+\)' | head -5
else
  info "ainda sem estados traduzidos: no CLIENTE da LAN rode (nao use ping):"
  info "    nslookup unb.br $DNS_SERVER     (ou: host unb.br $DNS_SERVER)"
  info "depois repita: sh testes/router/t02-nat.sh"
fi
resumo
