# 50 - Firewall: impede ping (echo-request) da LAN para fora do segmento.
# "quick" = esta regra vence sempre. Ping ao proprio gateway continua funcionando.
block in quick on $lan_if inet proto icmp from $lan_net to ! $lan_net icmp-type echoreq
