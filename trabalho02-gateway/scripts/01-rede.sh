#!/bin/sh
# 01-rede.sh - IP da LAN, WAN e roteamento (forwarding)
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/lib/common.sh"
need_root; need_freebsd
need_iface "$WAN_IF"; need_iface "$LAN_IF"
[ "$WAN_IF" != "$LAN_IF" ] || die "WAN_IF e LAN_IF nao podem ser a mesma placa"
backup_once /etc/rc.conf

echo "=== 01-rede: LAN $LAN_IF=$LAN_IP  WAN $WAN_IF (modo $WAN_MODE) ==="

# ---- LAN ----
sysrc "ifconfig_${LAN_IF}=inet ${LAN_IP} netmask ${LAN_MASK}" >/dev/null
# remove qualquer outro IPv4 que tenha ficado na placa da LAN
for a in $(ifconfig "$LAN_IF" | awk '$1=="inet"{print $2}'); do
  if [ "$a" != "$LAN_IP" ]; then
    log "removendo IP antigo $a de $LAN_IF"
    ifconfig "$LAN_IF" inet "$a" -alias
  fi
done
ifconfig "$LAN_IF" inet "$LAN_IP" netmask "$LAN_MASK" up
good "LAN $LAN_IF = $LAN_IP/$LAN_MASK"

# ---- WAN ----
case "$WAN_MODE" in
  dhcp)
    cur=$(sysrc -n "ifconfig_${WAN_IF}" 2>/dev/null)
    case "$cur" in
      *DHCP*) ;;
      *) sysrc "ifconfig_${WAN_IF}=SYNCDHCP" >/dev/null ;;
    esac
    sysrc -x defaultrouter >/dev/null 2>&1
    if ! ifconfig "$WAN_IF" | grep -q 'inet '; then
      log "WAN sem IP: pedindo por DHCP (dhclient)"
      dhclient "$WAN_IF"
    fi
    ;;
  static)
    is_ipv4 "$WAN_IP" || die "WAN_IP invalido em config.sh: '$WAN_IP' (use numeros reais, sem letras)"
    is_ipv4 "$WAN_GW" || die "WAN_GW invalido em config.sh: '$WAN_GW'"
    sysrc "ifconfig_${WAN_IF}=inet ${WAN_IP} netmask ${WAN_MASK}" >/dev/null
    sysrc "defaultrouter=${WAN_GW}" >/dev/null
    for a in $(ifconfig "$WAN_IF" | awk '$1=="inet"{print $2}'); do
      if [ "$a" != "$WAN_IP" ]; then ifconfig "$WAN_IF" inet "$a" -alias; fi
    done
    ifconfig "$WAN_IF" inet "$WAN_IP" netmask "$WAN_MASK" up
    route -n delete default >/dev/null 2>&1
    route -n add default "$WAN_GW" >/dev/null
    ;;
  keep) log "WAN_MODE=keep: WAN nao alterada" ;;
  *) die "WAN_MODE invalido: '$WAN_MODE' (use dhcp, static ou keep)" ;;
esac

# ---- Roteamento ----
sysrc gateway_enable=YES >/dev/null
sysctl net.inet.ip.forwarding=1 >/dev/null
good "forwarding ligado (net.inet.ip.forwarding=1)"

echo "--- resumo ---"
ifconfig "$WAN_IF" | grep -E 'inet |status'
ifconfig "$LAN_IF" | grep -E 'inet |status'
netstat -rn -f inet | grep '^default' || warn "sem rota default (a WAN pegou IP e gateway?)"
ifconfig "$WAN_IF" | grep -q 'inet ' || warn "a WAN ($WAN_IF) ainda nao tem IP"
ifconfig "$LAN_IF" | grep -q 'status: active' || warn "LAN ($LAN_IF) sem cabo (no carrier): ligue o cabo no cliente/switch"
exit 0
