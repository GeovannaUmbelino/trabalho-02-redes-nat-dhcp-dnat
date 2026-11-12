# 20 - DNAT (traducao): WAN:80 -> cliente da LAN:8080
# (o pf exige regras de traducao ANTES das regras de filtro)
rdr on $wan_if inet proto tcp from any to ($wan_if) port $dnat_wan_port -> $dnat_ip port $dnat_port
