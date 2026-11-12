# 10 - NAT (traducao): tudo que sai da LAN pela WAN usa o IP da WAN.
# Sintaxe "nat on" funciona no FreeBSD 13, 14 e 15.
nat on $wan_if inet from $lan_net to any -> ($wan_if)
