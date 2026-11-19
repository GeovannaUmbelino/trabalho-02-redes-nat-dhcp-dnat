# README - Gateway FreeBSD (NAT + DHCP + DNAT + bloqueio de ping)

Trabalho 02 de Fundamentos de Redes de Computadores (UnB Gama, Prof. Tiago Alves).
Este README explica **onde ficam as configurações, para que servem, como são usadas** e traz o **passo a passo** para configurar e testar.

> **Novidade desta versão:** os scripts **descobrem sozinhos** as placas WAN e LAN, o modo da WAN, o DNS e o MAC do cliente.
> Você **não precisa mais editar o `config.sh`**. É só ligar os cabos, rodar `sh scripts/ativar.sh` e testar.

---

## 1. Os scripts já criam as configurações certinhas?

**Sim, esse é o objetivo do pacote `trabalho02-gateway.zip`.** Um comando (`sh scripts/ativar.sh`) detecta o ambiente, gera e instala todos os arquivos de configuração e roda os testes.

O que o pacote garante:
- **Valida antes de aplicar.** O `pf.conf` passa por `pfctl -nf` e o `dhcpd.conf` por `dhcpd -t`. Se houver erro, o script mostra o motivo e **não instala** a configuração quebrada.
- **Pode rodar de novo** quantas vezes quiser.
- **Faz backup** dos arquivos originais (`*.pre-t2`) antes de sobrescrever.
- **Tenta duas sintaxes de `pf`**: a clássica (`nat on` / `rdr on`) e a nova (`nat-to` / `rdr-to`).
- **Detecta o ambiente** (seção 4), em vez de você digitar os dados.

O que **não** dá para garantir:
- **Nada foi testado em um FreeBSD real.** A sintaxe dos scripts foi conferida e a lógica de detecção foi testada com comandos simulados, mas não em uma máquina de verdade. Por isso existem os testes (seção 8): eles dizem, item por item, se cada configuração ficou certa.
- Os scripts não resolvem problemas físicos: cabo solto, adaptador USB sem driver, pacote `isc-dhcp44-server` não instalado, WAN sem IP.
- Se o laboratório **não** der IP por DHCP e o professor passar um IP fixo, esse IP não dá para descobrir sozinho: aí você preenche 2 linhas no `config.sh` (seção 4.1).
- Se a detecção errar qualquer dado, a seção 4.2 mostra **como descobrir cada informação à mão**, a 4.3 como forçá-la e a 4.4 traz a configuração 100% manual.
- A seção 3.1 explica **o que cada script faz** e traz o **passo a passo manual equivalente** de cada um.

---

## 2. Visão geral da rede

```
 Rede do laboratório          NOTEBOOK FREEBSD (pf + dhcpd)             LAN privada
 192.168.2.0/24  --cabo-->  [ue0 = WAN]            [re0 = LAN]  --cabo-->  cliente(s)
 (gateway 192.168.2.1)       IP pego por DHCP       10.10.0.1/16            10.10.0.0/16
                                                                            cliente fixo: 10.10.0.100
```

| Item | Valor |
|---|---|
| WAN | adaptador USB (`ue0` no seu caso), IP recebido do laboratório (ex.: 192.168.2.119) |
| LAN | RJ45 do notebook (`re0`), `10.10.0.1`, máscara `255.255.0.0` (/16) |
| Faixa do DHCP | `10.10.1.1` a `10.10.1.254` |
| DNS entregue | `164.41.101.4` (ou `164.41.101.11` ou o gateway `192.168.X.1`, o que responder) |
| IP fixo (por MAC) | `10.10.0.100` |
| DNAT | porta 80 da WAN -> `10.10.0.100` porta 8080 |

**Regra importante:** nunca ligue a LAN na rede do laboratório (nem no mesmo switch). Dois servidores DHCP na mesma rede derrubam a rede.

---

## 3. O que tem dentro do pacote

```
trabalho02-gateway/
  config.sh                  <- valores "auto" (normalmente não se edita)
  config.auto                <- GERADO: o que foi detectado (não existe antes da 1ª execução)
  LEIAME.md                  <- guia rápido dentro do zip
  lib/common.sh              <- funções usadas pelos scripts
  templates/
    dhcpd.conf.tpl           <- modelo do DHCP
    pf.conf.tpl              <- modelo do firewall (sintaxe clássica)
    pf.conf.nat-to.tpl       <- modelo do firewall (sintaxe nova)
  scripts/
    ativar.sh                <- UM COMANDO: detecta, configura, reserva IP e testa
    00-detectar.sh           <- descobre placas, modo da WAN e DNS
    01-rede.sh               <- IPs, WAN, forwarding
    02-dhcp.sh               <- servidor DHCP + log
    03-pf.sh                 <- NAT, DNAT, firewall
    reserva.sh               <- reserva do IP fixo (automática ou com MAC informado)
    status.sh                <- mostra tudo (para o professor)
    desfazer.sh              <- desliga e restaura os originais
  testes/
    router/                  <- testes que rodam no notebook (t01 a t06 + rodar-todos.sh)
    cliente/                 <- testes que rodam nos clientes (LAN e WAN) + servidor da porta 8080
```

### Como funcionam os modelos (`templates/`)
Os arquivos `.tpl` têm marcações como `@LAN_IP@`. Os scripts trocam cada marcação pelo valor (detectado ou do `config.sh`) e gravam o arquivo final no sistema.

### 3.1 O que cada script faz (e o passo a passo à mão, se você não tiver o script)

Cada bloco abaixo diz **para que serve** o script, **o que ele faz em ordem**, **o que altera no sistema**, **como rodá-lo sozinho** e o **passo a passo manual equivalente**, para você seguir se o script não existir ou falhar. Os passos manuais usam `ue0` (WAN) e `re0` (LAN); troque pelos nomes que você descobriu (seção 4.2).

**Ordem normal:** `00-detectar` -> `01-rede` -> `02-dhcp` -> `03-pf` -> `reserva` -> testes. O `ativar.sh` chama todos nessa ordem.

#### `scripts/ativar.sh` (o comando principal)
**Para que serve:** faz tudo em um comando.

**O que faz, em ordem:**
1. Confere que você é root.
2. Roda o `00-detectar.sh` (descobre placas, modo da WAN e DNS).
3. Roda o `01-rede.sh`, o `02-dhcp.sh` e o `03-pf.sh`. Se um deles falhar, o `ativar.sh` para ali e mostra `[ERRO]`.
4. Se o MAC do cliente ainda não é conhecido (e você não passou `--sem-cliente`), roda o `reserva.sh`, que espera até 3 minutos o cliente da LAN pedir IP.
5. Roda os testes do roteador (`rodar-todos.sh`).

**O que altera:** tudo o que os scripts 01, 02, 03 e `reserva` alteram.

**Como rodar:**
```sh
sh scripts/ativar.sh                  # completo
sh scripts/ativar.sh --sem-cliente    # não espera o cliente (reserve depois)
```
**Esperado:** o bloco `--- detectado ---`, vários `[OK]` e, no fim, `TODOS OS TESTES DO ROTEADOR PASSARAM`.

**À mão:** descubra os dados (seção 4.2), siga os passos 1 a 6 da seção 4.4, faça a reserva do IP fixo (bloco do `reserva.sh` abaixo) e rode os testes da seção 8.

#### `scripts/00-detectar.sh` (descobre os dados sozinho)
**Para que serve:** descobrir placa WAN, placa LAN, modo da WAN e DNS, para você não digitar nada.

**O que faz, em ordem:**
1. Lista as placas Ethernet físicas (ignora `lo0`, `pflog0`, `wlan`, bridge e túneis).
2. Se achar menos de duas, tenta carregar drivers de adaptador USB (`if_ure`, `if_axge`, `if_cdce`...) e procura de novo. Se continuar com uma só, para com `[ERRO]`.
3. Escolhe a **LAN** (a placa que já tem IP `10.10.x.x` ou a outra) e a **WAN** (placa da rota padrão, ou a que tem IP e cabo, ou o adaptador USB).
4. Define o **modo da WAN**. Se for DHCP e a WAN estiver sem IP, roda `dhclient` por até 45 segundos. Se não vier IP, para e explica como usar IP fixo.
5. Testa o **DNS** (`164.41.101.4`, `164.41.101.11` e o gateway da WAN) e usa o primeiro que resolver `unb.br`.
6. Grava tudo em `config.auto` e mostra o bloco `--- detectado ---`.

**O que altera:** só o arquivo `config.auto` (e, se a WAN estiver sem IP, pede o IP por DHCP).

**Como rodar sozinho:** `sh scripts/00-detectar.sh`
**Esperado:** o bloco `--- detectado ---` e `[OK] deteccao concluida`.

**À mão:** seção 4.2 (itens A a D) para descobrir cada valor e seção 4.3 para forçá-lo no `config.sh`.

#### `scripts/01-rede.sh` (IPs e roteamento)
**Para que serve:** colocar o IP da LAN, preparar a WAN e **ligar o roteamento** entre as placas.

**O que faz, em ordem:**
1. Exige root, FreeBSD e que as duas placas existam.
2. Faz backup do `/etc/rc.conf` (`rc.conf.pre-t2`, só na primeira vez).
3. Grava no `rc.conf` o IP da LAN (`10.10.0.1`, máscara `255.255.0.0`) e aplica na hora. **Remove qualquer outro IP** que tenha ficado na placa da LAN (evita o erro de um IP antigo na `re0`).
4. Cuida da WAN conforme o modo: `dhcp` (garante DHCP no `rc.conf` e pede IP se não tiver), `static` (confere que IP e gateway são só números, grava no `rc.conf`, aplica o IP e a rota padrão) ou `keep` (não mexe).
5. Liga o roteamento: `gateway_enable="YES"` e `net.inet.ip.forwarding=1`.
6. Mostra um resumo e avisa se a WAN está sem IP, se a LAN está sem cabo (`no carrier`) ou se falta rota padrão.

**O que altera:** `/etc/rc.conf`, o IP das placas, a rota padrão (só no modo `static`) e o `sysctl` de roteamento.

**Como rodar sozinho:** `sh scripts/01-rede.sh`
**Esperado:** `[OK] LAN ... = 10.10.0.1/255.255.0.0` e `[OK] forwarding ligado`.

**À mão:**
```sh
sysrc gateway_enable=YES
sysctl net.inet.ip.forwarding=1
sysrc "ifconfig_re0=inet 10.10.0.1 netmask 255.255.0.0"
ifconfig re0 inet 10.10.0.1 netmask 255.255.0.0 up
ifconfig re0 | grep -E "inet |status"
```
**Esperado:** `inet 10.10.0.1 netmask 0xffff0000 ...` uma só vez, e `sysctl net.inet.ip.forwarding` com `1` (escreva **forwarding**, com **r** depois de "fo"). Se sobrou outro `inet` na `re0`, remova: `ifconfig re0 inet IP_ANTIGO -alias`.

Para a WAN, escolha **uma** das duas:
```sh
# WAN por DHCP (se a WAN ainda não tem IP)
sysrc "ifconfig_ue0=SYNCDHCP"
dhclient ue0

# OU WAN com IP fixo (números reais do professor, sem letras)
sysrc "ifconfig_ue0=inet 192.168.2.50 netmask 255.255.255.0"
sysrc defaultrouter=192.168.2.1
ifconfig ue0 inet 192.168.2.50 netmask 255.255.255.0
route -n add default 192.168.2.1
```
**Esperado:** `ifconfig ue0 | grep "inet "` mostra o IP e `ping -c 2 <gateway>` responde.

#### `scripts/02-dhcp.sh` (servidor DHCP e log)
**Para que serve:** subir o servidor DHCP na LAN, com a reserva do IP fixo e o log das leases.

**O que faz, em ordem:**
1. Confere que o `dhcpd` está instalado (`/usr/local/sbin/dhcpd`) e que a LAN já tem `10.10.0.1`.
2. Faz backup do `dhcpd.conf` original.
3. Gera o arquivo novo a partir do modelo `templates/dhcpd.conf.tpl` e **valida** com `dhcpd -t`. Se houver erro, mostra e **não instala**.
4. Instala em `/usr/local/etc/dhcpd.conf`, cria o arquivo de leases e o `/var/log/dhcpd.log` e configura o `syslog` (`/etc/syslog.d/dhcpd.conf`).
5. Grava no `rc.conf` `dhcpd_enable="YES"` e `dhcpd_ifaces` (só a placa da LAN) e reinicia o serviço.
6. Confere que o `dhcpd` está rodando. Se ainda não há MAC, avisa que a reserva fica para depois.

**O que altera:** `/usr/local/etc/dhcpd.conf`, `/etc/syslog.d/dhcpd.conf`, `/var/log/dhcpd.log`, `/var/db/dhcpd/dhcpd.leases` e o `rc.conf`.

**Como rodar sozinho:** `sh scripts/02-dhcp.sh`
**Esperado:** `[OK] dhcpd.conf validado e instalado`, `[OK] log do DHCP` e `[OK] dhcpd rodando`.

**À mão:** passos 2, 3 e 4 da seção 4.4 (gerar o `dhcpd.conf`, criar o log e subir o serviço só na LAN).

#### `scripts/03-pf.sh` (firewall: NAT, DNAT, isolamento e ICMP)
**Para que serve:** carregar o firewall com NAT, DNAT, bloqueio de entrada pela WAN e bloqueio de ping para fora.

**O que faz, em ordem:**
1. Carrega os módulos `pf` e `pflog` e faz backup do `/etc/pf.conf`.
2. Gera o `pf.conf` a partir do modelo clássico (`pf.conf.tpl`) e **valida** com `pfctl -nf`. Se o `pf` recusar, tenta o modelo da sintaxe nova (`pf.conf.nat-to.tpl`).
3. Se nenhuma das duas passar, **não aplica nada** e mostra o erro com o número da linha.
4. Se passar, instala em `/etc/pf.conf`, grava `pf_enable="YES"`, liga o `pf`, carrega as regras e confere que ficou habilitado.
5. Garante o forwarding e mostra o NAT e o DNAT carregados.

**O que altera:** `/etc/pf.conf`, o `rc.conf` e o estado do `pf`.

**Como rodar sozinho:** `sh scripts/03-pf.sh`
**Esperado:** `[OK] pf.conf validado (...)`, `[OK] pf habilitado e regras carregadas` e as linhas de NAT e redirecionamento.

**À mão:** passos 5 e 6 da seção 4.4 (criar o `pf.conf`, validar com `pfctl -nf` e ligar o `pf`).

#### `scripts/reserva.sh` (IP fixo por MAC)
**Para que serve:** fazer o cliente da LAN receber **sempre** o `10.10.0.100`.

**Três modos:**
```sh
sh scripts/reserva.sh                    # automático: espera o cliente e pega o MAC
sh scripts/reserva.sh aa:bb:cc:dd:ee:ff  # manual, com o MAC informado
sh scripts/reserva.sh --listar           # só mostra o MAC que escolheria
```
**O que faz (modo automático), em ordem:**
1. Espera até 3 minutos o cliente pedir IP e lê o MAC nas leases, no log do DHCP ou no ARP.
2. Valida o formato do MAC e grava em `config.auto`.
3. Roda de novo o `02-dhcp.sh`, que passa a incluir o bloco `host maquina-teste` com o MAC.
4. Pede para o cliente renovar o IP e espera (até 3 minutos) o `DHCPACK` do `10.10.0.100` no log.

**O que altera:** `config.auto` e o `/usr/local/etc/dhcpd.conf` (pelo `02-dhcp.sh`).
**Esperado:** `[OK] MAC gravado` e `[OK] o cliente recebeu o IP fixo 10.10.0.100 (confirmado no log)`.

**À mão:** descubra o MAC (seção 4.2-E) e acrescente o bloco abaixo ao `/usr/local/etc/dhcpd.conf`, **fora** do `subnet { }`:
```sh
nano /usr/local/etc/dhcpd.conf
```
```
host maquina-teste {
  hardware ethernet aa:bb:cc:dd:ee:ff;
  fixed-address 10.10.0.100;
}
```
Depois:
```sh
dhcpd -t -cf /usr/local/etc/dhcpd.conf
service isc-dhcpd restart
```
No cliente, renove o IP (Windows: `ipconfig /release` e `ipconfig /renew`). **Esperado:** `10.10.0.100`. Para confirmar no notebook: `grep 10.10.0.100 /var/log/dhcpd.log | tail -3` deve mostrar `DHCPACK on 10.10.0.100`.

**Atenção:** se você editar o `dhcpd.conf` à mão e depois rodar o `ativar.sh`, o script **gera o arquivo de novo** e apaga o seu bloco, a menos que o MAC esteja registrado. Para não perder a reserva, registre também o MAC com `sh scripts/reserva.sh aa:bb:cc:dd:ee:ff` ou em `STATIC_HOST_MAC` no `config.sh` (seção 4.3).

#### `scripts/status.sh` (mostrar tudo ao professor)
**Para que serve:** mostrar, de uma vez, o estado do sistema. Não altera nada.

**O que mostra:** os valores usados, as placas e IPs, o forwarding, a rota padrão, o estado do `pf`, o NAT e o DNAT (`pfctl -sn`), as regras (`pfctl -sr`), os estados traduzidos (`pfctl -ss`), o `dhcpd`, as leases e as últimas 20 linhas do log.

**Como rodar:** `sh scripts/status.sh`

**À mão:**
```sh
ifconfig ue0 | grep -E "inet |status"
ifconfig re0 | grep -E "inet |status"
sysctl net.inet.ip.forwarding
netstat -rn -f inet | grep default
pfctl -si | head -2
pfctl -sn
pfctl -sr
pfctl -ss
service isc-dhcpd status
cat /var/db/dhcpd/dhcpd.leases
tail -20 /var/log/dhcpd.log
```

#### `scripts/desfazer.sh` (voltar ao estado anterior)
**Para que serve:** desligar o que foi configurado e restaurar os arquivos originais.

**O que faz:** para o `dhcpd` e o `pf`; restaura o `pf.conf` e o `dhcpd.conf` a partir dos backups `*.pre-t2` (ou apaga, se não havia original); remove `/etc/syslog.d/dhcpd.conf`; remove do `rc.conf` as variáveis `pf_enable`, `dhcpd_enable`, `dhcpd_ifaces`, `gateway_enable` e o IP da LAN; tira o IP da placa da LAN; desliga o forwarding; apaga o `config.auto`. **Não mexe na WAN.**

**Como rodar:** `sh scripts/desfazer.sh`
**Esperado:** `[OK] desfeito`.

**À mão:**
```sh
service isc-dhcpd stop
service pf stop
sysrc -x pf_enable dhcpd_enable dhcpd_ifaces gateway_enable
sysrc -x ifconfig_re0
ifconfig re0 inet 10.10.0.1 -alias
sysctl net.inet.ip.forwarding=0
rm -f /etc/syslog.d/dhcpd.conf
cp -p /etc/pf.conf.pre-t2 /etc/pf.conf                              # só se o backup existir
cp -p /usr/local/etc/dhcpd.conf.pre-t2 /usr/local/etc/dhcpd.conf    # só se o backup existir
```

#### `testes/router/` (testes que rodam no notebook)
**Para que servem:** conferir, item por item, se a configuração ficou certa. Cada um mostra `[ OK ]` ou `[FALHOU]` e um resumo `X ok, Y falhas`. Só **leem** o sistema, não alteram nada.

- `rodar-todos.sh` executa os seis testes e termina com `TODOS OS TESTES DO ROTEADOR PASSARAM` (ou diz quantos falharam).
- `lib.sh` são as funções comuns dos testes (não se roda sozinho).

Equivalente à mão de cada teste:

| Teste | O que confere | Comando manual | Esperado |
|---|---|---|---|
| `t01-conectividade.sh` | IPs, cabos, forwarding, rota, gateway, DNS | `ifconfig ue0 \| grep -E "inet \|status"`, `ifconfig re0 \| grep -E "inet \|status"`, `sysctl net.inet.ip.forwarding`, `netstat -rn -f inet \| grep default`, `ping -c 2 <gateway>`, `host unb.br 164.41.101.4` | IP e `status: active` nas duas, forwarding `1`, rota default, ping responde, `unb.br has address ...` |
| `t02-nat.sh` | `pf` ligado, regra de NAT, estados traduzidos | `pfctl -si \| grep Status`, `pfctl -sn \| grep nat`, `pfctl -ss \| grep '('` | `Status: Enabled`, `nat on ue0 ...`, linha `IP_WAN:porta (IP_LAN:porta) -> destino` |
| `t03-isolamento.sh` | bloqueio de entrada pela WAN | `pfctl -sr \| grep "block.*in on ue0"`, `ifconfig ue0 \| grep inet` | regra de bloqueio presente; a WAN sem IP `10.10.x.x` |
| `t04-dhcp.sh` | `dhcpd`, sub-rede, DNS, reserva, leases e log | `pgrep -x dhcpd`, `dhcpd -t -cf /usr/local/etc/dhcpd.conf`, `grep -A3 "host maquina-teste" /usr/local/etc/dhcpd.conf`, `sysrc dhcpd_ifaces`, `ls /var/db/dhcpd/dhcpd.leases /var/log/dhcpd.log` | um número de PID, sem erro de sintaxe, bloco `host` com o MAC, `dhcpd_ifaces: re0`, os dois arquivos existem |
| `t05-dnat.sh` | regra `rdr` e liberação da porta 8080 | `pfctl -sn \| grep rdr`, `pfctl -sr \| grep -E "8080\|http-alt"`, `pfctl -ss \| grep 8080` | `rdr on ue0 ... -> 10.10.0.100 port 8080`; o `pf` mostra a 8080 como `http-alt` |
| `t06-icmp.sh` | bloqueio de ping da LAN para fora | `pfctl -sr \| grep "quick on re0"` | `block drop in quick on re0 ... icmp ... to ! 10.10.0.0/16` |

#### `testes/cliente/` (testes que rodam nos clientes)
- **`lan-client.sh`** (no cliente da LAN, Linux/BSD): confere que o IP é `10.10.x.x`, que o ping ao gateway responde, que o DNS resolve (prova o NAT) e que o ping para fora está **bloqueado**. Uso: `sh testes/cliente/lan-client.sh`. À mão (Windows): `ping 10.10.0.1`, `nslookup unb.br 164.41.101.4` e `ping 164.41.101.4` (o primeiro e o segundo respondem; o terceiro não).
- **`servidor-8080.sh`** (no cliente da LAN `10.10.0.100`): fica escutando na porta 8080 para receber o teste do DNAT. À mão: `while true; do nc -l 8080; done` (Windows: `ncat -l 8080 -k`).
- **`wan-client.sh`** (em outro computador da rede do laboratório): conecta na porta 80 do roteador (DNAT), envia um texto e testa o isolamento (ping e porta 22 direto ao cliente da LAN devem falhar). Uso: `sh testes/cliente/wan-client.sh IP_DA_WAN 10.10.0.100`. À mão: `telnet IP_DA_WAN 80` e, com a rota para a LAN adicionada, `ping -c 2 10.10.0.100` e `nc -z -w 3 10.10.0.100 22` (seções "Teste 6" e "Teste 7").

#### Arquivos de apoio
- **`config.sh`:** os valores do projeto. `"auto"` significa "descobrir sozinho"; um valor escrito força aquele valor (seção 4.3).
- **`config.auto`:** gerado pelo `00-detectar.sh` e pelo `reserva.sh`; guarda o que foi detectado e o MAC. Apague com `rm -f config.auto` para refazer a detecção.
- **`lib/common.sh`:** funções usadas por todos os scripts: ler o `config.sh`, usar os valores detectados, `render` (preencher os modelos), `backup_once` (backup do original) e as mensagens `[OK]`, `[AVISO]` e `[ERRO]`.
- **`templates/*.tpl`:** modelos do `dhcpd.conf` e do `pf.conf` (duas sintaxes), com marcações `@VARIAVEL@` que os scripts preenchem.

---

## 4. O que é detectado automaticamente

O `scripts/00-detectar.sh` roda no início do `ativar.sh`, descobre os dados abaixo e guarda em `config.auto`.

| Dado | Como é descoberto |
|---|---|
| **Placas candidatas** | Placas Ethernet físicas. Ignora `lo0`, `pflog0`, `wlan`, bridge, túneis etc. Se achar só uma, tenta carregar drivers de adaptador USB (`if_ure`, `if_axge`, `if_cdce`...) |
| **LAN** | A placa que já tem IP da faixa `10.10.x.x`; se nenhuma tiver, a outra placa (preferindo a que está com cabo) |
| **WAN** | A placa da rota padrão; senão a que tem IP e cabo; senão o adaptador USB (`ue*`); senão a primeira com cabo |
| **Modo da WAN** | Se o `rc.conf` já usa DHCP nela, é `dhcp`. Se não tem IP, tenta `dhclient` por até 45 s. Se tem IP manual, é `keep` (não mexe) |
| **DNS** | Testa, nesta ordem, `164.41.101.4`, `164.41.101.11` e o gateway da WAN (`192.168.X.1`); usa o primeiro que resolver `unb.br` |
| **MAC do cliente (IP fixo)** | Quando o cliente da LAN pede IP, o script lê o MAC nas leases, no log do DHCP ou na tabela ARP |

O resultado aparece na tela, por exemplo:
```
--- detectado ---
WAN : ue0  (IP 192.168.2.119)  modo: dhcp
LAN : re0  (sera 10.10.0.1/255.255.0.0)
DNS : 164.41.101.4
```
**Confira esse bloco**: se a WAN e a LAN estiverem trocadas, descubra os valores certos à mão (seção 4.2) e force-os (seção 4.3).

### 4.1 Quando editar o `config.sh` (casos especiais)
```sh
nano config.sh
```
- **O professor passou IP fixo para a WAN:** preencha `WAN_MODE="static"`, `WAN_IP="..."` e `WAN_GW="..."` com **números reais** (nunca deixe letras como `X` ou `Y`).
- **A detecção errou as placas:** force `WAN_IF="ue0"` e `LAN_IF="re0"`.
- **Quer outro DNS:** `DNS_SERVER="164.41.101.11"`.

Salvar: Ctrl+O, Enter. Sair: Ctrl+X. Depois rode `sh scripts/ativar.sh` de novo.

### 4.2 Como descobrir cada informação manualmente (se a detecção errar)

Use esta seção quando o bloco `--- detectado ---` mostrar algo errado ou quando o script parar com erro. Depois de descobrir cada valor, **force-o no `config.sh`** (seção 4.3) e rode `sh scripts/ativar.sh` de novo.

Os exemplos usam `ue0` (adaptador USB) e `re0` (RJ45 do notebook). Troque pelos nomes que aparecerem no seu `ifconfig -l`.

| Informação | Comando principal | Resposta esperada | Onde usar |
|---|---|---|---|
| Placas existentes | `ifconfig -l` | `re0 ue0 lo0 pflog0` | `WAN_IF` e `LAN_IF` |
| Qual é a WAN | `ifconfig ue0 \| grep -E "inet \|status"` | `status: active` e `inet 192.168.X.Y` | `WAN_IF` |
| IP, máscara e gateway da WAN | `route -n get default` | `gateway: 192.168.X.1` e `interface: ue0` | `WAN_IP`, `WAN_GW` |
| WAN por DHCP? | `dhclient ue0` | `bound to 192.168.X.Y` | `WAN_MODE` |
| DNS que responde | `host unb.br 164.41.101.4` | `unb.br has address ...` | `DNS_SERVER` |
| MAC do cliente | `cat /var/db/dhcpd/dhcpd.leases` | `hardware ethernet aa:bb:...;` | `sh scripts/reserva.sh <MAC>` |

#### A) Descobrir quais são as placas de rede
```sh
ifconfig -l
```
**Esperado:** algo como `re0 ue0 lo0 pflog0`. Ignore `lo0` e `pflog0`: as outras são as placas de rede.

Para saber qual é o adaptador USB e qual é a placa interna:
```sh
usbconfig list
dmesg | grep -E "^(ue|re|em|igc|igb)[0-9]"
```
**Esperado:** `ue0` é o adaptador USB-Ethernet (o nome `ue` vem de USB Ethernet) e `re0` (ou `em0`, `igc0`) é a placa interna do notebook.

Se o adaptador USB **não aparece** no `ifconfig -l`, carregue o driver (um por vez) e confira de novo:
```sh
kldload if_ure       # Realtek
ifconfig -l
kldload if_axge      # ASIX gigabit
ifconfig -l
kldload if_cdce      # adaptadores genéricos / USB-C
ifconfig -l
```
Se nenhum funcionar, veja `dmesg | tail -20` e identifique o chip do adaptador.

#### B) Descobrir qual placa é a WAN e qual é a LAN
**Regra:** a WAN é a placa ligada na rede do laboratório (a que tem IP `192.168.X.Y`); a LAN é a outra.

1. Deixe plugado **só o cabo do laboratório** (tire o cabo do cliente da LAN).
2. Confira as duas placas:
   ```sh
   ifconfig ue0 | grep -E "inet |status"
   ifconfig re0 | grep -E "inet |status"
   ```
   **Esperado:** a WAN mostra `inet 192.168.2.119 netmask 0xffffff00 ...` e `status: active`. A outra mostra `status: no carrier` e nenhum `inet`.
3. Confirme pela rota padrão:
   ```sh
   route -n get default | grep -E "gateway|interface"
   ```
   **Esperado:** `interface: ue0`. A placa que aparece em `interface:` é a WAN.
4. Religue o cabo do cliente da LAN.

Para ver o MAC de cada placa (se precisar distinguir): `ifconfig ue0 | grep ether` e `ifconfig re0 | grep ether`.

#### C) Descobrir IP, máscara, gateway e se a WAN é DHCP ou fixa
```sh
ifconfig ue0 | grep "inet "
route -n get default | grep -E "gateway|interface"
netstat -rn -f inet | grep default
```
**Esperado:**
```
inet 192.168.2.119 netmask 0xffffff00 broadcast 192.168.2.255
gateway: 192.168.2.1
interface: ue0
default            192.168.2.1        UGS         ue0
```
A máscara aparece em hexadecimal. Converta assim:

| Hexadecimal | Decimal | Prefixo |
|---|---|---|
| `0xffffff00` | `255.255.255.0` | /24 |
| `0xffff0000` | `255.255.0.0` | /16 |

**O laboratório dá IP por DHCP?** Peça um IP:
```sh
dhclient ue0
```
**Esperado:** aparece `DHCPACK from 192.168.X.1` e `bound to 192.168.X.Y`. Se apareceu, a WAN é DHCP: use `WAN_MODE="dhcp"`.

Veja também o que o `rc.conf` guarda para a WAN:
```sh
sysrc ifconfig_ue0
```
**Esperado:** `ifconfig_ue0: DHCP` (ou `SYNCDHCP`) quando a WAN é DHCP.

**Se o `dhclient` não responde (passou cerca de 1 minuto)**, o laboratório não usa DHCP. Peça ao professor: o **IP** do notebook, a **máscara** (quase sempre `255.255.255.0`) e o **gateway** (`192.168.X.1`). Teste com números reais, sem letras:
```sh
ifconfig ue0 inet 192.168.2.50 netmask 255.255.255.0
route -n add default 192.168.2.1
ping -c 2 192.168.2.1
```
**Esperado:** 2 respostas do gateway. Depois use esses valores como `WAN_MODE="static"`, `WAN_IP` e `WAN_GW` (seção 4.3).

Se o `ifconfig` responder `bad value`, você deixou letras (`X`, `Y`) no IP. Use só números.

#### D) Descobrir qual DNS responde
O enunciado permite `164.41.101.4`, `164.41.101.11` ou o gateway do laboratório (`192.168.X.1`). Teste um por vez:
```sh
host unb.br 164.41.101.4
host unb.br 164.41.101.11
host unb.br 192.168.2.1
```
(no último, use o gateway real da seção C)

**Esperado:** `unb.br has address ...`. Use o primeiro que responder. Se o `host` não existir:
```sh
drill unb.br @164.41.101.4
```
**Esperado:** uma seção `ANSWER SECTION` com o endereço.

Se **nenhum** responder, o problema é a WAN, não o DNS: volte à seção C e confira `ping -c 2 <gateway>`.

#### E) Descobrir o MAC do cliente da LAN
**No notebook**, depois que o cliente da LAN pediu IP (use uma das três formas):
```sh
cat /var/db/dhcpd/dhcpd.leases
grep DHCPDISCOVER /var/log/dhcpd.log | tail -3
arp -an | grep re0
```
**Esperado:**
- nas leases: `hardware ethernet aa:bb:cc:dd:ee:ff;`
- no log: `DHCPDISCOVER from aa:bb:cc:dd:ee:ff via re0`
- no ARP: `? (10.10.1.5) at aa:bb:cc:dd:ee:ff on re0 ...`

O MAC é o `aa:bb:cc:dd:ee:ff`. Se o cliente nunca pediu IP, esses três ficam vazios: faça o cliente pedir IP primeiro.

**No próprio cliente:**

| Sistema | Comando | Onde está o MAC |
|---|---|---|
| Windows | `ipconfig /all` | campo **Endereço Físico**, do adaptador Ethernet (cabeado). Troque os `-` por `:` e use letras minúsculas |
| Linux | `ip link` | linha `link/ether aa:bb:cc:dd:ee:ff` |
| FreeBSD | `ifconfig` | linha `ether aa:bb:cc:dd:ee:ff` |

Se o cliente tem Wi-Fi e cabo, use o MAC do adaptador **do cabo** (o que está ligado no notebook).

Com o MAC em mãos:
```sh
sh scripts/reserva.sh aa:bb:cc:dd:ee:ff
```
O script aceita maiúsculas e traços (`AA-BB-CC-DD-EE-FF`).

#### F) Conferir o que o script detectou
```sh
cat config.auto
sh scripts/status.sh
```
**Esperado no `config.auto`:** linhas `AUTO_WAN_IF="ue0"`, `AUTO_LAN_IF="re0"`, `AUTO_WAN_MODE="dhcp"` e `AUTO_DNS_SERVER="164.41.101.4"` (o MAC aparece depois da reserva). Compare com o que você descobriu nas seções A a E.

### 4.3 Como forçar os valores no `config.sh`
Quando você descobriu o valor certo à mão, grave-o no `config.sh`. Onde está `"auto"`, o script descobre sozinho; onde você escreve um valor, ele usa o seu.
```sh
nano config.sh
```
Troque só o que precisar. Exemplos:
```sh
WAN_IF="ue0"
LAN_IF="re0"
WAN_MODE="static"          # use "dhcp" se o laboratório der IP automático
WAN_IP="192.168.2.50"      # só no modo static, números reais
WAN_GW="192.168.2.1"       # só no modo static
DNS_SERVER="164.41.101.11"
STATIC_HOST_MAC="aa:bb:cc:dd:ee:ff"
```
Salve com Ctrl+O, Enter e saia com Ctrl+X. Depois:
```sh
rm -f config.auto
sh scripts/ativar.sh
```
O `rm -f config.auto` apaga a detecção antiga, para o script refazer tudo com os seus valores.

### 4.4 Configuração 100% manual (se os scripts falharem por completo)
Estes são os mesmos passos que os scripts executam. Troque `ue0` (WAN), `re0` (LAN), o DNS e o MAC pelos valores que você descobriu na seção 4.2. Todos como **root**, na tela do notebook.

**1) Rede e roteamento**
```sh
sysrc gateway_enable=YES
sysctl net.inet.ip.forwarding=1
sysrc "ifconfig_re0=inet 10.10.0.1 netmask 255.255.0.0"
ifconfig re0 inet 10.10.0.1 netmask 255.255.0.0 up
ifconfig re0 | grep -E "inet |status"
sysctl net.inet.ip.forwarding
```
**Esperado:** `inet 10.10.0.1 netmask 0xffff0000 ...` **uma só vez** e `net.inet.ip.forwarding: 1`. Escreva **forwarding** com **r** depois de "fo".

Se a `re0` mostrar outro `inet` (por exemplo um IP antigo), remova-o:
```sh
ifconfig re0 inet 192.168.5.20 -alias
```
(troque pelo IP que sobrou)

**2) DHCP** (troque o DNS; o bloco `host` é a reserva do IP fixo e pode ser acrescentado depois)
```sh
cat > /usr/local/etc/dhcpd.conf <<'EOF'
authoritative;
default-lease-time 600;
max-lease-time 7200;
option domain-name-servers 164.41.101.4;
log-facility local7;

subnet 10.10.0.0 netmask 255.255.0.0 {
  range 10.10.1.1 10.10.1.254;
  option routers 10.10.0.1;
  option subnet-mask 255.255.0.0;
  option broadcast-address 10.10.255.255;
}

host maquina-teste {
  hardware ethernet aa:bb:cc:dd:ee:ff;
  fixed-address 10.10.0.100;
}
EOF
nano /usr/local/etc/dhcpd.conf
dhcpd -t -cf /usr/local/etc/dhcpd.conf
```
No nano, troque `aa:bb:cc:dd:ee:ff` pelo MAC real (ou apague o bloco `host` se ainda não tem o MAC). **Esperado:** nenhuma mensagem de erro no `dhcpd -t`.

**3) Log do DHCP**
```sh
mkdir -p /var/db/dhcpd
touch /var/db/dhcpd/dhcpd.leases /var/log/dhcpd.log
printf 'local7.*\t\t\t\t/var/log/dhcpd.log\n' > /etc/syslog.d/dhcpd.conf
service syslogd restart
```

**4) Subir o DHCP só na LAN**
```sh
sysrc dhcpd_enable=YES
sysrc dhcpd_ifaces="re0"
service isc-dhcpd restart
service isc-dhcpd status
```
**Esperado:** `dhcpd is running as pid ...`. Se aparecer `No subnet declaration for re0`, a `re0` não está com `10.10.0.1` (volte ao passo 1).

**5) Firewall (NAT + DNAT + bloqueio de ping)**
```sh
cat > /etc/pf.conf <<'EOF'
wan_if    = "ue0"
lan_if    = "re0"
lan_net   = "10.10.0.0/16"
dnat_host = "10.10.0.100"

set skip on lo0
set block-policy drop

nat on $wan_if inet from $lan_net to any -> ($wan_if)

rdr on $wan_if inet proto tcp from any to ($wan_if) port 80 -> $dnat_host port 8080

pass all
block in on $wan_if all
pass in on $wan_if inet proto udp from any port 67 to any port 68
pass in on $wan_if inet proto icmp from any to ($wan_if) icmp-type echoreq
pass in on $wan_if inet proto tcp to $dnat_host port 8080

block in quick on $lan_if inet proto icmp from $lan_net to ! $lan_net icmp-type echoreq
EOF
pfctl -nf /etc/pf.conf
```
**Atenção à ordem do `icmp-type`:** no `pf`, `icmp-type` vem **depois** de `from ... to ...`. Escrever `proto icmp icmp-type echoreq to ...` dá `syntax error` (foi o erro que apareceu nas linhas dos pings).

**Esperado:** nenhuma saída. Digite as aspas direto no teclado (aspas retas); aspas curvas, que vêm de colar texto formatado, fazem o `pf` recusar o arquivo.

Se o `pfctl -nf` reclamar nas linhas `nat on` ou `rdr on`, seu `pf` usa a sintaxe nova. Troque as duas por estas (e deixe o resto igual):
```
pass all
match out on $wan_if inet from $lan_net to any nat-to ($wan_if)
match in on $wan_if inet proto tcp from any to ($wan_if) port 80 rdr-to $dnat_host port 8080
```
Neste caso, a linha `pass all` fica **antes** das duas linhas `match` (como no modelo `templates/pf.conf.nat-to.tpl`): **apague** o `pass all` antigo, que vinha mais abaixo, para não repetir. O resto do arquivo continua igual.

**6) Ligar o firewall**
```sh
sysrc pf_enable=YES
service pf start
pfctl -f /etc/pf.conf
pfctl -e
pfctl -sn
```
**Esperado:** o `pfctl -sn` mostra o NAT na WAN (`nat on ue0 ...`) e o redirecionamento (`rdr on ue0 ... -> 10.10.0.100 port 8080`). Se o `pfctl -e` disser que já está habilitado, tudo bem.

Depois siga para os testes da seção 8.

---

## 5. Onde ficam as configurações no sistema, para que servem e como são usadas

Depois do `ativar.sh`, estes são os arquivos do FreeBSD que ficam configurados:

| Arquivo / ajuste | Quem cria | Para que serve | Como é usado |
|---|---|---|---|
| `config.auto` (na pasta do projeto) | `00-detectar.sh`, `reserva.sh` | Guarda o que foi detectado (placas, modo, DNS, MAC) | Lido pelos outros scripts quando o `config.sh` diz `auto` |
| `/etc/rc.conf` | `01-rede.sh`, `02-dhcp.sh`, `03-pf.sh` (via `sysrc`) | Configurações que **sobrevivem ao reboot** | `ifconfig_<LAN>` (IP da LAN), `ifconfig_<WAN>` (WAN por DHCP), `gateway_enable="YES"`, `pf_enable="YES"`, `dhcpd_enable="YES"`, `dhcpd_ifaces="<LAN>"` |
| `net.inet.ip.forwarding=1` | `01-rede.sh` (`sysctl`) | **Liga o roteamento** entre as placas | Aplicado na hora e mantido pelo `gateway_enable` |
| `/etc/pf.conf` | `03-pf.sh` (do modelo `pf.conf.tpl`) | **Firewall**: NAT, DNAT, isolamento da WAN e bloqueio de ping | Lido pelo `pf` ao iniciar e por `pfctl -f /etc/pf.conf` |
| `/usr/local/etc/dhcpd.conf` | `02-dhcp.sh` (do modelo `dhcpd.conf.tpl`) | **Servidor DHCP**: faixa, gateway, DNS e reserva do IP fixo | Lido pelo `dhcpd` ao iniciar |
| `/etc/syslog.d/dhcpd.conf` | `02-dhcp.sh` | Manda as mensagens do DHCP para um log próprio | Lido pelo `syslogd` |
| `/var/log/dhcpd.log` | `02-dhcp.sh` | **Log do DHCP** (DISCOVER, OFFER, REQUEST, ACK) | `tail -20 /var/log/dhcpd.log` |
| `/var/db/dhcpd/dhcpd.leases` | `02-dhcp.sh` e o próprio `dhcpd` | **Leases**: concessões de IP ativas | `cat /var/db/dhcpd/dhcpd.leases` |
| `*.pre-t2` | `backup_once` | Cópia dos arquivos originais antes da alteração | Restaurados pelo `desfazer.sh` |

### O que cada regra do `pf.conf` faz

| Linha (resumo) | O que faz |
|---|---|
| `nat on <WAN> inet from 10.10.0.0/16 to any -> (<WAN>)` | **NAT**: os clientes da LAN saem com o IP da WAN |
| `rdr on <WAN> ... port 80 -> 10.10.0.100 port 8080` | **DNAT**: porta 80 da WAN vira porta 8080 do cliente |
| `pass all` + `block in on <WAN> all` | Tudo passa, mas **nada novo entra pela WAN** (isolamento) |
| `pass in on <WAN> ... udp ... 67 ... 68` | Permite a resposta do DHCP da WAN |
| `pass in on <WAN> ... proto icmp from any to (<WAN>) icmp-type echoreq` | Permite ping ao próprio roteador pela WAN |
| `pass in on <WAN> ... tcp to 10.10.0.100 port 8080` | Libera o destino já traduzido pelo DNAT |
| `block in quick on <LAN> ... proto icmp from 10.10.0.0/16 to ! 10.10.0.0/16 icmp-type echoreq` | **Bloqueia ping da LAN para fora**; o ping ao gateway `10.10.0.1` continua funcionando |

### O que o `dhcpd.conf` faz
- `subnet 10.10.0.0 netmask 255.255.0.0` e `range 10.10.1.1 10.10.1.254`: a rede e a faixa de IPs entregues.
- `option routers 10.10.0.1`: o gateway dos clientes é o notebook.
- `option domain-name-servers <DNS>`: o DNS entregue.
- `log-facility local7`: manda o log para o `syslog` (que grava em `/var/log/dhcpd.log`).
- Bloco `host maquina-teste { hardware ethernet <MAC>; fixed-address 10.10.0.100; }`: a **reserva**. O cliente com esse MAC recebe sempre `10.10.0.100`. O bloco só aparece depois que o MAC é descoberto.

---

## 6. Preparação (antes de ir ao laboratório, com internet)

1. Instale o servidor DHCP (não vem no FreeBSD):
   ```sh
   pkg install -y isc-dhcp44-server
   pkg info isc-dhcp44-server
   ```
   **Esperado:** uma linha `isc-dhcp44-server-4.4...`.
2. Leve o `trabalho02-gateway.zip` para o notebook (pendrive FAT32):
   ```sh
   gpart show
   mount -t msdosfs /dev/da1s1 /mnt
   cp /mnt/trabalho02-gateway.zip /root/
   umount /mnt
   cd /root
   tar xf trabalho02-gateway.zip
   cd trabalho02-gateway
   ls
   ```
   Se o `mount` falhar, troque `da1s1` pelo nome que o `gpart show` mostrou (por exemplo `da0s1`).
   **Esperado no `ls`:** `LEIAME.md config.sh lib scripts templates testes`.

---

## 7. Passo a passo da configuração

Todos os comandos são como **root**, dentro da pasta `trabalho02-gateway`. Use a tela do próprio notebook (não SSH): o firewall pode cortar conexões remotas.

### Passo 1: ligar os cabos
- Cabo da tomada do laboratório no **adaptador USB** (WAN).
- Cabo da porta **RJ45 do notebook** (LAN) no computador do cliente (ou num switch só da LAN).

### Passo 2: rodar tudo
```sh
sh scripts/ativar.sh
```
Ele faz, na ordem: **detecta** (`00`), **rede** (`01`), **DHCP** (`02`), **firewall** (`03`), **reserva o IP fixo** e **roda os testes**.

**Esperado, na ordem:**
1. O bloco `--- detectado ---` com WAN, LAN, DNS e modo (confira se estão certos).
2. `[OK] LAN ... = 10.10.0.1/255.255.0.0` e `[OK] forwarding ligado (net.inet.ip.forwarding=1)`.
3. `[OK] dhcpd.conf validado e instalado` e `[OK] dhcpd rodando`.
4. `[OK] pf.conf validado (pf.conf.tpl) e instalado` (ou `pf.conf.nat-to.tpl`) e `[OK] pf habilitado e regras carregadas`, seguido das linhas de NAT e redirecionamento.
5. `=== RESERVA AUTOMATICA DO IP FIXO ===` e a mensagem `aguardando o cliente da LAN pedir IP`.

Se aparecer `[ERRO]`, leia a mensagem: ela diz a causa e **nada inválido foi aplicado**. Corrija e rode `sh scripts/ativar.sh` de novo.

### Passo 3: o cliente pede IP (o script espera até 3 minutos)
No computador do cliente da LAN (Windows: `ipconfig /renew`, ou "Obter IP automaticamente"; Linux: `sudo dhclient -v <placa>`).

**Esperado no cliente:** IP `10.10.1.x`, gateway `10.10.0.1`, DNS igual ao detectado.
**Esperado no notebook:** `[OK] cliente encontrado: aa:bb:cc:dd:ee:ff` e `[OK] MAC gravado: ... -> 10.10.0.100`, seguido do bloco `host maquina-teste` com o MAC real.

### Passo 4: o cliente pega o IP fixo
O script pede: *"AGORA, NO CLIENTE: libere e renove o IP"*. No cliente (Windows: `ipconfig /release` e depois `ipconfig /renew`; Linux: `sudo dhclient -r <placa>` e depois `sudo dhclient -v <placa>`).

**Esperado:** o cliente com `10.10.0.100` e, no notebook, `[OK] o cliente recebeu o IP fixo 10.10.0.100 (confirmado no log)`. Se vier `10.10.1.x`, desconecte e reconecte o cabo do cliente e tente de novo.

### Passo 5: testes do roteador
O `ativar.sh` termina rodando os testes. **Esperado:** `TODOS OS TESTES DO ROTEADOR PASSARAM`. Se o cliente não apareceu a tempo, o script avisa e roda os testes mesmo assim: depois rode `sh scripts/reserva.sh` com o cliente pedindo IP.

**Variações úteis:**
- `sh scripts/ativar.sh --sem-cliente`: não espera o cliente (reserve depois com `sh scripts/reserva.sh`).
- `sh scripts/reserva.sh aa:bb:cc:dd:ee:ff`: informa o MAC à mão (aceita maiúsculas e traços).
- `sh scripts/reserva.sh --listar`: mostra qual MAC o script escolheria, sem alterar nada.

**A configuração termina aqui.** Só siga para os testes de cliente com o cliente em `10.10.0.100`, porque o DNAT depende desse IP.

---

## 8. TESTES (a partir daqui é só verificação)

Anote o IP da WAN do notebook (a placa WAN que o `--- detectado ---` mostrou):
```sh
ifconfig ue0 | grep "inet "
```
(troque `ue0` pela WAN detectada; no exemplo, `192.168.2.119`. Ele pode mudar se o notebook renovar o IP.)

### Teste 1: IP fixo
**Onde:** cliente da LAN, liberando e pedindo IP duas vezes.
**Esperado:** sempre `10.10.0.100`.

### Teste 2: leases em arquivo e log
**Onde:** notebook.
```sh
cat /var/db/dhcpd/dhcpd.leases
tail -20 /var/log/dhcpd.log
```
**Esperado:** blocos `lease 10.10.0.100 {` com o MAC do cliente e, no log, `DHCPDISCOVER`, `DHCPOFFER`, `DHCPREQUEST` e `DHCPACK`.

### Teste 3: conectividade
**Onde:** cliente da LAN.
```sh
ping -c 2 10.10.0.1
```
**Esperado:** 2 respostas do gateway.

### Teste 4: NAT (tradução de endereço)
**Onde:** cliente da LAN.
```sh
nslookup unb.br 164.41.101.4
```
**Esperado:** o endereço do `unb.br`.

**Onde:** notebook, logo em seguida.
```sh
pfctl -ss | grep '('
```
**Esperado:** uma linha como `192.168.2.119:51234 (10.10.0.100:40000) -> 164.41.101.4:53`. O IP **entre parênteses** é o do cliente da LAN, e o de fora é o da WAN. Isso prova que o NAT trocou o endereço.

**Não valide o NAT com ping:** o ping para fora é bloqueado de propósito. Use DNS ou TCP.

### Teste 5: ping bloqueado para fora
**Onde:** cliente da LAN.
```sh
ping -c 2 164.41.101.4
ping -c 2 10.10.0.1
```
**Esperado:** o primeiro com `100% packet loss` (é o resultado certo) e o segundo com respostas.

### Teste 6: DNAT (porta 80 da WAN vira porta 8080 da LAN)
1. **No cliente da LAN** (`10.10.0.100`), deixe rodando um servidor TCP:
   ```sh
   sh testes/cliente/servidor-8080.sh
   ```
   (ou `while true; do nc -l 8080; done`). No Windows use `ncat -l 8080 -k` e libere a porta 8080 no firewall do Windows.
2. **Em outro computador ligado na rede do laboratório** (não pode ser o notebook nem o cliente da LAN):
   ```sh
   telnet 192.168.2.119 80
   ```
   Troque pelo IP da WAN anotado. Digite `oi` e Enter.
   **Esperado:** `Connected to 192.168.2.119.` e o texto `oi` aparece no terminal do cliente da LAN.
3. **No notebook:**
   ```sh
   pfctl -ss | grep 8080
   ```
   **Esperado:** um estado ligando o computador da WAN a `10.10.0.100:8080`.

Alternativa automática, no computador da WAN:
```sh
sh testes/cliente/wan-client.sh 192.168.2.119 10.10.0.100
```

### Teste 7: isolamento de segmento
**Onde:** o mesmo computador da WAN. Primeiro ensine uma rota para a LAN pelo notebook:
```sh
sudo ip route add 10.10.0.0/16 via 192.168.2.119      # Linux
route add 10.10.0.0/16 192.168.2.119                  # FreeBSD
```
Depois teste:
```sh
ping -c 2 10.10.0.100
nc -z -w 3 10.10.0.100 22
```
**Esperado:** os dois **falham** (sem resposta). Só a porta 80 do notebook (DNAT) responde.

Use a porta **22** e não a 8080: a 8080 está liberada pela regra do DNAT, então um teste direto nela pode conectar e parecer que o isolamento falhou.

### Testes automáticos no notebook
```sh
sh testes/router/rodar-todos.sh
```
**Esperado no final:** `TODOS OS TESTES DO ROTEADOR PASSARAM`.

| Arquivo | O que verifica |
|---|---|
| `t01-conectividade.sh` | IPs, cabos, forwarding, rota default, ping ao gateway da WAN e DNS |
| `t02-nat.sh` | regra de NAT e estados traduzidos |
| `t03-isolamento.sh` | bloqueio de entrada pela WAN e segmentos separados |
| `t04-dhcp.sh` | `dhcpd`, reserva por MAC, leases e log |
| `t05-dnat.sh` | regra de redirecionamento 80 -> 8080 e a liberação da porta 8080 |
| `t06-icmp.sh` | bloqueio de ping da LAN para fora |

Os testes 02, 04 e 05 só ficam completos depois dos testes de cliente acima. Rode-os de novo no fim.

### Para mostrar ao professor
```sh
sh scripts/status.sh
cat /var/db/dhcpd/dhcpd.leases
tail -20 /var/log/dhcpd.log
```

---

## 9. Se algo falhar

| Sintoma | O que ver |
|---|---|
| `[ERRO] preciso de 2 placas de rede` | Plugue o adaptador USB-Ethernet e confira com `ifconfig -l` (drivers: seção 4.2-A) |
| `[ERRO] a WAN não recebeu IP por DHCP` | Cabo do laboratório na placa WAN. Confira à mão (seção 4.2-C). Se o professor passou IP fixo, use `WAN_MODE="static"` (seção 4.3) |
| WAN e LAN trocadas no `--- detectado ---` | Descubra à mão (seção 4.2-A e B) e force `WAN_IF` e `LAN_IF` no `config.sh` (seção 4.3) |
| `[ERRO] dhcpd não instalado` | Instale com internet: `pkg install -y isc-dhcp44-server` |
| `bad value` ao colocar IP | Você deixou `X`/`Y` no IP. Use os números reais |
| LAN com `no carrier` | O cabo da placa LAN não está ligado no cliente ou no switch |
| `dhcpd` não sobe, "No subnet declaration" | A placa da LAN precisa estar só com `10.10.0.1`: rode `sh scripts/ativar.sh` de novo |
| Cliente sem IP | `service isc-dhcpd status` e `tail /var/log/dhcpd.log` |
| Cliente com IP, mas sem DNS | `sysctl net.inet.ip.forwarding` deve dar `1` (o nome certo tem **r**: for**r**warding) e `pfctl -sn` deve mostrar `nat on` na WAN |
| `syntax error` em linha com `icmp` | A regra tem `icmp-type` antes de `from ... to ...`. Use a forma `proto icmp from X to Y icmp-type echoreq` (seção 4.4) |
| O `03-pf.sh` recusou as duas sintaxes | Copie a mensagem de erro que ele imprime (com o número da linha) e envie para análise |
| Reserva não concluída (cliente não apareceu) | Faça o cliente pedir IP e rode `sh scripts/reserva.sh`. Para achar o MAC à mão: seção 4.2-E |
| DNAT não conecta | `nc -l 8080` rodando em `10.10.0.100`; gateway do cliente `10.10.0.1`; firewall do Windows liberado |
| Parou depois de reiniciar | Rode `sh scripts/ativar.sh` de novo |
| Os scripts não funcionam de jeito nenhum | Configuração manual completa: seção 4.4 |

Comandos úteis: `pfctl -sn` (NAT/DNAT), `pfctl -sr` (regras), `pfctl -ss` (conexões), `service isc-dhcpd status`, `tcpdump -ni <placa>`.

---

## 10. Desfazer tudo
```sh
sh scripts/desfazer.sh
```
Desliga o `pf` e o DHCP, restaura os arquivos originais (`*.pre-t2`), remove as variáveis do `rc.conf` e apaga o `config.auto`. **Não mexe na WAN.**

---

## 11. Atualizar um pacote que você já extraiu

Se você já extraiu o zip anterior e baixou só os arquivos novos, copie cada um para a pasta indicada (dentro de `trabalho02-gateway/`):

| Arquivo | Pasta de destino | Ação |
|---|---|---|
| `config.sh` | `trabalho02-gateway/` (raiz) | substitui |
| `common.sh` | `trabalho02-gateway/lib/` | substitui |
| `00-detectar.sh` | `trabalho02-gateway/scripts/` | **novo** |
| `ativar.sh` | `trabalho02-gateway/scripts/` | substitui |
| `reserva.sh` | `trabalho02-gateway/scripts/` | substitui |
| `status.sh` | `trabalho02-gateway/scripts/` | substitui |
| `desfazer.sh` | `trabalho02-gateway/scripts/` | substitui |

Não mexa em `01-rede.sh`, `02-dhcp.sh`, `03-pf.sh`, nos modelos (`templates/`) nem nos testes. Se preferir, baixe o `trabalho02-gateway.zip` completo e atualizado e extraia de novo.

---

## 12. Documentação mínima exigida pelo enunciado (30% da nota)

- **Sistema operacional:** FreeBSD, instalado direto no hardware (*BSD = 100% da nota). Sem distribuições prontas de gateway: só o sistema base (`pf`, `sysctl`, `ifconfig`, `rc.conf`) mais o pacote `isc-dhcp44-server`.
- **Aplicações:** `pf` (NAT, DNAT, firewall), ISC `dhcpd` (DHCP), `sysctl`/`gateway_enable` (roteamento), `syslogd` (log do DHCP), `nc` e `telnet` (teste do DNAT), `ping`, `nslookup`/`host`, `pfctl`, `tcpdump`.
- **Como implementar:** seções 6 e 7 deste README.
- **Como validar:** seção 8 deste README.
- **Limitações conhecidas:**
  - Apenas IPv4.
  - Um único IP de WAN compartilhado pela LAN (NAT muitos-para-um).
  - O bloqueio de ICMP cobre só o ping (echo-request).
  - Entrada pela WAN negada, exceto DNAT, DHCP e ping ao roteador (SSH pela WAN precisa de regra extra).
  - A porta 8080 do cliente fica acessível a quem alcança o `10.10.0.100` pela WAN, por causa da regra de liberação do DNAT.
  - O servidor DHCP é um pacote e exige internet para instalar; o ISC encerrou o desenvolvimento do ISC DHCP em favor do Kea.
  - A detecção automática é uma heurística: com mais de duas placas ou cabos em posições incomuns pode errar (nesse caso force as placas no `config.sh`).
  - Um IP fixo de WAN, se o laboratório não usar DHCP, não pode ser detectado.
  - Exige hardware real com duas interfaces de rede (virtualização não é admitida).
  - Os scripts foram escritos para FreeBSD.
