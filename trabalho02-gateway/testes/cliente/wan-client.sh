#!/bin/sh
# wan-client.sh - rode em OUTRO PC da rede do laboratorio (lado WAN).
# Uso: sh wan-client.sh IP_WAN_DO_ROTEADOR IP_CLIENTE_LAN
# Antes: no cliente da LAN rode servidor-8080.sh  (nc -l 8080)
# Para o teste de isolamento valer, adicione a rota para a LAN (como root):
#   Linux:   sudo ip route add 10.10.0.0/16 via IP_WAN_DO_ROTEADOR
#   FreeBSD: route add 10.10.0.0/16 IP_WAN_DO_ROTEADOR
WAN=$1; LANC=$2
[ -n "$WAN" ] && [ -n "$LANC" ] || { echo "Uso: sh wan-client.sh IP_WAN_DO_ROTEADOR IP_CLIENTE_LAN"; exit 2; }
PASS=0; FAIL=0

T() { if command -v timeout >/dev/null 2>&1; then timeout "$@"; else shift; "$@"; fi; }
ok()   { printf '[ OK ] %s\n' "$1"; PASS=$((PASS+1)); }
nok()  { printf '[FALHOU] %s\n' "$1"; FAIL=$((FAIL+1)); }
check() { d=$1; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else nok "$d"; fi; }
deny()  { d=$1; shift; if "$@" >/dev/null 2>&1; then nok "$d"; else ok "$d"; fi; }

echo "=== TESTES NO PC DA WAN ==="
check "DNAT: porta 80 do roteador ($WAN) conecta" nc -z -w 3 "$WAN" 80
sleep 1
printf 'DNAT-OK-oi\n' | nc -w 3 "$WAN" 80 >/dev/null 2>&1
echo "[INFO] enviei 'DNAT-OK-oi': esse texto deve aparecer no terminal do cliente da LAN"

if ! { ip route 2>/dev/null; netstat -rn 2>/dev/null; } | grep -q '^10\.10'; then
  echo "[AVISO] sem rota para 10.10.0.0/16: o isolamento abaixo falharia por falta de rota, nao pelo firewall."
  echo "        Adicione a rota (veja o topo deste script) e rode de novo."
fi
deny "isolamento: ping direto a $LANC falha" T 8 ping -c 2 "$LANC"
deny "isolamento: TCP direto a $LANC:22 falha" nc -z -w 3 "$LANC" 22
echo "--> $PASS ok, $FAIL falhas"
[ "$FAIL" -eq 0 ]
