#!/bin/sh
# ativar.sh - UM COMANDO: detecta tudo, configura rede/DHCP/firewall, reserva o IP fixo e testa.
# Uso: sh scripts/ativar.sh              (completo)
#      sh scripts/ativar.sh --sem-cliente (nao espera o cliente da LAN; reserva depois)
ROOT=$(cd "$(dirname "$0")/.." && pwd)
[ "$(id -u)" -eq 0 ] || { echo "[ERRO] execute como root" >&2; exit 1; }
sh "$ROOT/scripts/00-detectar.sh" || exit 1
. "$ROOT/lib/common.sh"
need_freebsd
echo
sh "$ROOT/scripts/01-rede.sh" || die "falha no 01-rede"
echo
sh "$ROOT/scripts/02-dhcp.sh" || die "falha no 02-dhcp"
echo
sh "$ROOT/scripts/03-pf.sh"   || die "falha no 03-pf"
echo
if [ -z "$STATIC_HOST_MAC" ] && [ "$1" != "--sem-cliente" ]; then
  echo "=== RESERVA AUTOMATICA DO IP FIXO ==="
  echo ">>> Ligue o cliente da LAN no cabo da $LAN_IF e faca ele pedir IP (Windows: ipconfig /renew)."
  sh "$ROOT/scripts/reserva.sh" || warn "reserva nao concluida; depois rode: sh scripts/reserva.sh"
  echo
fi
echo "############ TESTES NO ROTEADOR ############"
sh "$ROOT/testes/router/rodar-todos.sh"
