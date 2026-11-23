#!/bin/bash
# ==============================================================================
# Script de Instalação de Dependências para o Cliente de Testes (Linux / Debian / Ubuntu / Mint)
# Trabalho 02 - Redes de Computadores (Prof. Tiago Alves)
# ==============================================================================

set -e

echo "=== Verificando e instalando dependências do cliente de testes ==="

# Verifica se está executando com sudo/root
if [ "$EUID" -ne 0 ]; then
    echo "[!] Por favor, execute este script com sudo:"
    echo "    sudo $0"
    exit 1
fi

echo ">> Atualizando lista de pacotes..."
apt-get update -y

echo ">> Instalando pacotes necessários:"
echo "   - netcat-openbsd  : para abrir soquetes TCP e testar DNAT"
echo "   - isc-dhcp-client : dhclient para renovar/solicitar IP via DHCP"
echo "   - bind9-dnsutils  : nslookup e host para validar resolução DNS via NAT"
echo "   - iproute2        : comandos ip para manipulação de rotas e interfaces"
echo "   - network-manager : nmcli para desligar/ligar Wi-Fi"
echo "   - curl / telnet   : clientes de teste para DNAT na porta 80"
echo "   - tcpdump         : inspeção de tráfego caso seja necessário debugar pacotes"
echo "   - macchanger      : utilitário para troca rápida de MAC (opcional para teste de pool)"

apt-get install -y \
    netcat-openbsd \
    isc-dhcp-client \
    bind9-dnsutils \
    iproute2 \
    network-manager \
    curl \
    telnet \
    tcpdump \
    rfkill \
    macchanger || true

echo ""
echo "=== [OK] Todas as ferramentas necessárias estão instaladas! ==="
echo "Ferramentas disponíveis:"
for cmd in nc dhclient nslookup host ip nmcli curl telnet tcpdump python3; do
    if command -v "$cmd" >/dev/null 2>&1; then
        printf "  [✓] %-12s: %s\n" "$cmd" "$(command -v "$cmd")"
    else
        printf "  [✗] %-12s: NÃO ENCONTRADO\n" "$cmd"
    fi
done
echo "==============================================================="
