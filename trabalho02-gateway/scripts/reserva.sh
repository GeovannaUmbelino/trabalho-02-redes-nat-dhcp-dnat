#!/bin/sh
# reserva.sh - reserva o IP fixo (10.10.0.100) para o MAC do cliente da LAN.
#   sh scripts/reserva.sh            -> AUTOMATICO: espera o cliente pedir IP e pega o MAC sozinho
#   sh scripts/reserva.sh aa:bb:..   -> manual, com o MAC informado
#   sh scripts/reserva.sh --listar   -> so mostra o MAC que seria escolhido
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/lib/common.sh"
need_root; need_freebsd
LEASES=${LEASES:-/var/db/dhcpd/dhcpd.leases}
LOG=${LOG:-/var/log/dhcpd.log}
ESPERA=${ESPERA:-180}

mac_lease() { awk '/hardware ethernet/{m=$3; sub(";","",m)} END{print m}' "$LEASES" 2>/dev/null; }
mac_log()   { awk '/DHCPDISCOVER|DHCPREQUEST/{for(i=1;i<=NF;i++) if($i=="from") m=$(i+1)} END{print m}' "$LOG" 2>/dev/null; }
mac_arp()   { arp -an 2>/dev/null | awk -v lan="$LAN_IF" -v ip="$LAN_IP" '$6==lan{x=$2; gsub(/[()]/,"",x); if(x!=ip && $4 ~ /^[0-9a-f:]+$/) print $4}' | head -1; }
achar_mac() {
  m=$(mac_lease); if [ -n "$m" ]; then echo "$m"; return; fi
  m=$(mac_log);   if [ -n "$m" ]; then echo "$m"; return; fi
  mac_arp
}
mac_valido() { echo "$1" | grep -Eq '^[0-9a-f]{2}(:[0-9a-f]{2}){5}$'; }

case "$1" in
  --listar)
    echo "lease: $(mac_lease)"; echo "log:   $(mac_log)"; echo "arp:   $(mac_arp)"
    echo "escolhido: $(achar_mac)"
    exit 0 ;;
  "")
    mac=""; n=0
    while [ "$n" -lt "$ESPERA" ]; do
      mac=$(achar_mac)
      if [ -n "$mac" ]; then break; fi
      if [ $((n % 15)) -eq 0 ]; then
        log "aguardando o cliente da LAN pedir IP (ligue o cabo e renove o IP no cliente)... ${n}s de ${ESPERA}s"
      fi
      sleep 3; n=$((n+3))
    done
    [ -n "$mac" ] || { warn "nenhum cliente apareceu. Depois que ele pedir IP, rode: sh scripts/reserva.sh"; exit 1; }
    good "cliente encontrado: $mac"
    ;;
  *) mac=$(echo "$1" | tr 'A-F-' 'a-f:') ;;
esac

mac_valido "$mac" || die "MAC invalido: '$mac' (formato aa:bb:cc:dd:ee:ff)"

setauto AUTO_STATIC_HOST_MAC "$mac"
# se o MAC tiver sido forcado em config.sh, atualiza la tambem
case "$(grep '^STATIC_HOST_MAC=' "$ROOT/config.sh")" in
  *'"auto"'*) ;;
  *) sed "s|^STATIC_HOST_MAC=.*|STATIC_HOST_MAC=\"$mac\"|" "$ROOT/config.sh" > "$ROOT/config.sh.novo" && mv "$ROOT/config.sh.novo" "$ROOT/config.sh" ;;
esac
good "MAC gravado: $mac -> $STATIC_HOST_IP"

antes=$(wc -l < "$LOG" 2>/dev/null | tr -d ' ')
[ -n "$antes" ] || antes=0
sh "$ROOT/scripts/02-dhcp.sh" || exit 1
echo "--- reserva no dhcpd.conf ---"
grep -A3 "host $STATIC_HOST_NAME" /usr/local/etc/dhcpd.conf
echo
echo ">>> AGORA, NO CLIENTE: libere e renove o IP (Windows: ipconfig /release  e  ipconfig /renew)."
echo ">>> Esperado: $STATIC_HOST_IP"
n=0; visto=0
while [ "$n" -lt "$ESPERA" ]; do
  if tail -n +$((antes+1)) "$LOG" 2>/dev/null | grep -q "DHCPACK on $STATIC_HOST_IP "; then visto=1; break; fi
  if [ $((n % 15)) -eq 0 ]; then log "aguardando o cliente pegar $STATIC_HOST_IP ... ${n}s de ${ESPERA}s"; fi
  sleep 3; n=$((n+3))
done
if [ "$visto" = 1 ]; then
  good "o cliente recebeu o IP fixo $STATIC_HOST_IP (confirmado no log)"
else
  warn "nao vi o cliente receber $STATIC_HOST_IP ainda. Renove o IP no cliente e confira: tail -20 $LOG"
fi
exit 0
