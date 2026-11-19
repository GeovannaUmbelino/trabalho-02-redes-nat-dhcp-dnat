wan_if    = "@WAN_IF@"
lan_if    = "@LAN_IF@"
lan_net   = "@LAN_NET@"
dnat_host = "@DNAT_TARGET_IP@"

set skip on lo0
set block-policy drop

# NAT: a LAN sai com o IP da WAN
nat on $wan_if inet from $lan_net to any -> ($wan_if)

# DNAT: WAN porta @DNAT_PUBLIC_PORT@ -> cliente da LAN porta @DNAT_TARGET_PORT@
rdr on $wan_if inet proto tcp from any to ($wan_if) port @DNAT_PUBLIC_PORT@ -> $dnat_host port @DNAT_TARGET_PORT@

# Politica: tudo passa, mas nada novo entra pela WAN
pass all
block in on $wan_if all
pass in on $wan_if inet proto udp from any port 67 to any port 68
pass in on $wan_if inet proto icmp from any to ($wan_if) icmp-type echoreq
pass in on $wan_if inet proto tcp to $dnat_host port @DNAT_TARGET_PORT@

# Sem ping da LAN para fora (ping ao gateway da LAN continua funcionando)
block in quick on $lan_if inet proto icmp from $lan_net to ! $lan_net icmp-type echoreq
