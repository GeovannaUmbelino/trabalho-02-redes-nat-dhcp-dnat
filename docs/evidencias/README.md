# Evidências de funcionamento – Trabalho 02 (NAT + DHCP + DNAT)

Fundamentos de Redes de Computadores – UnB Gama – Prof. Tiago Alves

Este documento reúne as **provas de que cada requisito do enunciado funciona**: saídas de comandos no roteador FreeBSD, saídas nos clientes e prints. Cada evidência traz o objetivo, o comando, o que procurar na saída e o espaço para colar o resultado real.

> **Regra do grupo:** as saídas abaixo devem vir do **ensaio em hardware real**. Os blocos marcados como *exemplo* mostram só o formato esperado; substitua pelo que o seu roteador realmente imprimiu. Não edite as saídas coletadas.

---

## 0. Identificação do ensaio

| Item | Valor |
|---|---|
| Data / hora | `<PREENCHER>` |
| Integrantes | `<PREENCHER>` |
| Versão do FreeBSD (`freebsd-version`) | `<PREENCHER>` |
| Hardware (notebook / adaptadores USB) | `<PREENCHER>` |
| Interface WAN (`WAN_IF`) e IP | `<PREENCHER>` (ex.: `ue0` – `192.168.X.__`) |
| Interface LAN (`LAN_IF`) e IP | `<PREENCHER>` (ex.: `ue1` – `10.10.0.1/16`) |
| Servidor DNS usado | `<PREENCHER>` (164.41.101.4 / 164.41.101.11 / 192.168.X.1) |
| Cliente LAN com IP fixo (nome / MAC / IP) | `<PREENCHER>` |
| Cliente WAN usado no teste de DNAT (IP) | `<PREENCHER>` |

### Convenção de arquivos

```
docs/evidencias/
├── README.md            ← este documento
├── saidas/              ← saídas de texto (preferidas: copiáveis e verificáveis)
│   └── NN-descricao.txt
└── img/                 ← prints, quando a saída de texto não bastar
    └── NN-descricao.png
```

### Como coletar uma saída de texto

Rode no roteador, a partir da raiz do projeto, para gravar data, comando e resultado juntos:

```sh
mkdir -p docs/evidencias/saidas docs/evidencias/img

# modelo: { date; echo '$ COMANDO'; COMANDO; } 2>&1 | tee docs/evidencias/saidas/NN-nome.txt
{ date; echo '$ pfctl -sn'; pfctl -sn; } 2>&1 | tee docs/evidencias/saidas/01-pfctl-sn.txt
```

---

## 1. Ambiente e rede do roteador

**Objetivo:** provar que o FreeBSD está roteando e que as duas interfaces têm os IPs esperados.
**Onde:** roteador.

```sh
{ date; freebsd-version; ifconfig -a; sysctl net.inet.ip.forwarding; netstat -rn -f inet; } 2>&1 | tee docs/evidencias/saidas/00-ambiente.txt
```

**O que procurar**
- WAN com IP da rede `192.168.X.0/24`; LAN com `10.10.0.1/16`.
- `net.inet.ip.forwarding: 1`.
- Rota `default` apontando para `192.168.X.1`.

**Saída obtida:**

```
<COLAR AQUI>
```

**Status:** [ ] coletada  [ ] confere com o esperado

---

## 2. Regras de NAT e DNAT carregadas (`pfctl -sn`)

**Objetivo:** mostrar que as regras `nat` (LAN → WAN) e `rdr` (WAN:80 → LAN:8080) estão ativas no `pf`.
**Onde:** roteador.

```sh
{ date; echo '$ pfctl -sn'; pfctl -sn; } 2>&1 | tee docs/evidencias/saidas/01-pfctl-sn.txt
```

**O que procurar**
- Uma linha `nat on <WAN_IF> ... from 10.10.0.0/16 to any -> (<WAN_IF>)`.
- Uma linha `rdr on <WAN_IF> ... port 80 -> 10.10.0.100 port 8080`.

**Saída esperada (exemplo; o formato pode variar entre versões do FreeBSD):**

```
nat on ue0 inet from 10.10.0.0/16 to any -> (ue0) round-robin
rdr on ue0 inet proto tcp from any to (ue0) port = http -> 10.10.0.100 port 8080
```

**Saída obtida:**

```
<COLAR AQUI>
```

**Status:** [ ] coletada  [ ] confere com o esperado

---

## 3. Estados e tradução de endereço (`pfctl -ss`)

**Objetivo:** provar que o NAT **traduz** de fato: o IP privado da LAN aparece entre parênteses e o IP da WAN é o que sai para a rede do laboratório.
**Onde:** roteador, **enquanto** um cliente da LAN gera tráfego (por exemplo, consulta DNS ou `nc` para um host externo).

No cliente LAN, gere tráfego:

```sh
# consulta DNS (usa o NAT; não depende de ping)
host www.unb.br <DNS_SERVER>
```

No roteador, logo em seguida:

```sh
{ date; echo '$ pfctl -ss'; pfctl -ss; echo; echo '$ pfctl -ss | grep "("'; pfctl -ss | grep '('; } 2>&1 | tee docs/evidencias/saidas/02-pfctl-ss-nat.txt
```

**O que procurar**
- Linhas no formato `IP_WAN:porta (IP_LAN:porta) -> destino:porta`. O endereço entre parênteses é o original da LAN.
- Prova de que a origem vista na rede externa é o IP do roteador, não o `10.10.x.x`.

**Saída esperada (exemplo):**

```
all udp 192.168.X.50:51234 (10.10.1.10:51234) -> 164.41.101.4:53       MULTIPLE:SINGLE
```

**Saída obtida:**

```
<COLAR AQUI>
```

**Prova complementar (opcional, mais forte):** capture no lado WAN e mostre que a origem é o IP da WAN.

```sh
tcpdump -ni <WAN_IF> host <DNS_SERVER> and udp port 53
```

**Status:** [ ] coletada  [ ] confere com o esperado

---

## 4. Concessões DHCP – arquivo de leases (`dhcpd.leases`)

**Objetivo:** mostrar que o servidor DHCP entregou endereços aos clientes da LAN.
**Onde:** roteador, **depois** de pelo menos um cliente pedir IP.

Peça IP no cliente (`dhclient <interface>` em Linux/BSD, ou "obter IP automaticamente" no Windows) e então:

```sh
{ date; echo '$ cat /var/db/dhcpd/dhcpd.leases'; cat /var/db/dhcpd/dhcpd.leases; } 2>&1 | tee docs/evidencias/saidas/03-dhcpd-leases.txt
```

**O que procurar**
- Blocos `lease <IP> { ... }` com `hardware ethernet <MAC do cliente>`.
- IPs do pool dinâmico (`10.10.1.x`) para clientes comuns.
- `binding state active`.

**Saída esperada (exemplo):**

```
lease 10.10.1.1 {
  starts 1 2026/11/16 15:00:00;
  ends 1 2026/11/16 15:10:00;
  binding state active;
  hardware ethernet aa:bb:cc:dd:ee:01;
  client-hostname "cliente-lan";
}
```

**Saída obtida:**

```
<COLAR AQUI>
```

**Status:** [ ] coletada  [ ] confere com o esperado

---

## 5. Log do DHCP (`dhcpd.log`)

**Objetivo:** mostrar o ciclo completo **DISCOVER → OFFER → REQUEST → ACK** registrado em log, como pede o enunciado ("conferir as *leases* em arquivos de *log*").
**Onde:** roteador.

```sh
{ date; echo '$ tail -30 /var/log/dhcpd.log'; tail -30 /var/log/dhcpd.log; } 2>&1 | tee docs/evidencias/saidas/04-dhcpd-log.txt
```

Para acompanhar ao vivo enquanto o cliente pede IP: `tail -f /var/log/dhcpd.log`.

**O que procurar:** as quatro mensagens, na ordem, para o MAC do cliente.

**Saída esperada (exemplo):**

```
dhcpd[1234]: DHCPDISCOVER from aa:bb:cc:dd:ee:01 via ue1
dhcpd[1234]: DHCPOFFER on 10.10.1.1 to aa:bb:cc:dd:ee:01 via ue1
dhcpd[1234]: DHCPREQUEST for 10.10.1.1 (10.10.0.1) from aa:bb:cc:dd:ee:01 via ue1
dhcpd[1234]: DHCPACK on 10.10.1.1 to aa:bb:cc:dd:ee:01 via ue1
```

**Saída obtida:**

```
<COLAR AQUI>
```

**Status:** [ ] coletada  [ ] confere com o esperado

---

## 6. Reserva de IP fixo por MAC

**Objetivo:** provar que a máquina de teste recebe **sempre** o mesmo IP (`STATIC_HOST_IP`).
**Onde:** cliente LAN reservado + roteador.

1. No cliente reservado, solte e renove a concessão (ou reinicie a interface) **duas vezes** e anote o IP recebido a cada vez.
2. No roteador, filtre o log pelo MAC:

```sh
{ date; grep -i '<MAC_DO_CLIENTE_RESERVADO>' /var/log/dhcpd.log | tail -10; } 2>&1 | tee docs/evidencias/saidas/05-reserva-ip-fixo.txt
```

**O que procurar:** o mesmo IP (`10.10.0.100`) nos dois ciclos, fora do pool dinâmico.

| Tentativa | IP recebido | Hora |
|---|---|---|
| 1 | `<PREENCHER>` | `<PREENCHER>` |
| 2 | `<PREENCHER>` | `<PREENCHER>` |

**Saída obtida:**

```
<COLAR AQUI>
```

**Status:** [ ] coletada  [ ] mesmo IP nas duas tentativas

---

## 7. Teste de DNAT (WAN:80 → cliente LAN:8080)

**Objetivo:** provar que uma conexão TCP à porta 80 do **IP WAN do roteador**, vinda de outro equipamento da WAN, chega ao servidor TCP na porta 8080 do cliente da LAN.

Há três pontos de observação. Registre os três.

### 7.1 Servidor TCP no cliente LAN (`10.10.0.100`)

```sh
while true; do nc -l 8080; done
```

### 7.2 Cliente TCP em outro equipamento da WAN

```sh
telnet <IP_WAN_DO_ROTEADOR> 80
# alternativa: nc <IP_WAN_DO_ROTEADOR> 80
```

Digite uma frase de teste (por exemplo `teste dnat grupo X`) e dê Enter.

### 7.3 Estado no roteador (durante a conexão)

```sh
{ date; echo '$ pfctl -sn | grep rdr'; pfctl -sn | grep rdr; echo; echo '$ pfctl -ss | grep 8080'; pfctl -ss | grep 8080; } 2>&1 | tee docs/evidencias/saidas/06-dnat-roteador.txt
```

**O que procurar**
- No cliente LAN, o texto digitado na WAN **aparece** no terminal do `nc -l 8080`.
- No roteador, um estado `ESTABLISHED` com `(10.10.0.100:8080)` ligado ao cliente WAN.

**Estado esperado no roteador (exemplo):**

```
all tcp 192.168.X.50:80 (10.10.0.100:8080) <- 192.168.X.77:49152       ESTABLISHED:ESTABLISHED
```

**Saída obtida – roteador:**

```
<COLAR AQUI>
```

**Saída / print – terminal do cliente WAN (telnet/nc):**

![telnet no cliente WAN](img/06-dnat-cliente-wan.png)

**Saída / print – terminal do servidor `nc -l 8080` na LAN:**

![nc servidor na LAN](img/06-dnat-servidor-lan.png)

**Status:** [ ] roteador coletado  [ ] print WAN  [ ] print LAN  [ ] texto chegou ao servidor

---

## 8. Isolamento de segmento

**Objetivo:** provar que um host da WAN **não** alcança diretamente os IPs da LAN, e que só a porta do DNAT responde.
**Onde:** host da WAN (com rota estática para a LAN via roteador, para o teste ser válido).

```sh
# Linux:   sudo ip route add 10.10.0.0/16 via <IP_WAN_DO_ROTEADOR>
# FreeBSD: route add 10.10.0.0/16 <IP_WAN_DO_ROTEADOR>
sh tests/client/wan-client.sh <IP_WAN_DO_ROTEADOR> <IP_CLIENTE_LAN> 2>&1 | tee docs/evidencias/saidas/07-isolamento-wan-client.txt
```

**O que procurar:** ping e TCP direto ao `10.10.0.100` **falham**; a porta 80 do roteador (DNAT) **responde**.

**Saída obtida:**

```
<COLAR AQUI>
```

**Status:** [ ] coletada  [ ] confere com o esperado

---

## 9. Conectividade do cliente LAN

**Objetivo:** provar que o cliente da LAN recebeu a configuração e alcança o gateway e a rede externa.
**Onde:** cliente LAN.

```sh
sh tests/client/lan-client.sh 2>&1 | tee docs/evidencias/saidas/08-lan-client.txt
```

Registre também a configuração recebida (`ifconfig` / `ip a` e `cat /etc/resolv.conf`) com o IP `10.10.x.x`, o gateway `10.10.0.1` e o DNS escolhido.

> Se a regra de bloqueio de ICMP estiver ativa, o ping para fora **falha de propósito**; valide a saída para a rede externa com DNS ou TCP (ex.: `host www.unb.br <DNS_SERVER>`).

**Saída obtida:**

```
<COLAR AQUI>
```

**Status:** [ ] coletada  [ ] confere com o esperado

---

## 10. Suíte de testes automatizada no roteador

**Objetivo:** resumo geral: todos os testes do roteador em `[ OK ]`.
**Onde:** roteador, **após** os testes com clientes (assim o NAT e o DHCP já têm estados e leases para mostrar).

```sh
sh tests/run-all.sh 2>&1 | tee docs/evidencias/saidas/09-run-all.txt
```

**Saída obtida:**

```
<COLAR AQUI>
```

**Status:** [ ] coletada  [ ] todos `[ OK ]`

---

## Resumo das evidências

| # | Requisito do enunciado | Evidência | Coletada | Confere |
|---|---|---|:---:|:---:|
| 1 | WAN com IP da rede de acesso, LAN /16 | `00-ambiente.txt` | [ ] | [ ] |
| 2 | Serviço de NAT (regras carregadas) | `01-pfctl-sn.txt` | [ ] | [ ] |
| 3 | Tradução de endereço (NAT) | `02-pfctl-ss-nat.txt` | [ ] | [ ] |
| 4 | DHCP: leases | `03-dhcpd-leases.txt` | [ ] | [ ] |
| 5 | DHCP: leases em log | `04-dhcpd-log.txt` | [ ] | [ ] |
| 6 | DHCP: IP fixo por MAC | `05-reserva-ip-fixo.txt` | [ ] | [ ] |
| 7 | DNAT 80 → 8080 com nc/telnet | `06-dnat-roteador.txt` + prints | [ ] | [ ] |
| 8 | Isolamento de segmento | `07-isolamento-wan-client.txt` | [ ] | [ ] |
| 9 | Conectividade do cliente LAN | `08-lan-client.txt` | [ ] | [ ] |
| 10 | Suíte de testes do roteador | `09-run-all.txt` | [ ] | [ ] |

## Observações e problemas do ensaio

Anote aqui qualquer diferença entre o esperado e o obtido, e como foi resolvida. Isso alimenta a seção "Problemas que enfrentamos" da `DOCUMENTACAO.md`.

- `<PREENCHER>`
