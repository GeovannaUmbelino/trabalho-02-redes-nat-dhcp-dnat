#!/bin/bash
# ==============================================================================
# ALIASES E FUNÇÕES PARA A MÁQUINA CLIENTE (Trabalho 02 - Redes)
# Interface cabeada detectada: eno1 (MAC original: ec:f4:bb:f6:43:b3)
# Interface Wi-Fi detectada:   wlp2s0
# ==============================================================================

# Interface de rede cabeada padrão
export CLIENT_IFACE="eno1"
export ORIGINAL_MAC="ec:f4:bb:f6:43:b3"
export LAN_GW="10.10.0.1"

# Helper interno: força a rota default para o gateway da LAN via cabo.
# Isso é o que fazia funcionar de verdade a troca de IP:
# o dhclient sozinho nao sobrescreve a rota default quando ha Wi-Fi ativa.
_forcar_rota_default() {
    local GW="${1:-$LAN_GW}"
    # Remove qualquer rota default existente (pode ser da Wi-Fi ou rota antiga)
    sudo ip route del default 2>/dev/null || true
    # Adiciona a rota default apontando para o gateway do BSD via cabo
    sudo ip route add default via "$GW" dev "$CLIENT_IFACE"
    echo ">> Rota default configurada: gateway $GW via $CLIENT_IFACE"
    ip route show | grep default
}

# --- 1. CONTROLE DE WI-FI ---
# Desliga o Wi-Fi (essencial para que todo o tráfego saia pelo cabo conectado ao BSD)
alias wifioff="nmcli radio wifi off && echo '[OK] Wi-Fi desativado! Trafego agora passara pela rede cabeada.'"

# Religa o Wi-Fi (quando terminar o teste ou sair do lab)
alias wifion="nmcli radio wifi on && echo '[OK] Wi-Fi reativado!'"

# Consulta o status do Wi-Fi
alias wifistatus="nmcli radio wifi"


# --- 2. CONSULTA DE IP E ROTAS ---
# Mostra o IP atual da interface cabeada e o gateway padrão
alias meuip="echo '--- [IP na interface $CLIENT_IFACE] ---' && ip -4 addr show \$CLIENT_IFACE | grep inet && echo '--- [Rota padrao / Gateway] ---' && ip route show | grep default"


# --- 3. DHCP E CONFIGURAÇÃO DE IP ---
# Renova a concessão DHCP mantendo o mesmo MAC (pede confirmação/renovação ao DHCP do BSD)
renovarip() {
    echo ">> Liberando IP atual e solicitando renovação via DHCP na interface $CLIENT_IFACE..."
    sudo dhclient -r "$CLIENT_IFACE" 2>/dev/null || sudo nmcli device disconnect "$CLIENT_IFACE"
    sleep 1
    sudo dhclient "$CLIENT_IFACE" 2>/dev/null || sudo nmcli device connect "$CLIENT_IFACE"
    sleep 1
    # IMPORTANTE: dhclient sozinho nao sobrescreve a rota default quando ha Wi-Fi ativa.
    # Esta linha garante que o trafego saia pelo cabo e passe pelo roteador BSD.
    _forcar_rota_default "$LAN_GW"
    echo ">> IP atualizado:"
    ip -4 addr show "$CLIENT_IFACE" | grep inet
}

# Define um IP estático manualmente na sua máquina (sem depender de DHCP)
# Exemplo: fixarip 10.10.0.50
fixarip() {
    local IP="$1"
    local MASK="${2:-16}"
    local GW="${3:-$LAN_GW}"
    if [ -z "$IP" ]; then
        echo "Uso: fixarip <IP> [mascara] [gateway]"
        echo "Exemplo: fixarip 10.10.0.50"
        return 1
    fi
    echo ">> Definindo IP estático $IP/$MASK com gateway $GW na interface $CLIENT_IFACE..."
    sudo ip addr flush dev "$CLIENT_IFACE"
    sudo ip addr add "$IP/$MASK" dev "$CLIENT_IFACE"
    sudo ip link set dev "$CLIENT_IFACE" up
    _forcar_rota_default "$GW"
    echo ">> Configuração manual aplicada:"
    ip -4 addr show "$CLIENT_IFACE" | grep inet
}

# Solicita OUTRO IP da rede (gera um MAC temporário aleatório para pegar um IP dinâmico do pool DHCP)
# Muito útil se o professor pedir: 'Se entrar outra máquina que não tem IP reservado, o que acontece?'
pedirnovoippool() {
    local NOVO_MAC
    NOVO_MAC=$(printf '02:%02x:%02x:%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
    echo ">> Alterando temporariamente o MAC da interface $CLIENT_IFACE para: $NOVO_MAC"
    sudo ip link set dev "$CLIENT_IFACE" down
    sudo ip link set dev "$CLIENT_IFACE" address "$NOVO_MAC"
    sudo ip link set dev "$CLIENT_IFACE" up
    echo ">> Solicitando novo IP via DHCP do pool dinâmico..."
    sudo dhclient -r "$CLIENT_IFACE" 2>/dev/null
    sleep 1
    sudo dhclient "$CLIENT_IFACE"
    sleep 1
    # Garante rota default via BSD mesmo com Wi-Fi ativa
    _forcar_rota_default "$LAN_GW"
    echo ">> Novo IP recebido do roteador BSD:"
    ip -4 addr show "$CLIENT_IFACE" | grep inet
}

# Restaura o MAC original de fábrica da interface (para voltar a receber o IP reservado, ex: 10.10.0.100)
restaurarmac() {
    echo ">> Restaurando MAC original de fábrica ($ORIGINAL_MAC)..."
    sudo ip link set dev "$CLIENT_IFACE" down
    sudo ip link set dev "$CLIENT_IFACE" address "$ORIGINAL_MAC"
    sudo ip link set dev "$CLIENT_IFACE" up
    echo ">> Renovando concessão DHCP com o MAC original..."
    sudo dhclient -r "$CLIENT_IFACE" 2>/dev/null
    sleep 1
    sudo dhclient "$CLIENT_IFACE"
    sleep 1
    # Garante rota default via BSD mesmo com Wi-Fi ativa
    _forcar_rota_default "$LAN_GW"
    echo ">> IP obtido (deve ser o IP estático reservado no dhcpd.conf):"
    ip -4 addr show "$CLIENT_IFACE" | grep inet
}


# --- 4. ABRIR SOQUETE DE PORTA (TESTE DE DNAT / FIREWALL) ---
# Abre um socket TCP escutando em uma porta específica (padrão: 8080)
# Mostra na tela qualquer mensagem enviada por outro PC conectado à porta 80 do BSD
ouvirporta() {
    local PORTA="${1:-8080}"
    echo "=========================================================="
    echo ">> Abrindo socket TCP de escuta na porta $PORTA..."
    echo ">> Para o teste de DNAT: o roteador BSD redireciona WAN:80 -> LAN:$PORTA"
    echo ">> Digite Ctrl+C para encerrar o socket."
    echo "=========================================================="
    while true; do
        nc -l -p "$PORTA" 2>/dev/null || nc -l "$PORTA"
    done
}

# Abre servidor web simples em Python na porta informada (padrão: 8080)
# Permite testar acessando via curl ou navegador web em http://IP_WAN_ROTEADOR:80/
servidorweb() {
    local PORTA="${1:-8080}"
    echo ">> Iniciando servidor HTTP na porta $PORTA (DNAT WAN:80 -> LAN:$PORTA)..."
    echo ">> Pressione Ctrl+C para finalizar."
    python3 -m http.server "$PORTA"
}

# Atalho direto para o teste de DNAT (abre na porta 8080)
alias testardnat="ouvirporta 8080"


# --- 5. EXECUÇÃO RÁPIDA DOS TESTES AUTOMÁTICOS DO TRABALHO ---
testarcliente() {
    local GW="${1:-10.10.0.1}"
    local DNS="${2:-164.41.101.4}"
    local SCRIPT_PATH="/home/jonas/Downloads/trabalho2rede/trabalho-02-redes-nat-dhcp-dnat/tests/client/lan-client.sh"
    
    if [ -f "$SCRIPT_PATH" ]; then
        sh "$SCRIPT_PATH" "$GW" "$DNS"
    else
        echo "Script de teste não encontrado em $SCRIPT_PATH"
    fi
}
