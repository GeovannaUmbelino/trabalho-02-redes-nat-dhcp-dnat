#!/bin/sh
# ==============================================================================
# ALIASES E FUNÇÕES PARA O ROTEADOR FREEBSD (Trabalho 02 - Redes)
# Copiar para o FreeBSD e executar: source aliases_roteador.sh
# Ou adicionar ao /root/.shrc:  . /caminho/para/aliases_roteador.sh
# ==============================================================================

# Detecta as interfaces dinamicamente a partir do config.sh do projeto
_CONF_PATH="$(dirname "$0")/config/gateway.conf"
[ -f "$_CONF_PATH" ] && . "$_CONF_PATH" || {
    # Fallback: valores padrão caso rode sem o repositório
    WAN_IF="ue0"
    LAN_IF="ue1"
    LAN_GW_IP="10.10.0.1"
    LAN_NET="10.10.0.0/16"
    DNAT_TARGET_IP="10.10.0.100"
    DNAT_WAN_PORT="80"
    DNAT_TARGET_PORT="8080"
    STATIC_HOST_IP="10.10.0.100"
    DNS_SERVER="164.41.101.4"
}

DHCP_CONF="/usr/local/etc/dhcpd.conf"
DHCP_LEASES="/var/db/dhcpd/dhcpd.leases"
DHCP_LOG="/var/log/dhcpd.log"


# ==============================================================================
# 1. STATUS GERAL (Ponto de Partida — rode SEMPRE primeiro)
# ==============================================================================

# Exibe tudo: interfaces, IPs, rotas, PF e DHCP em um único comando
status() {
    echo "========================================================"
    echo "  STATUS GERAL DO ROTEADOR BSD"
    echo "========================================================"
    echo ""
    echo "--- [Interfaces e IPs] ---"
    ifconfig | grep -E '^[a-z]|inet '
    echo ""
    echo "--- [Rota Default / Gateway WAN] ---"
    route -n get default | grep -E 'destination|gateway|interface' || netstat -rn | grep '^default'
    echo ""
    echo "--- [IP Forwarding] ---"
    sysctl net.inet.ip.forwarding
    echo ""
    echo "--- [PF Status] ---"
    pfctl -si | grep -E 'Status|Since'
    echo ""
    echo "--- [DHCP Status] ---"
    service isc-dhcpd status 2>/dev/null || service dhcpd status 2>/dev/null || echo "(dhcpd: verificar manualmente)"
    echo "========================================================"
}

# Exibe apenas os IPs configurados nas interfaces
alias verips="ifconfig | grep -E '^[a-zA-Z]|inet '"

# Exibe a tabela de roteamento
alias verrotas="netstat -rn"

# Verifica se o forwarding de pacotes IPv4 está ativado (precisa ser 1)
alias forwarding="sysctl net.inet.ip.forwarding"


# ==============================================================================
# 2. PACKET FILTER (PF) — Regras, Estados e Recarregamento
# ==============================================================================

# Exibe TODAS as regras ativas do PF (filtros + NAT + DNAT)
alias pfregras="echo '--- [Regras de Filtro] ---' && pfctl -sr && echo '' && echo '--- [Regras de Traducao NAT/DNAT] ---' && pfctl -sn"

# Exibe apenas regras de NAT e DNAT (traducao)
alias pfnat="pfctl -sn"

# Exibe a tabela de estados ativos (conexoes sendo traduzidas em tempo real)
alias pfestados="pfctl -ss"

# Exibe estados com tradução NAT (conexões com '(' indicam IP privado -> publico)
alias pfnat_live="echo 'Estados NAT/DNAT ativos (Ctrl+C para parar):' && watch -n 1 pfctl -ss"

# Exibe estados de traducao filtrando apenas conexoes com traducao de endereco
alias pfver_nat="pfctl -ss | grep '('"

# Exibe estatisticas do PF (pacotes passados, bloqueados, etc.)
alias pfstats="pfctl -si"

# Recarrega as regras do PF a partir do /etc/pf.conf
pf_reload() {
    echo ">> Recarregando regras do PF a partir de /etc/pf.conf..."
    pfctl -nf /etc/pf.conf && echo "  [OK] Sintaxe valida" || { echo "  [ERRO] Sintaxe invalida! Nada foi aplicado."; return 1; }
    pfctl -f /etc/pf.conf && echo "  [OK] Regras aplicadas"
    pfctl -e 2>/dev/null && echo "  [OK] PF habilitado" || true
}

# Reinicia o servico PF completamente
pf_restart() {
    echo ">> Reiniciando o servico PF..."
    service pf restart && echo "  [OK] PF reiniciado"
    pfctl -f /etc/pf.conf
}

# Habilita o PF (caso esteja desligado)
alias pf_enable="pfctl -e && echo '[OK] PF habilitado'"

# Desabilita o PF temporariamente (cuidado: libera todo o trafego)
alias pf_disable="pfctl -d && echo '[ATENCAO] PF DESABILITADO - todo trafego liberado'"

# Exibe o /etc/pf.conf gerado pelo setup
alias verconf_pf="cat /etc/pf.conf"


# ==============================================================================
# 3. DHCP — Status, Leases, Logs e Reinicialização
# ==============================================================================

# Exibe o status do daemon do DHCP
alias dhcp_status="service isc-dhcpd status 2>/dev/null || service dhcpd status 2>/dev/null"

# Reinicia o servidor DHCP
dhcp_restart() {
    echo ">> Reiniciando o servico DHCP..."
    service isc-dhcpd restart 2>/dev/null || service dhcpd restart 2>/dev/null
    echo "  [OK] DHCP reiniciado"
}

# Limpa as leases antigas e reinicia (util quando cliente nao pega IP)
dhcp_limpar_leases() {
    echo ">> Parando DHCP, limpando leases antigas e reiniciando..."
    service isc-dhcpd stop 2>/dev/null || service dhcpd stop 2>/dev/null || true
    > "$DHCP_LEASES"
    echo "  [OK] Arquivo de leases limpo: $DHCP_LEASES"
    service isc-dhcpd start 2>/dev/null || service dhcpd start 2>/dev/null
    echo "  [OK] DHCP reiniciado com leases vazias"
}

# Exibe as concessoes (leases) ativas com IP e MAC
alias dhcp_leases="echo '--- [Leases Ativas: IP e MAC] ---' && grep -E '^lease|hardware ethernet|binding state' $DHCP_LEASES | grep -v 'free' | head -40"

# Exibe o log do DHCP em tempo real (DISCOVER, OFFER, REQUEST, ACK)
alias dhcp_log="tail -f $DHCP_LOG"

# Exibe as ultimas 20 linhas do log do DHCP
alias dhcp_log_tail="tail -20 $DHCP_LOG"

# Exibe o arquivo de configuracao do DHCP
alias verconf_dhcp="cat $DHCP_CONF"


# ==============================================================================
# 4. TESTES DO TRABALHO 2 (01 ao 06 + todos de uma vez)
# ==============================================================================

_TESTS_DIR="$(dirname "$0")/tests"

# Roda todos os testes do roteador de uma vez
alias testar_tudo="sh $_TESTS_DIR/run-all.sh"

# 01 - Conectividade: IP nas interfaces, forwarding, rota default, DNS
alias teste01_conectividade="sh $_TESTS_DIR/router/01-connectivity.sh"

# 02 - NAT: PF ativo, regra nat carregada, mostra estados traduzidos
alias teste02_nat="sh $_TESTS_DIR/router/02-nat.sh"

# 03 - Isolamento: regra de bloqueio de entrada WAN ativa
alias teste03_isolamento="sh $_TESTS_DIR/router/03-isolation.sh"

# 04 - DHCP: servico ativo, reserva configurada, leases e log
alias teste04_dhcp="sh $_TESTS_DIR/router/04-dhcp.sh"

# 05 - DNAT: regra rdr carregada no PF
alias teste05_dnat="sh $_TESTS_DIR/router/05-dnat.sh"

# 06 - Firewall ICMP: bloqueio de echo-request da LAN para fora
alias teste06_icmp="sh $_TESTS_DIR/router/06-icmp.sh"


# ==============================================================================
# 5. TCPDUMP — Monitoramento de Trafego em Tempo Real
# ==============================================================================

# Captura TODO o trafego na interface WAN (para ver o NAT em acao)
tcpdump_wan() {
    local IFACE="${WAN_IF:-ue0}"
    echo ">> Capturando trafego na WAN ($IFACE) - Ctrl+C para parar..."
    tcpdump -ni "$IFACE" -l
}

# Captura TODO o trafego na interface LAN (para ver clientes DHCP e pings)
tcpdump_lan() {
    local IFACE="${LAN_IF:-ue1}"
    echo ">> Capturando trafego na LAN ($IFACE) - Ctrl+C para parar..."
    tcpdump -ni "$IFACE" -l
}

# Captura apenas trafego DHCP (portas 67 e 68) na interface LAN
tcpdump_dhcp() {
    local IFACE="${LAN_IF:-ue1}"
    echo ">> Capturando trafego DHCP (porta 67/68) em $IFACE - Ctrl+C para parar..."
    tcpdump -ni "$IFACE" -l port 67 or port 68
}

# Captura apenas trafego TCP na porta 80 da WAN (para ver o DNAT em acao)
tcpdump_dnat() {
    local IFACE="${WAN_IF:-ue0}"
    echo ">> Monitorando DNAT: conexoes TCP na porta 80 de $IFACE - Ctrl+C para parar..."
    tcpdump -ni "$IFACE" -l tcp port 80
}

# Captura trafego ICMP (ping) na LAN para verificar bloqueio
tcpdump_icmp() {
    local IFACE="${LAN_IF:-ue1}"
    echo ">> Monitorando ICMP (ping) em $IFACE - Ctrl+C para parar..."
    tcpdump -ni "$IFACE" -l icmp
}

# Captura e grava em arquivo (para apresentar como evidencia)
# Uso: tcpdump_gravar wan nome_arquivo.pcap
tcpdump_gravar() {
    local IFACE="${1:-$WAN_IF}"
    local ARQ="${2:-captura_$(date +%Y%m%d_%H%M%S).pcap}"
    echo ">> Gravando captura em $ARQ (Ctrl+C para parar e salvar)..."
    tcpdump -ni "$IFACE" -w "$ARQ"
    echo "  [OK] Arquivo salvo: $ARQ"
}


# ==============================================================================
# 6. COMANDOS DE VERIFICAÇÃO RÁPIDA PARA A APRESENTAÇÃO
# ==============================================================================

# Exibe o resumo completo de regras PF (o que o professor vai querer ver)
alias apresentar_pf="echo '=== REGRAS DO PACKET FILTER ===' && pfctl -sr && echo '' && echo '=== TRADUCAO NAT/DNAT ===' && pfctl -sn && echo '' && echo '=== ESTADOS ATIVOS ===' && pfctl -ss | head -20"

# Exibe o resumo completo do DHCP (leases + log recente)
alias apresentar_dhcp="echo '=== CONFIGURACAO DHCP ===' && cat $DHCP_CONF && echo '' && echo '=== LEASES ATIVAS ===' && grep -E '^lease|hardware ethernet|binding state' $DHCP_LEASES && echo '' && echo '=== LOG RECENTE ===' && tail -15 $DHCP_LOG"

# Teste de conectividade manual rapido (sem script)
ping_dns() {
    echo ">> Ping no DNS $DNS_SERVER (testa rota WAN)..."
    ping -c 3 "$DNS_SERVER"
}

echo "[OK] Aliases do roteador BSD carregados!"
echo "     Use 'status' para ver o estado geral do gateway."
