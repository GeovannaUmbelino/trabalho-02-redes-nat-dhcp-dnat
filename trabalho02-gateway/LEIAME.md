# Trabalho 02 - Gateway FreeBSD (NAT + DHCP + DNAT + firewall ICMP)  -  guia rapido

Os scripts DESCOBREM SOZINHOS: placa WAN, placa LAN, modo da WAN (DHCP), DNS e o MAC do cliente (IP fixo).
Voce nao precisa editar config.sh (so em caso especial, veja o item 5).

## 0. Levar o pacote para o notebook FreeBSD (root)
    gpart show
    mount -t msdosfs /dev/da1s1 /mnt        # use o nome que o gpart mostrou
    cp /mnt/trabalho02-gateway.zip /root/
    umount /mnt
    cd /root
    tar xf trabalho02-gateway.zip
    cd trabalho02-gateway

Requisito (com internet, antes do laboratorio):  `pkg install -y isc-dhcp44-server`

## 1. Cabos
- Cabo do laboratorio no adaptador USB. Cabo do cliente da LAN na porta RJ45 do notebook.
- NUNCA ligue a LAN na rede do laboratorio.

## 2. Rodar (um comando)
    sh scripts/ativar.sh

Ele faz, na ordem: detecta tudo -> rede (IPs + forwarding) -> DHCP -> firewall (NAT/DNAT/ICMP) -> reserva do IP fixo -> testes.
Esperado no inicio: um bloco `--- detectado ---` com WAN, LAN, DNS e modo.
Na etapa da reserva ele mostra `aguardando o cliente da LAN pedir IP`: no cliente, peca IP
(Windows: `ipconfig /renew`; Linux: `sudo dhclient -v <placa>`). Ele pega o MAC sozinho, grava a reserva e pede
para o cliente renovar de novo: `ipconfig /release` e `ipconfig /renew`. Esperado: **10.10.0.100**.
No fim: `TODOS OS TESTES DO ROTEADOR PASSARAM`.

Pode rodar de novo quantas vezes quiser. `sh scripts/ativar.sh --sem-cliente` nao espera o cliente (reserve depois com `sh scripts/reserva.sh`).

## 3. TESTES
### Roteador
    sh testes/router/rodar-todos.sh
| Arquivo | O que verifica |
|---|---|
| t01-conectividade.sh | IPs, cabos, forwarding, rota default, gateway e DNS |
| t02-nat.sh | regra de NAT e estados traduzidos `IP_WAN (IP_LAN) -> destino` |
| t03-isolamento.sh | bloqueio de entrada pela WAN e segmentos separados |
| t04-dhcp.sh | dhcpd, reserva por MAC, leases e log |
| t05-dnat.sh | regra rdr WAN:80 -> 10.10.0.100:8080 e pass da 8080 |
| t06-icmp.sh | bloqueio de ping da LAN para fora |

### Cliente da LAN
    sh testes/cliente/lan-client.sh           (Linux/BSD)
No Windows: `ping 10.10.0.1` (responde), `nslookup unb.br 164.41.101.4` (responde = NAT), `ping 164.41.101.4` (SEM resposta = bloqueado).
Depois, no roteador: `sh testes/router/t02-nat.sh` (mostra `IP_WAN (IP_LAN) -> 164.41.101.4:53`). Nao valide NAT com ping.

### DNAT (porta 80 da WAN -> 8080 do cliente)
1. No cliente da LAN (10.10.0.100): `sh testes/cliente/servidor-8080.sh` (ou `while true; do nc -l 8080; done`; Windows: `ncat -l 8080 -k`).
2. No roteador: `ifconfig` da WAN (placa que o script mostrou) para ver o IP da WAN.
3. Em OUTRO PC da rede do laboratorio: `telnet IP_DA_WAN 80` e digite `oi` -> aparece no cliente da LAN.
   Ou: `sh testes/cliente/wan-client.sh IP_DA_WAN 10.10.0.100`
4. No roteador: `pfctl -ss | grep 8080`.

### Isolamento (no PC da WAN; use a porta 22, nao a 8080)
    sudo ip route add 10.10.0.0/16 via IP_DA_WAN
    ping -c 2 10.10.0.100                -> sem resposta
    nc -z -w 3 10.10.0.100 22            -> falha

### Mostrar ao professor
    sh scripts/status.sh
    cat /var/db/dhcpd/dhcpd.leases
    tail -20 /var/log/dhcpd.log

## 4. Se algo falhar
| Sintoma | O que ver |
|---|---|
| `preciso de 2 placas de rede` | plugue o adaptador USB; `ifconfig -l` |
| `a WAN nao recebeu IP por DHCP` | cabo do lab na placa WAN; se o professor passou IP fixo, item 5 |
| LAN `no carrier` | cabo da LAN nao esta ligado no cliente/switch |
| dhcpd nao sobe | `dhcpd -t -cf /usr/local/etc/dhcpd.conf`; a placa da LAN precisa estar com 10.10.0.1 |
| Cliente sem IP | `service isc-dhcpd status` e `tail /var/log/dhcpd.log` |
| Cliente com IP, sem DNS | `sysctl net.inet.ip.forwarding` = 1 e `pfctl -sn` mostrando nat |
| pf recusou as duas sintaxes | mande a mensagem de erro que o `03-pf.sh` imprime |
| Deteccao errada | force no config.sh (item 5) e rode `sh scripts/ativar.sh` de novo |

## 5. Casos especiais (unica vez que se edita config.sh)
- **Professor passou IP fixo para a WAN:** `nano config.sh` e preencha `WAN_MODE="static"`, `WAN_IP="..."`, `WAN_GW="..."` (numeros reais, sem letras).
- **Forcar placas:** `WAN_IF="ue0"` e `LAN_IF="re0"`. **Forcar DNS:** `DNS_SERVER="164.41.101.11"`.
- **Forcar MAC:** `sh scripts/reserva.sh aa:bb:cc:dd:ee:ff`.

Desfazer tudo: `sh scripts/desfazer.sh` (restaura os originais; nao mexe na WAN).

## Limitacoes conhecidas
- Apenas IPv4; um unico IP de WAN compartilhado (NAT muitos-para-um).
- O bloqueio de ICMP cobre echo-request (ping); outros tipos nao.
- Entrada pela WAN negada, exceto DNAT, DHCP e ping ao roteador.
- A porta 8080 do cliente fica acessivel a quem na WAN a alcanca diretamente (regra pass do DNAT).
- O servidor DHCP e um pacote (isc-dhcp44-server), que exige internet para instalar.
- IP fixo da WAN (se o lab nao tiver DHCP) nao e detectavel: precisa informar em config.sh.
- Requer hardware real com duas interfaces de rede (virtualizacao nao e admitida).
