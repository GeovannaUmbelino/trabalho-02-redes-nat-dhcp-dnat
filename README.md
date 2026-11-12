# Trabalho 02 – Gateway FreeBSD (NAT + DHCP + DNAT + Firewall)
Fundamentos de Redes de Computadores – UnB Gama – Prof. Tiago Alves

Roteador/gateway em **FreeBSD** (instalado direto no hardware, sem virtualização) que entrega uma LAN privada `10.10.0.0/16` atrás de um IP da rede de acesso `192.168.X.0/24`.

```
 Rede do lab 192.168.X.0/24                       LAN privada 10.10.0.0/16
 (gateway 192.168.X.1, DNS)                       (criada por este trabalho)
        │                                                   │
        └──── [WAN: ue0] ── FREEBSD (pf + dhcpd) ── [LAN: ue1] ──── switch ──── clientes
                             NAT · DHCP · DNAT · firewall            (10.10.0.1 é o gateway)
```

## O que o sistema faz
| Requisito do enunciado | Onde está | Teste |
|---|---|---|
| WAN com IP da rede de acesso, LAN /16 privada | `scripts/10-network.sh` | `tests/router/01` |
| NAT LAN → WAN | `templates/pf/10-nat.conf.tpl` | `tests/router/02` |
| Isolamento de segmento | `templates/pf/30-isolamento.conf.tpl` | `tests/router/03` + `client/wan-client.sh` |
| DHCP (gateway, DNS, IP fixo p/ uma máquina, leases em log) | `scripts/30-dhcp.sh` | `tests/router/04` |
| DNAT WAN:80 → LAN:8080 | `templates/pf/20-rdr` e `40-dnat-pass` | `tests/router/05` + `client/wan-client.sh` |
| Firewall: sem ping para fora | `templates/pf/50-icmp.conf.tpl` | `tests/router/06` + `client/lan-client.sh` |

## Estrutura
```
config/gateway.conf     ← ÚNICO arquivo que você edita
lib/common.sh           funções compartilhadas (log, render de templates, pf_reload)
templates/              modelos dos arquivos de sistema (dhcpd.conf, pf/*)
scripts/                módulos: 10-network 20-nat 30-dhcp 40-dnat 50-firewall + setup/teardown
tests/router/           testes executados no roteador
tests/client/           testes executados em clientes (LAN e WAN)
docs/                   DOCUMENTACAO.md (explicação completa) e DIVISAO.md (equipe)
```

---
# PREPARAÇÃO (fazer ANTES do dia do teste, com internet)
1. Instalar o FreeBSD direto no notebook (`bsdinstall`): partição livre/dual boot **ou** pendrive/SSD USB como destino. Cuidado para escolher o disco/partição certo.
2. Com internet, instalar o servidor DHCP (não vem no sistema base):
   ```sh
   pkg install -y isc-dhcp44-server
   ```
3. Plugar os dois adaptadores de rede e conferir que aparecem: `ifconfig -l` (esperado `ue0 ue1`, ou `re0`, `em0`...).
4. Copiar este projeto para o notebook e extrair: `tar xf trabalho02-gateway-freebsd.zip -C /root`
5. Anotar o **MAC** do cliente que receberá IP fixo.
6. Fazer um **ensaio completo** (passos abaixo) pelo menos uma vez.

# PASSO A PASSO PARA O DIA DO TESTE

### 1. Montar a topologia
- Cabo da **WAN** na rede do laboratório (a que tem gateway `192.168.X.1`).
- Cabo da **LAN** no switch (ou direto no cliente).

### 2. Descobrir os nomes das interfaces
```sh
ifconfig -l                                   # lista (ex.: ue0 ue1 lo0)
dmesg | grep -E "^(ue|re|em|igc)[0-9]"        # confirma os adaptadores
```

### 3. Configurar
```sh
cd /root/trabalho02-gateway
ee config/gateway.conf        # (ou vi)
```
Ajuste: `WAN_IF`, `LAN_IF`, `WAN_MODE` (`dhcp` ou `static` + `WAN_IP/WAN_MASK/WAN_GW`), `DNS_SERVER` (164.41.101.4, 164.41.101.11 ou 192.168.X.1), `STATIC_HOST_MAC` e, se quiser, `STATIC_HOST_IP`/`DNAT_TARGET_IP`.

### 4. Aplicar tudo (como root)
```sh
sh scripts/setup.sh
```
Um módulo isolado: `sh scripts/setup.sh 30-dhcp`.

### 5. Validar no roteador
```sh
sh tests/run-all.sh
```
Todos devem aparecer `[ OK ]`. (O DHCP só mostra leases depois que um cliente pedir IP.)

### 6. Cliente da LAN (DHCP + NAT + ICMP)
1. Conecte o cliente à LAN e peça IP (`dhclient <interface>` no Linux/BSD; Windows: "obter IP automaticamente").
2. Deve receber `10.10.x.x`, gateway `10.10.0.1` e o DNS escolhido. A máquina com o MAC reservado recebe **sempre** `STATIC_HOST_IP`.
3. No cliente: `sh tests/client/lan-client.sh` → gateway responde, DNS responde (NAT), **ping para fora falha** (regra ICMP).
4. No roteador: `pfctl -ss | grep '('` mostra os estados **traduzidos** (prova do NAT).

### 7. Leases do DHCP (como mostrar ao professor)
```sh
cat /var/db/dhcpd/dhcpd.leases           # leases ativos
tail -20 /var/log/dhcpd.log              # DISCOVER / OFFER / REQUEST / ACK
tail -f /var/log/dhcpd.log               # acompanhar ao vivo
```

### 8. DNAT (porta 80 da WAN → 8080 do cliente da LAN)
1. No cliente da LAN com `STATIC_HOST_IP` (servidor TCP):
   ```sh
   while true; do nc -l 8080; done
   ```
2. Em **outro equipamento da WAN** (cliente TCP), apontando para o **IP da WAN do roteador** (`ifconfig <WAN_IF>`):
   ```sh
   telnet <IP_WAN_DO_ROTEADOR> 80        # ou: nc <IP_WAN_DO_ROTEADOR> 80
   ```
   Digite algo: o texto aparece no servidor `nc` da LAN.
3. No roteador: `pfctl -ss | grep 8080`.

### 9. Isolamento de segmento
No host da WAN, adicione rota para a LAN via roteador (para o teste ser válido):
```sh
# Linux:   sudo ip route add 10.10.0.0/16 via <IP_WAN_DO_ROTEADOR>
# FreeBSD: route add 10.10.0.0/16 <IP_WAN_DO_ROTEADOR>
sh tests/client/wan-client.sh <IP_WAN_DO_ROTEADOR> <IP_CLIENTE_LAN>
```
Ping e TCP direto ao cliente da LAN devem **falhar**; só a porta do DNAT responde.

### 10. Desfazer (opcional)
```sh
sh scripts/teardown.sh
```

---
## Problemas comuns
| Sintoma | Causa provável / solução |
|---|---|
| `interface 'ue0' não existe` | Nome errado: veja `ifconfig -l` e ajuste `WAN_IF`/`LAN_IF`. |
| `isc-dhcp44-server` não instala | Sem internet na WAN. Instale em casa antes (Preparação, passo 2). |
| Cliente não recebe IP | `service isc-dhcpd status`; `tail /var/log/dhcpd.log`; cabo/switch na interface certa (`LAN_IF`). |
| Sem internet no cliente LAN | `sysctl net.inet.ip.forwarding` deve ser 1; `pfctl -sn` deve mostrar `nat on`; `route -n get default` no roteador. |
| DNAT não conecta | `nc -l 8080` precisa estar rodando (fecha após cada conexão: use o `while`); confira `pfctl -sn \| grep rdr`. |
| `pf.conf inválido` | O setup não aplica nada se a validação falhar; leia a mensagem do `pfctl`. |
| Ping para fora falha na validação de NAT | Esperado: o ping é bloqueado de propósito. Valide NAT com DNS/TCP. |

## Comandos úteis (pf)
`pfctl -sr` regras de filtro · `pfctl -sn` NAT/rdr · `pfctl -ss` estados · `pfctl -si` status · `pfctl -nf /etc/pf.conf` validar · `tcpdump -ni <if>` capturar
