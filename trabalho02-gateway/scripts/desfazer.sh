#!/bin/sh
# desfazer.sh - desliga pf/dhcpd e restaura os arquivos originais (*.pre-t2)
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/lib/common.sh"
need_root; need_freebsd
service isc-dhcpd stop >/dev/null 2>&1
service pf stop >/dev/null 2>&1
if [ -e /etc/pf.conf.pre-t2 ]; then cp -p /etc/pf.conf.pre-t2 /etc/pf.conf; else rm -f /etc/pf.conf; fi
if [ -e /usr/local/etc/dhcpd.conf.pre-t2 ]; then cp -p /usr/local/etc/dhcpd.conf.pre-t2 /usr/local/etc/dhcpd.conf; else rm -f /usr/local/etc/dhcpd.conf; fi
rm -f /etc/syslog.d/dhcpd.conf
sysrc -x pf_enable dhcpd_enable dhcpd_ifaces gateway_enable "ifconfig_${LAN_IF}" >/dev/null 2>&1
ifconfig "$LAN_IF" inet "$LAN_IP" -alias >/dev/null 2>&1
sysctl net.inet.ip.forwarding=0 >/dev/null
rm -f "$ROOT/config.auto"
good "desfeito (a WAN $WAN_IF nao foi alterada; a deteccao sera refeita na proxima ativacao)"
