#!/bin/bash
# TA2BI - Wi-Fi bekcisi: USB Wi-Fi dongle (ornegin RTL8192CU) kopunca hizli toparlanir.
#
# 20 saniyede bir agin geciti (gateway) ping'lenir. Ust uste basarisizlikta kademeli onarim:
#   2 basarisiz (~40 sn)  : wpa_cli reassociate
#   4 basarisiz (~80 sn)  : arayuz kapat/ac + wpa_cli reconfigure
#   6 basarisiz (~2 dk)   : dongle USB'den cikarilip takilmis gibi sifirlanir (unbind/bind)
#   sonra her 6 basarisizlikta USB sifirlama tekrarlanir
# Kablolu (eth0) varsayilan rota ise hicbir sey yapmaz.
#   --test-usb : yalnizca USB sifirlamayi dener (SSH birkac saniye kopar)
#   --dry      : karar mantigini yazar, hicbir sey yapmaz
IFACE=${IFACE:-wlan0}
ARALIK=${ARALIK:-20}
log() { logger -t ta2bi-wifi "$*"; echo "$*"; }

usb_sifirla() {
  local dev
  dev=$(basename "$(dirname "$(readlink -f /sys/class/net/$IFACE/device 2>/dev/null)")" 2>/dev/null)
  if [ -z "$dev" ] || [ ! -e "/sys/bus/usb/devices/$dev" ]; then log "$IFACE USB aygiti bulunamadi"; return 1; fi
  log "USB dongle sifirlaniyor ($dev)"
  echo "$dev" > /sys/bus/usb/drivers/usb/unbind 2>/dev/null
  sleep 3
  echo "$dev" > /sys/bus/usb/drivers/usb/bind 2>/dev/null
  sleep 10
  systemctl restart wpa_supplicant@$IFACE 2>/dev/null || wpa_cli -i "$IFACE" reconfigure >/dev/null 2>&1
}

[ "$1" = "--test-usb" ] && { usb_sifirla; exit $?; }
DRY=0; [ "$1" = "--dry" ] && DRY=1

hata=0
while true; do
  if ip route show default 2>/dev/null | grep -q ' dev eth0 '; then hata=0; sleep "$ARALIK"; [ "$DRY" = 1 ] && { echo "eth0 varsayilan rota: bekci pasif"; exit 0; }; continue; fi
  gw=$(ip route show default dev "$IFACE" 2>/dev/null | awk '{print $3; exit}')
  if [ -n "$gw" ] && ping -I "$IFACE" -c 1 -W 3 "$gw" >/dev/null 2>&1; then
    [ "$hata" -ge 2 ] && log "$IFACE yeniden baglandi ($hata basarisiz denemeden sonra)"
    hata=0
  else
    hata=$((hata + 1))
    if [ "$DRY" = 1 ]; then echo "basarisiz $hata (gw=${gw:-yok})"; [ "$hata" -ge 6 ] && exit 0; sleep 1; continue; fi
    case $((hata % 6)) in
      2) log "$IFACE yanit vermiyor: reassociate"; wpa_cli -i "$IFACE" reassociate >/dev/null 2>&1 ;;
      4) log "$IFACE yanit vermiyor: arayuz yeniden aciliyor"; ip link set "$IFACE" down; sleep 2; ip link set "$IFACE" up; wpa_cli -i "$IFACE" reconfigure >/dev/null 2>&1 ;;
      0) log "$IFACE yanit vermiyor: USB sifirlama"; usb_sifirla ;;
    esac
  fi
  sleep "$ARALIK"
done
