# Divisão de Tarefas da Equipe – Trabalho 02 (NAT + DHCP + DNAT)

Fundamentos de Redes de Computadores – UnB Gama – Prof. Tiago Alves

---

## 1. Integrantes da Equipe

| Nome do Integrante | Matrícula | Módulo / Responsabilidade Principal |
|---|---|---|
| `<Nome do Integrante 1>` | `<Matrícula 1>` | Módulo 1: Interfaces, Roteamento e NAT |
| `<Nome do Integrante 2>` | `<Matrícula 2>` | Módulo 2: Servidor DHCP e Logging |
| `<Nome do Integrante 3>` | `<Matrícula 3>` | Módulo 3: DNAT, Firewall ICMP e Isolamento |
| `<Nome do Integrante 4 / Opcional>` | `<Matrícula 4>` | Testes de Clientes, Validação e Documentação |

---

## 2. Atribuição de Módulos e Componentes

### Módulo 1: Interfaces de Rede, Roteamento e NAT
- **Responsável:** `<Nome do Integrante 1>`
- **Artefatos sob responsabilidade:**
  - `config/gateway.conf` (Parâmetros de rede: `WAN_IF`, `LAN_IF`, `WAN_MODE`, `LAN_NET`, `LAN_GW_IP`)
  - `scripts/10-network.sh` (Configuração de IP das interfaces no `rc.conf` e habilitação do `sysctl net.inet.ip.forwarding`)
  - `scripts/20-nat.sh` e `templates/pf/10-nat.conf.tpl` (Regra de tradução de endereços NAT muitos-para-um)
  - `tests/router/01-connectivity.sh` (Validação de IP, rota default e conectividade da WAN)
  - `tests/router/02-nat.sh` (Validação de regras ativas e tabela de estados do PF)

---

### Módulo 2: Serviço de DHCP e Registro de Concessões (Logs)
- **Responsável:** `<Nome do Integrante 2>`
- **Artefatos sob responsabilidade:**
  - `templates/dhcpd.conf.tpl` (Definição de faixa de endereços, gateway, máscara, DNS e reserva de IP fixo por MAC)
  - `scripts/30-dhcp.sh` (Instalação do pacote `isc-dhcp44-server`, inicialização do daemon e criação da infraestrutura de leases)
  - Configuração do `syslogd` (`/etc/syslog.d/dhcpd.conf` direcionando `local7.*` para `/var/log/dhcpd.log`)
  - `tests/router/04-dhcp.sh` (Verificação de status do serviço, leases ativos e histórico de requisições)

---

### Módulo 3: DNAT, Firewall ICMP e Isolamento de Segmento
- **Responsável:** `<Nome do Integrante 3>`
- **Artefatos sob responsabilidade:**
  - `templates/pf/20-rdr.conf.tpl` e `40-dnat-pass.conf.tpl` (Redirecionamento de porta WAN:80 → LAN:8080)
  - `templates/pf/30-isolamento.conf.tpl` (Política de isolamento: bloqueio de conexões de entrada arbitrárias pela WAN)
  - `templates/pf/50-icmp.conf.tpl` (Regra `block in quick` para pacotes ICMP echo-request com destino externo)
  - `scripts/40-dnat.sh` e `scripts/50-firewall.sh`
  - `tests/router/03-isolation.sh`, `05-dnat.sh` e `06-icmp.sh`

---

### Módulo 4: Validação de Clientes, Ensaio Prático e Documentação
- **Responsável:** `<Nome do Integrante 4 ou Todos os Membros>`
- **Artefatos sob responsabilidade:**
  - `tests/client/lan-client.sh` (Validação no cliente LAN: ping gateway OK, DNS/NAT OK, ping fora bloqueado)
  - `tests/client/wan-client.sh` (Validação no host WAN: DNAT funcional e isolamento contra tráfego direto à LAN)
  - `docs/DOCUMENTACAO.md` e `docs/evidencias/README.md` (Compilação do relatório técnico e evidências de teste)
  - Procedimento de empacotamento ZIP final para submissão no SIGAA/Teams.

---

## 3. Checklist Conjunto para o Ensaio e Apresentação (LDS)

- [ ] Instalação limpa do FreeBSD no notebook físico (sem VM).
- [ ] Conexão e identificação dos adaptadores de rede (`ifconfig -l`).
- [ ] Ajuste de `config/gateway.conf` com os dados do laboratório e MAC da máquina de teste.
- [ ] Execução do setup completo: `sh scripts/setup.sh`.
- [ ] Execução dos testes automatizados no roteador: `sh tests/run-all.sh`.
- [ ] Demonstração do cliente LAN (DHCP recebido, IP fixo e ping bloqueado para fora).
- [ ] Demonstração do DNAT via `nc -l 8080` (LAN) e `telnet WAN_IP 80` (WAN).
