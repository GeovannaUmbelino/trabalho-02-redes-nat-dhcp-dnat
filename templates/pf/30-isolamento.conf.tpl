# 30 - Isolamento (filtro): por padrao tudo passa (a ultima regra que casa vence),
# mas nada NOVO entra pela WAN, exceto o que liberarmos abaixo/nos proximos fragmentos.
pass all
block in on $wan_if all
# respostas do servidor DHCP do laboratorio (se a WAN usa DHCP)
pass in on $wan_if inet proto udp from any port 67 to any port 68
# o proprio roteador pode ser "pingado" pela WAN (diagnostico)
pass in on $wan_if inet proto icmp to ($wan_if) icmp-type echoreq
