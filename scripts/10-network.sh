#!/bin/sh
# [Modulo 1] Interfaces WAN/LAN (via /etc/rc.conf) + habilita roteamento IPv4.
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd); . "$ROOT_DIR/lib/common.sh"
require_root; require_freebsd; require_iface "$WAN_IF"; require_iface "$LAN_IF"
backup_once /etc/rc.conf

log "LAN: $LAN_IF = $LAN_GW_IP/$LAN_PREFIX"
sysrc "ifconfig_${LAN_IF}=inet $LAN_GW_IP netmask $LAN_MASK"
service netif restart "$LAN_IF"

case "$WAN_MODE" in
  dhcp)
    log "WAN: $WAN_IF via DHCP"
    sysrc "ifconfig_${WAN_IF}=SYNCDHCP"
    service netif restart "$WAN_IF" ;;
  static)
    log "WAN: $WAN_IF = $WAN_IP (gw $WAN_GW)"
    sysrc "ifconfig_${WAN_IF}=inet $WAN_IP netmask $WAN_MASK"
    sysrc "defaultrouter=$WAN_GW"
    service netif restart "$WAN_IF"
    service routing restart ;;
  keep) log "WAN: mantendo configuração atual de $WAN_IF" ;;
  *) die "WAN_MODE inválido: $WAN_MODE (use dhcp|static|keep)" ;;
esac

log "Habilitando forwarding IPv4 (agora e no boot)"
sysrc gateway_enable=YES
sysctl net.inet.ip.forwarding=1
