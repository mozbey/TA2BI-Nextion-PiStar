#!/bin/bash
# TA2BI - Pi-Star guncellemesi/"Apply" sonrasi ayarlari ve yamalari geri yukler.
#
# Pi-Star'in "Update" dugmesi /usr/local/bin (NextionDriver, YSFGateway ...) icin 'git pull' / 'reset --hard'
# calistirir; panelde "Apply" ise /etc/mmdvmhost ve /etc/ysfgateway dosyalarini yeniden yazabilir.
# Bu betik timer ile 10 dakikada bir calisir ve bozulan seyleri onarir:
#   1) /usr/local/bin/NextionDriver  -> /opt/ta2bi/yedek/NextionDriver (yamali surum)
#   2) YSFGateway tocall (APDG03 -> TOCALL)
#   3) /etc/mmdvmhost [NextionDriver] Port ve [Nextion] Port
#   4) /etc/ysfgateway [APRS] Description (yalnizca DESC tanimliysa)
# Ayarlar: /etc/default/ta2bi-yama   (PORT=/dev/ttyUSB0  TOCALL=AP2BIG  DESC="TA2BI Hotspot&Nextion")
PORT=/dev/ttyUSB0
TOCALL=AP2BIG
DESC=""
[ -r /etc/default/ta2bi-yama ] && . /etc/default/ta2bi-yama
YEDEK=/opt/ta2bi/yedek
log() { logger -t ta2bi-yama "$*"; echo "$*"; }

[ "$(id -u)" = 0 ] || exit 1
exec 9>/var/lock/ta2bi-yama.lock; flock -n 9 || exit 0
# Pi-Star guncellemesi sirasindaysa dokunma
flock -n /var/lock/pistar-update.lock true 2>/dev/null || exit 0

RO=0; DEGISTI=0
rw() { if [ "$RO" = 0 ] && grep -qE '^\S+ / \S+ ro[ ,]' /proc/mounts; then RO=1; mount -o remount,rw /; fi; }

# 1) NextionDriver yamali surum
if [ -f "$YEDEK/NextionDriver" ] && ! cmp -s "$YEDEK/NextionDriver" /usr/local/bin/NextionDriver; then
  rw
  cp -p /usr/local/bin/NextionDriver "$YEDEK/NextionDriver.upstream-$(date +%Y%m%d%H%M)" 2>/dev/null || true
  install -m 755 -o root -g bin "$YEDEK/NextionDriver" /usr/local/bin/NextionDriver
  log "NextionDriver yamali surume geri alindi"; DEGISTI=1
fi

# 2) tocall
if ! { grep -aq ">$TOCALL,TCPIP" /usr/local/bin/YSFGateway 2>/dev/null && grep -aq ">$TOCALL,C4FM" /usr/local/bin/YSFGateway 2>/dev/null; } && [ -x /opt/ta2bi/tocall.sh ]; then
  rw
  /opt/ta2bi/tocall.sh "$TOCALL" >/dev/null 2>&1 && log "YSFGateway tocall $TOCALL olarak geri yuklendi"
fi

# 3) NextionDriver portlari
ini_oku() { awk -v s="[$1]" -v k="$2" -F= '$0==s{b=1;next} /^\[/{b=0} b&&$1==k{print $2; exit}' /etc/mmdvmhost | tr -d '\r \t'; }
if [ -n "$PORT" ] && [ -e "$PORT" ]; then
  if [ "$(ini_oku NextionDriver Port)" != "$PORT" ] || [ "$(ini_oku Nextion Port)" != "/dev/ttyNextionDriver" ]; then
    rw
    sed -i '/^[[]Nextion[]]/,/^[[]/ s#^Port=.*#Port=/dev/ttyNextionDriver#' /etc/mmdvmhost
    sed -i '/^[[]NextionDriver[]]/,/^[[]/ s#^Port=.*#Port='"$PORT"'#' /etc/mmdvmhost
    log "/etc/mmdvmhost portlari geri yuklendi"; DEGISTI=1
  fi
fi

# 4) APRS aciklamasi
if [ -n "$DESC" ] && [ -f /etc/ysfgateway ]; then
  MEVCUT=$(awk '/^\[APRS\]/{b=1;next} /^\[/{b=0} b&&/^Description=/{sub(/^Description=/,""); print; exit}' /etc/ysfgateway)
  if [ "$MEVCUT" != "$DESC" ]; then
    rw
    ESC=$(printf '%s' "$DESC" | sed 's/[&|\\]/\\&/g')
    sed -i '/^[[]APRS[]]/,/^[[]/ s|^Description=.*|Description='"$ESC"'|' /etc/ysfgateway
    systemctl restart ysfgateway 2>/dev/null
    log "APRS aciklamasi geri yuklendi"
  fi
fi

if [ "$DEGISTI" = 1 ]; then
  sync
  systemctl reset-failed nextiondriver 2>/dev/null
  systemctl restart nextiondriver; sleep 8
  systemctl restart mmdvmhost; sleep 6
  systemctl restart tgekran 2>/dev/null
fi
[ "$RO" = 1 ] && { sync; mount -o remount,ro / 2>/dev/null || true; }
exit 0
