# 00 - macros e opcoes globais (usadas pelos demais fragmentos)
wan_if        = "@WAN_IF@"
lan_if        = "@LAN_IF@"
lan_net       = "@LAN_NET@"
dnat_ip       = "@DNAT_TARGET_IP@"
dnat_wan_port = "@DNAT_WAN_PORT@"
dnat_port     = "@DNAT_TARGET_PORT@"

set skip on lo0
set block-policy drop
