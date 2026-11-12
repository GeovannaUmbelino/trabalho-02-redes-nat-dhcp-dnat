# 40 - Libera o trafego do DNAT. Depois do rdr o pf filtra com o destino JA traduzido.
pass in on $wan_if inet proto tcp from any to $dnat_ip port $dnat_port
