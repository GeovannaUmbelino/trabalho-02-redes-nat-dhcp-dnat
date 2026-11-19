#!/bin/sh
# 00-detectar.sh - descobre sozinho: placa WAN, placa LAN, modo da WAN e DNS.
# Grava o resultado em config.auto (nao precisa editar nada).
ROOT=$(cd "$(dirname "$0")/.." && pwd)
T2_NO_AUTODETECT=1
export T2_NO_AUTODETECT
. "$ROOT/lib/common.sh"
old_mac=${AUTO_STATIC_HOST_MAC:-}
. "$ROOT/config.sh"            # valores do usuario ("auto" ou forcados)
need_root; need_freebsd

echo "=== 00-detectar: descobrindo placas, modo da WAN e DNS ==="
pfx=$(echo "$LAN_NETADDR" | cut -d. -f1-2)

has_ip()  { ifconfig "$1" 2>/dev/null | grep -q 'inet '; }
ip_of()   { ifconfig "$1" 2>/dev/null | awk '$1=="inet"{print $2; exit}'; }
link_up() { ifconfig "$1" 2>/dev/null | grep -q 'status: active'; }
dns_ok() {
  if command -v host >/dev/null 2>&1; then
    timeout 5 host unb.br "$1" 2>/dev/null | grep -q 'has address'
  else
    timeout 5 drill unb.br "@$1" 2>/dev/null | grep -q 'ANSWER SECTION'
  fi
}

# placas Ethernet fisicas (ignora loopback, pf, bridge, wlan, tuneis...)
candidatas() {
  _wl=$(sysctl -n net.wlan.devices 2>/dev/null)
  for _i in $(ifconfig -l); do
    case "$_i" in
      lo[0-9]*|pflog*|pfsync*|enc*|wlan*|bridge*|tap*|tun*|epair*|vlan*|gif*|gre*|stf*|ng*|lagg*|disc*|ipfw*) continue ;;
    esac
    _skip=0
    for _w in $_wl; do if [ "$_i" = "$_w" ]; then _skip=1; fi; done
    if [ "$_skip" = 1 ]; then continue; fi
    ifconfig "$_i" 2>/dev/null | grep -q 'ether ' || continue
    echo "$_i"
  done
}

CANDS=$(candidatas)
n=$(echo "$CANDS" | grep -c .)
if [ "$n" -lt 2 ]; then
  log "achei $n placa(s); tentando carregar drivers de adaptador USB-Ethernet..."
  for d in if_ure if_axge if_cdce if_axe if_smsc if_muge if_aue; do kldload "$d" >/dev/null 2>&1; done
  sleep 4
  CANDS=$(candidatas)
  n=$(echo "$CANDS" | grep -c .)
fi
[ "$n" -ge 2 ] || die "preciso de 2 placas de rede (WAN e LAN) e achei: $(echo $CANDS). Plugue o adaptador USB-Ethernet e rode de novo (veja: ifconfig -l)"

W=$WAN_IF; L=$LAN_IF; M=$WAN_MODE; D=$DNS_SERVER

# ---- placas ----
if [ "$W" != "auto" ]; then need_iface "$W"; fi
if [ "$L" != "auto" ]; then need_iface "$L"; fi

if [ "$L" = "auto" ]; then            # 1) placa que ja tem IP da LAN
  for i in $CANDS; do
    if [ "$i" != "$W" ] && ifconfig "$i" | grep -q "inet ${pfx}\."; then L=$i; break; fi
  done
fi
if [ "$W" = "auto" ]; then            # 2) placa da rota default
  dif=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
  if [ -n "$dif" ] && [ "$dif" != "$L" ] && echo "$CANDS" | grep -qx "$dif"; then W=$dif; fi
fi
if [ "$W" = "auto" ]; then            # 3) placa com IP (fora da LAN) e cabo
  for i in $CANDS; do
    if [ "$i" != "$L" ] && has_ip "$i" && link_up "$i" && ! ifconfig "$i" | grep -q "inet ${pfx}\."; then W=$i; break; fi
  done
fi
if [ "$W" = "auto" ]; then            # 4) adaptador USB (ue*)
  for i in $CANDS; do
    case "$i" in ue*) if [ "$i" != "$L" ]; then W=$i; break; fi ;; esac
  done
fi
if [ "$W" = "auto" ]; then            # 5) primeira com cabo; senao primeira
  for i in $CANDS; do if [ "$i" != "$L" ] && link_up "$i"; then W=$i; break; fi; done
fi
if [ "$W" = "auto" ]; then
  for i in $CANDS; do if [ "$i" != "$L" ]; then W=$i; break; fi; done
fi
if [ "$L" = "auto" ]; then            # LAN = outra placa (preferindo a com cabo)
  for i in $CANDS; do if [ "$i" != "$W" ] && link_up "$i"; then L=$i; break; fi; done
fi
if [ "$L" = "auto" ]; then
  for i in $CANDS; do if [ "$i" != "$W" ]; then L=$i; break; fi; done
fi
[ -n "$W" ] && [ -n "$L" ] && [ "$W" != "$L" ] || die "nao consegui separar WAN e LAN (placas: $(echo $CANDS))"

# ---- modo da WAN ----
if [ "$M" = "auto" ]; then
  cur=$(sysrc -n "ifconfig_${W}" 2>/dev/null)
  case "$cur" in *DHCP*) M=dhcp ;; esac
fi
if [ "$M" = "auto" ]; then
  if has_ip "$W"; then
    if pgrep -f "dhclient.*${W}" >/dev/null 2>&1 || [ -s "/var/db/dhclient.leases.${W}" ]; then M=dhcp; else M=keep; fi
  else
    M=dhcp
  fi
fi
if [ "$M" = "dhcp" ] && ! has_ip "$W"; then
  link_up "$W" || warn "WAN $W sem cabo (no carrier): ligue o cabo do laboratorio"
  log "WAN $W sem IP: pedindo por DHCP (ate 45s)..."
  timeout 45 dhclient "$W" >/dev/null 2>&1
  sleep 1
  has_ip "$W" || die "a WAN ($W) nao recebeu IP por DHCP. Se o professor passou IP fixo: nano config.sh e preencha WAN_MODE=\"static\", WAN_IP e WAN_GW (so isso). Se nao: confira o cabo do laboratorio em $W."
fi

# ---- DNS ----
if [ "$D" = "auto" ]; then
  if [ "$M" = "static" ]; then
    D=164.41.101.4
    warn "WAN_MODE=static: DNS nao testado agora; usando $D (confira no teste 01)"
  else
    gw=$(route -n get default 2>/dev/null | awk '/gateway:/{print $2}')
    for c in 164.41.101.4 164.41.101.11 $gw; do
      [ -n "$c" ] || continue
      log "testando DNS $c ..."
      if dns_ok "$c"; then D=$c; break; fi
    done
    if [ "$D" = "auto" ]; then
      D=164.41.101.4
      warn "nenhum DNS respondeu agora; usando $D (o enunciado permite). Confira no teste 01."
    fi
  fi
fi

# ---- grava config.auto ----
{
  echo "# gerado por scripts/00-detectar.sh em $(date)"
  printf 'AUTO_WAN_IF="%s"\n' "$W"
  printf 'AUTO_LAN_IF="%s"\n' "$L"
  printf 'AUTO_WAN_MODE="%s"\n' "$M"
  printf 'AUTO_DNS_SERVER="%s"\n' "$D"
  if [ -n "$old_mac" ]; then printf 'AUTO_STATIC_HOST_MAC="%s"\n' "$old_mac"; fi
} > "$ROOT/config.auto"

echo "--- detectado ---"
echo "WAN : $W  (IP $(ip_of "$W"))  modo: $M"
echo "LAN : $L  (sera $LAN_IP/$LAN_MASK)"
echo "DNS : $D"
if [ -n "$old_mac" ]; then echo "MAC do cliente (IP fixo): $old_mac"; else echo "MAC do cliente (IP fixo): sera descoberto quando o cliente pedir IP"; fi
good "deteccao concluida (salva em config.auto)"
exit 0
