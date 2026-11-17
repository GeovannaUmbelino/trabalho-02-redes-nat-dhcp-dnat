# Trabalho 02: Camada de Rede (NAT + DHCP + DNAT)

Fundamentos de Redes de Computadores – UnB Gama – Prof. Tiago Alves


---
## 1. Visão geral
Foi construído um **roteador/gateway** em FreeBSD. A interface **WAN** assume um IP da rede de acesso do laboratório (`192.168.X.0/24`) e a interface **LAN** serve a rede privada `10.10.0.0/16`. Sobre ele rodam: NAT, servidor DHCP, DNAT para um equipamento da LAN e uma regra de firewall contra ping para fora.

```
 Lab 192.168.X.0/24 ── [WAN] FREEBSD [LAN] ── switch ── clientes 10.10.0.0/16
```

### Mapa do enunciado (exigência → onde foi feita)
| Exigência do PDF | Implementação | Validação |
|---|---|---|
| WAN com IP da rede de acesso; LAN /16 de faixa reservada | `10-network.sh` + `config/gateway.conf` | teste 01 |
| Serviço de NAT | `pf/10-nat.conf` (`nat on`) | teste 02 |
| Lista de testes: conectividade, tradução, isolamento | `tests/` (seção 7) | testes 01, 02, 03 |
| DHCP com DNS 192.168.X.1 / 164.41.101.4 / .11 | `30-dhcp.sh` + `dhcpd.conf` | teste 04 |
| IP fixo para uma máquina de testes | bloco `host` do `dhcpd.conf` | teste 04 |
| Conferir leases em arquivos de log | `/var/db/dhcpd/dhcpd.leases` e `/var/log/dhcpd.log` | teste 04 |
| DNAT porta 80 (WAN) → 8080 (cliente LAN) | `pf/20-rdr.conf` + `pf/40-dnat-pass.conf` | teste 05 + `wan-client.sh` |
| Servidor/cliente TCP com netcat/telnet | procedimento no README, passo 8 | `wan-client.sh` |
| Firewall: sem ping para fora do segmento | `pf/50-icmp.conf` | teste 06 + `lan-client.sh` |
| Documentação dos procedimentos | `README.md` + este documento | – |

---
## 2. Sistema operacional e por que FreeBSD
- **Sistema usado: FreeBSD**, instalado diretamente no hardware (o enunciado **proíbe ambiente virtualizado**).
- **Pontuação:** *BSD = 100% da nota; Linux = 90%; outros = 70%. FreeBSD é *BSD, então não há desconto.
- **Sem "gateway pronto":** o enunciado invalida derivações com pacotes de configuração rápida de gateway (pfSense, OPNsense etc.). Aqui o roteamento, o NAT e o firewall usam apenas o **sistema base** (`pf`, `sysctl`, `ifconfig`, `rc.conf`). O **único pacote** instalado é o servidor DHCP (`isc-dhcp44-server`), pacote comum do repositório oficial, que não configura gateway nenhum.
- **Por que FreeBSD:** suporte amplo a hardware (adaptadores USB-Ethernet e placas do notebook), boa documentação e o `pf` disponível no kernel.

## 3. Aplicações utilizadas e por quê
| Aplicação | Papel | Por que esta |
|---|---|---|
| **pf** (Packet Filter) | NAT (`nat`), DNAT (`rdr`), isolamento e bloqueio de ICMP | firewall com sintaxe legível; um só lugar para toda a política de rede |
| **ISC dhcpd** (`isc-dhcp44-server`) | Servidor DHCP da LAN | suporta reserva por MAC e registra concessões; o FreeBSD não traz servidor DHCP no base |
| **sysctl / `gateway_enable`** | Liga o encaminhamento de pacotes | sem isso o sistema não atua como roteador |
| **rc.conf / sysrc / service** | Configura IPs e serviços de forma persistente | método padrão do FreeBSD |
| **syslogd** | Grava log dedicado do DHCP | o syslog padrão descarta mensagens "info" do dhcpd |
| **nc (netcat) e telnet** | Servidor e cliente TCP para testar o DNAT | exigido pelo enunciado |
| **ping, host/drill, tcpdump, pfctl** | Diagnóstico e validação | ferramentas do sistema base |
| **POSIX sh** | Linguagem dos scripts | o `sh` do FreeBSD roda tudo sem instalar bash |

---
## 4. Decisões de projeto (e a razão de cada uma)
1. **Faixa `10.10.0.0/16`.** O enunciado pede sub-rede /16 de faixa reservada (RFC 1918). Está em `10.0.0.0/8` e não colide com `192.168.X.0/24` do laboratório.
2. **Um único arquivo de configuração (`config/gateway.conf`).** Evita IP/porta espalhados; mudar de laboratório (X, DNS) é editar um arquivo.
3. **Templates + `render`.** Os arquivos de sistema são modelos com `@VARIAVEL@`; o script substitui pelos valores. O `render` aborta se sobrar variável sem valor.
4. **pf modular com `include`.** Cada módulo gera um fragmento em `/etc/pf.d/NN-*.conf`; o `/etc/pf.conf` apenas os inclui em ordem. Cada pessoa mexe no seu fragmento sem conflito.
5. **Sintaxe clássica `nat on` / `rdr on`.** Funciona no FreeBSD 13, 14 e 15 (o 15 também aceita `nat-to`/`rdr-to`). Como o pf exige a ordem *opções → tradução → filtros*, a numeração dos fragmentos reflete isso (`00` opções, `10–20` nat/rdr, `30–50` filtros).
6. **Validar antes de aplicar.** `pf_reload` roda `pfctl -nf` num arquivo temporário; se houver erro, nada é aplicado (o enunciado anula arquivos de configuração com erro).
7. **Backup e teardown.** Antes de sobrescrever `rc.conf`, `pf.conf` ou `dhcpd.conf` guarda-se `*.pre-t2`; `teardown.sh` restaura.
8. **Bloquear o ping na entrada da LAN.** A regra é `in` na interface LAN, onde o endereço de origem ainda é o da LAN (antes do NAT). Usa `to ! $lan_net`, então o ping ao próprio gateway continua funcionando.
9. **Política "tudo passa, mas nada novo entra pela WAN".** Mantém a LAN funcional e cumpre o isolamento: entram apenas respostas a conexões iniciadas pela LAN (estado do pf) e a porta do DNAT.
10. **DNAT em duas regras.** `rdr` traduz o destino e uma regra `pass` posterior libera o destino já traduzido (o pf filtra depois da tradução).
11. **Log dedicado do DHCP.** `log-facility local7` + `/etc/syslog.d/dhcpd.conf` gravam em `/var/log/dhcpd.log`, atendendo "conferir leases em arquivos de log".
12. **Interfaces em variável.** Adaptadores USB mudam de nome (`ue0`, `ue1`...); basta ajustar `WAN_IF`/`LAN_IF`.

---
## 5. Explicação arquivo por arquivo

### Raiz
- **`README.md`** – preparação, passo a passo do dia do teste, problemas comuns.

### `config/`
- **`gateway.conf`** – interfaces, modo da WAN (`dhcp`/`static`/`keep`), rede LAN, faixa e DNS do DHCP, MAC/IP da máquina com IP fixo, portas do DNAT. Único arquivo que o usuário edita.

### `lib/`
- **`common.sh`** – `log`/`die`; `require_root`, `require_freebsd`, `require_iface`; `backup_once`/`restore_or_remove`; `render`; `pf_install` (instala um fragmento); `pf_reload` (monta `/etc/pf.conf`, valida, habilita o pf no `rc.conf` e carrega).

### `templates/`
- **`dhcpd.conf.tpl`** → `/usr/local/etc/dhcpd.conf`: DNS, gateway, faixa, reserva por MAC e destino do log.
- **`pf/00-macros.conf.tpl`** – macros (`wan_if`, `lan_if`, `lan_net`, dados do DNAT) e opções (`skip on lo0`, `block-policy drop`).
- **`pf/10-nat.conf.tpl`** – `nat on $wan_if ... -> ($wan_if)`: a LAN sai com o IP da WAN.
- **`pf/20-rdr.conf.tpl`** – `rdr on $wan_if ... port 80 -> cliente port 8080`.
- **`pf/30-isolamento.conf.tpl`** – `pass all`; `block in on $wan_if all`; exceções: respostas DHCP (UDP 67→68) e ping ao próprio roteador.
- **`pf/40-dnat-pass.conf.tpl`** – libera o tráfego já traduzido para o cliente da LAN.
- **`pf/50-icmp.conf.tpl`** – `block in quick` de ICMP echo-request da LAN para fora da LAN.

### `scripts/`
- **`10-network.sh`** – grava `ifconfig_<if>` no `rc.conf` (`sysrc`), reinicia a interface (`service netif restart`), configura a WAN conforme `WAN_MODE`, ativa `gateway_enable` e `net.inet.ip.forwarding`.
- **`20-nat.sh`** – instala fragmentos de NAT e isolamento e recarrega o pf.
- **`30-dhcp.sh`** – instala o pacote se faltar, gera `dhcpd.conf`, cria log e leases, habilita `dhcpd` só na interface da LAN.
- **`40-dnat.sh`** – instala `rdr` + `pass` do DNAT e recarrega o pf.
- **`50-firewall.sh`** – instala o bloqueio de ICMP e recarrega o pf.
- **`setup.sh`** – orquestra os módulos em ordem (ou apenas os citados).
- **`teardown.sh`** – remove fragmentos, restaura arquivos originais e desliga forwarding/DHCP.

### `tests/`
- **`lib.sh`** – `check` e `summary`.
- **`router/01..06`** – testes no roteador (seção 7). **`run-all.sh`** executa todos.
- **`client/lan-client.sh`** – em cliente da LAN: gateway responde, DNS responde via NAT, ping para fora falha.
- **`client/wan-client.sh`** – em host da WAN: DNAT funciona, LAN não é alcançável diretamente.

### `docs/`
- **`DOCUMENTACAO.md`** – este documento.

---
## 6. Como implementar (resumo)
1. Instalar FreeBSD no hardware; `pkg install isc-dhcp44-server` (com internet); identificar interfaces (`ifconfig -l`).
2. Editar `config/gateway.conf`.
3. Como root: `sh scripts/setup.sh`.
Fluxo: `10-network` (IPs + forwarding) → `20-nat` (pf: NAT + isolamento) → `30-dhcp` (dhcpd) → `40-dnat` (pf: rdr) → `50-firewall` (pf: ICMP). Detalhes e dia do teste no `README.md`.

## 7. Como validar (lista de testes)
| Teste | Local | O que verifica | Resultado esperado |
|---|---|---|---|
| 01 Conectividade | roteador | IP da LAN, IP da WAN, forwarding, rota default, gateway e DNS alcançáveis | todos OK |
| 02 Tradução (NAT) | roteador (+ tráfego do cliente) | regra `nat` ativa; estados mostram `IP_WAN (IP_LAN) -> destino` | traduções visíveis em `pfctl -ss` |
| 03 Isolamento | roteador + `wan-client.sh` | bloqueio padrão na WAN; host da WAN não alcança IPs da LAN | ping/TCP direto à LAN falham |
| 04 DHCP | roteador + cliente | dhcpd ativo, reserva configurada; leases e log | cliente recebe IP; reservado sempre o mesmo |
| 05 DNAT | roteador + `wan-client.sh` | regra `rdr`; conexão WAN:80 chega em LAN:8080 | `nc`/`telnet` na porta 80 da WAN fala com o servidor da LAN |
| 06 ICMP | roteador + `lan-client.sh` | ping da LAN para fora bloqueado | ping para fora falha; ping ao gateway funciona |

**Conferir leases:** `/var/db/dhcpd/dhcpd.leases` (concessões ativas) e `/var/log/dhcpd.log` (DISCOVER, OFFER, REQUEST, ACK).
**Atenção:** como o ping para fora é bloqueado de propósito, a validação do NAT deve usar DNS ou TCP, não ping.

## 8. Limitações 
- Apenas **IPv4** (sem IPv6).
- **Um único IP de WAN** compartilhado pela LAN (NAT muitos-para-um); conexões recebidas, além da porta do DNAT, exigem novas regras.
- O bloqueio de ICMP cobre **echo-request** (ping); outros tipos ICMP e traceroute por UDP não são bloqueados.
- Entrada pela WAN é **negada**, exceto DNAT e ping ao roteador; acesso remoto (SSH) pela WAN precisa de regra adicional.
- O **servidor DHCP é um pacote** (`isc-dhcp44-server`): exige internet para instalar (por isso é instalado antes) e o ISC encerrou o desenvolvimento do ISC DHCP em favor do Kea, embora ainda esteja nos pacotes do FreeBSD.
- DHCP **sem redundância**; faixa de 254 endereços (ajustável).
- O roteador **não fornece DNS**: repassa o servidor configurado nas ofertas DHCP.
- `teardown.sh` restaura o `rc.conf` ao estado anterior ao setup (alterações feitas depois nele são perdidas).
- Nomes de interface variam por adaptador; é preciso ajustar `config/gateway.conf` em cada máquina.
- Exige hardware real com **duas interfaces de rede** (virtualização não é admitida).
- Os scripts foram escritos para FreeBSD; em outro SO é preciso adaptá-los.

## 9. Problemas que enfrentamos e soluções adotadas

Durante a concepção, implementação e testes do gateway em FreeBSD, foram enfrentados e solucionados os seguintes desafios técnicos:

1. **Ordem estrita das regras no Packet Filter (PF):**
   - *Desafio:* O `pf` exige uma estrutura rígida no arquivo de regras: primeiro macros e opções globais, depois regras de tradução (`nat`/`rdr`) e por fim regras de filtragem (`block`/`pass`). Qualquer regra fora de ordem impede o carregamento do firewall.
   - *Solução:* Adotou-se uma arquitetura modular baseada em fragmentos numerados (`templates/pf/00-macros.conf.tpl` a `50-icmp.conf.tpl`). A função `pf_reload` em `lib/common.sh` concatena os fragmentos em ordem alfabética e valida previamente a sintaxe com `pfctl -nf /etc/pf.conf.new` antes de aplicar ao sistema.

2. **Descarte de logs do DHCP pelo syslogd padrão:**
   - *Desafio:* O servidor ISC dhcpd emite as mensagens de concessão (`DHCPDISCOVER`, `DHCPOFFER`, `DHCPREQUEST`, `DHCPACK`) na prioridade `info`. O `syslogd` padrão do FreeBSD descarta ou mistura essas mensagens no `/var/log/messages`, dificultando o acompanhamento exigido no enunciado.
   - *Solução:* Configurou-se a diretiva `log-facility local7;` no `dhcpd.conf` e criou-se a regra `/etc/syslog.d/dhcpd.conf` direcionando `local7.*` para `/var/log/dhcpd.log`, permitindo auditoria isolada e em tempo real via `tail -f`.

3. **Validação do NAT com bloqueio de ICMP ativo:**
   - *Desafio:* O requisito de firewall bloqueia o envio de pacotes ICMP *echo-request* da LAN para fora. Com isso, testes convencionais de conectividade e NAT baseados em `ping` falham por especificação de projeto.
   - *Solução:* A validação de tradução de endereços (NAT) foi estabelecida através de consultas DNS via UDP (`host unb.br 164.41.101.4`) e inspeção da tabela de estados do roteador com `pfctl -ss | grep '('`. Isso comprova o funcionamento pleno do NAT sem violar a regra de firewall.

4. **Persistência do servidor TCP nos testes de DNAT:**
   - *Desafio:* Ao testar o redirecionamento de portas WAN:80 → LAN:8080 com `nc -l 8080` no cliente da LAN, o processo padrão do `netcat` finaliza imediatamente após a primeira desconexão do cliente.
   - *Solução:* Padronizou-se o comando de escuta com um loop contínuo (`while true; do nc -l 8080; done`), viabilizando múltiplos testes de validação com `telnet` e `tests/client/wan-client.sh`.

5. **Identificação e suporte a adaptadores de rede USB:**
   - *Desafio:* Em notebooks com apenas uma interface de rede onboard, o uso de placas de rede USB resulta em nomes variáveis (`ue0`, `ue1`, `re0`, etc.) e necessidade de módulos de kernel específicos (`if_ure` para Realtek, `if_axge` para ASIX).
   - *Solução:* Centralizou-se a parametrização das interfaces no arquivo `config/gateway.conf` (`WAN_IF` e `LAN_IF`) e incluiu-se a identificação via `ifconfig -l` e instruções de carregamento de drivers no roteiro, evitando dependências fixas no código.


