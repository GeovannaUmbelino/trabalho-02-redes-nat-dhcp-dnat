#!/bin/sh
# 03-pf.sh - firewall pf: NAT + DNAT + isolamento da WAN + bloqueio de ping
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/lib/common.sh"
need_root; need_freebsd
need_iface "$WAN_IF"; need_iface "$LAN_IF"

echo "=== 03-pf: NAT + DNAT ($DNAT_PUBLIC_PORT -> $DNAT_TARGET_IP:$DNAT_TARGET_PORT) + firewall ==="
kldload pf >/dev/null 2>&1
kldload pflog >/dev/null 2>&1
backup_once /etc/pf.conf

# tenta a sintaxe classica; se o pf do sistema recusar, tenta a nova (nat-to/rdr-to)
chosen=""
for t in pf.conf.tpl pf.conf.nat-to.tpl; do
  render "$ROOT/templates/$t" /tmp/pf.conf.novo
  if err=$(pfctl -nf /tmp/pf.conf.novo 2>&1); then
    chosen=$t
    break
  fi
  echo "--- $t foi recusado pelo pf:"
  echo "$err"
done
[ -n "$chosen" ] || die "nenhuma versao do pf.conf passou na validacao (nada foi aplicado). Mande a mensagem acima."

cp /tmp/pf.conf.novo /etc/pf.conf
good "pf.conf validado ($chosen) e instalado em /etc/pf.conf"

sysrc pf_enable=YES >/dev/null
service pf start >/dev/null 2>&1
pfctl -f /etc/pf.conf || die "falha ao carregar /etc/pf.conf"
pfctl -e >/dev/null 2>&1
pfctl -si 2>/dev/null | grep -q 'Status: Enabled' || die "pf nao ficou habilitado"
good "pf habilitado e regras carregadas"

sysctl net.inet.ip.forwarding=1 >/dev/null
sysrc gateway_enable=YES >/dev/null

echo "--- NAT / DNAT carregados ---"
pfctl -sn 2>/dev/null
exit 0
