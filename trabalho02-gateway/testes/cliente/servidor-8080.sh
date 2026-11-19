#!/bin/sh
# servidor-8080.sh - rode no cliente da LAN (10.10.0.100): servidor TCP para o teste do DNAT.
# O texto digitado no telnet do outro PC aparece aqui. Pare com Ctrl+C.
PORT=${1:-8080}
echo "Escutando na porta $PORT (aguardando conexao pelo DNAT)..."
while true; do
  nc -l "$PORT" 2>/dev/null || nc -l -p "$PORT"
done
