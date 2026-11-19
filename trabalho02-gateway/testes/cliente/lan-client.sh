#!/bin/sh
# lan-client.sh - rode no CLIENTE DA LAN (Linux/BSD), depois que ele pegou IP por DHCP.
# Uso: sh lan-client.sh [GATEWAY] [DNS] [DESTINO_EXTERNO]
GW=${1:-10.10.0.1}
DNS=${2:-164.41.101.4}
EXT=${3:-164.41.101.4}
PASS=0; FAIL=0

T() { if command -v timeout >/dev/null 2>&1; then timeout "$@"; else shift; "$@"; fi; }
ok()   { printf '[ OK ] %s\n' "$1"; PASS=$((PASS+1)); }
nok()  { printf '[FALHOU] %s\n' "$1"; FAIL=$((FAIL+1)); }
check() { d=$1; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else nok "$d"; fi; }
deny()  { d=$1; shift; if "$@" >/dev/null 2>&1; then nok "$d"; else ok "$d"; fi; }

has_ip() { (ip -4 addr 2>/dev/null || ifconfig 2>/dev/null) | grep -q '10\.10\.'; }
dns_ok() {
  if command -v host >/dev/null 2>&1; then T 8 host unb.br "$DNS" | grep -q 'has address'
  elif command -v nslookup >/dev/null 2>&1; then T 8 nslookup unb.br "$DNS" | grep -A2 '^Name' | grep -q 'Address'
  elif command -v dig >/dev/null 2>&1; then [ -n "$(T 8 dig +short unb.br "@$DNS")" ]
  else return 1; fi
}

echo "=== TESTES NO CLIENTE DA LAN ==="
check "recebeu IP da faixa 10.10.x.x (DHCP)" has_ip
check "ping ao gateway $GW responde" T 8 ping -c 2 "$GW"
check "DNS $DNS resolve unb.br (passa pelo NAT)" dns_ok
deny  "ping para fora ($EXT) esta BLOQUEADO" T 8 ping -c 2 "$EXT"
echo "--> $PASS ok, $FAIL falhas"
echo "No roteador, agora: sh testes/router/t02-nat.sh  (deve mostrar o estado traduzido)"
[ "$FAIL" -eq 0 ]
