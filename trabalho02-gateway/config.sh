# ============================================================
# config.sh - NORMALMENTE VOCE NAO PRECISA EDITAR NADA.
# Onde esta "auto", o script scripts/00-detectar.sh descobre sozinho.
# So mude um valor se quiser FORCAR (ex.: IP fixo da WAN passado pelo professor).
# Formato: NOME="valor"  (aspas retas, sem espacos nos valores)
# ============================================================

# Placas de rede: "auto" = descobre sozinho (WAN = a que tem a rota da internet/lab,
# LAN = a outra). Para forcar, ponha o nome, ex.: WAN_IF="ue0"
WAN_IF="auto"
LAN_IF="auto"

# Como a WAN pega IP:  auto | dhcp | static | keep
#   auto   = detecta (tenta DHCP; se o lab nao der IP, avisa para usar static)
#   static = IP fixo passado pelo professor: preencha WAN_IP e WAN_GW abaixo
#            (com NUMEROS REAIS, sem letras)
WAN_MODE="auto"
WAN_IP=""               # so se WAN_MODE="static"   ex.: 192.168.2.50
WAN_MASK="255.255.255.0"
WAN_GW=""               # so se WAN_MODE="static"   ex.: 192.168.2.1

# Rede LAN privada /16 (faixa RFC1918 10.0.0.0/8)
LAN_IP="10.10.0.1"
LAN_MASK="255.255.0.0"
LAN_NET="10.10.0.0/16"
LAN_NETADDR="10.10.0.0"
LAN_BROADCAST="10.10.255.255"

# Faixa do DHCP
DHCP_RANGE_START="10.10.1.1"
DHCP_RANGE_END="10.10.1.254"

# DNS entregue aos clientes: "auto" testa 164.41.101.4, 164.41.101.11 e o gateway
# da WAN (192.168.X.1) e usa o primeiro que responder.
DNS_SERVER="auto"

# Maquina que recebe SEMPRE o mesmo IP.
# "auto" = scripts/reserva.sh espera o cliente da LAN pedir IP e pega o MAC dele.
STATIC_HOST_NAME="maquina-teste"
STATIC_HOST_MAC="auto"
STATIC_HOST_IP="10.10.0.100"

# DNAT: porta publica da WAN -> cliente da LAN
DNAT_TARGET_IP="10.10.0.100"
DNAT_PUBLIC_PORT="80"
DNAT_TARGET_PORT="8080"
