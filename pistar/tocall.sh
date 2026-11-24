#!/bin/bash
# TA2BI - YSFGateway'in APRS "tocall" (hedef kodu) degerini degistirir (root olarak calistirilir).
#
#   sudo bash tocall.sh AP2BIG          # yeni tocall (6 karakter, AP ile baslar)
#   sudo bash tocall.sh APDG03          # eski haline dondurur
#
# YSFGateway her APRS konum paketini sabit "APDG03" ile gonderir. aprs.fi bu kodu cihaz listesinde
# arayip "Jonathan, G4KLX ircDDB Gateway" gosterir. Bu betik programdaki 6 karakterlik yaziyi ayni
# uzunlukta degistirir. Eski dosya /usr/local/bin/YSFGateway.orig-APDG03 olarak saklanir.
# Kendi kodunuzun aprs.fi'de ozel adla gorunmesi icin kodu https://github.com/aprsorg/aprs-deviceid
# deposuna kaydettirmek gerekir; kayit olmadan "bilinmeyen cihaz" gorunur.
# Pi-Star guncellemesi YSFGateway'i degistirirse betigi yeniden calistirin.
set -e
NEW="$1"
BIN=/usr/local/bin/YSFGateway
[ "$(id -u)" = 0 ] || { echo "root olarak calistirin"; exit 1; }
[[ "$NEW" =~ ^AP[A-Z0-9]{4}$ ]] || { echo "Kullanim: sudo bash $0 APxxxx   (6 karakter, buyuk harf/rakam, AP ile baslar)"; exit 1; }
[ -f "$BIN" ] || { echo "$BIN yok"; exit 1; }

CUR=$(grep -aoE '%s>AP[A-Z0-9]{4},TCPIP' "$BIN" | head -1 | cut -c4-9)
[ -n "$CUR" ] || { echo "Mevcut tocall bulunamadi"; exit 1; }
[ "$CUR" = "$NEW" ] && { echo "Zaten $NEW"; exit 0; }
[ "$(grep -aoE "%s>$CUR,TCPIP" "$BIN" | wc -l)" = 1 ] || { echo "Beklenmeyen: $CUR birden fazla yerde"; exit 1; }

RO=0
if grep -qE '^\S+ / \S+ ro[ ,]' /proc/mounts; then RO=1; mount -o remount,rw /; fi
[ -e "$BIN.orig-APDG03" ] || cp -p "$BIN" "$BIN.orig-APDG03"
OFS=$(grep -obUaE "%s>$CUR,TCPIP" "$BIN" | head -1 | cut -d: -f1)
OFS=$((OFS + 3))                       # "%s>" atlanir
systemctl stop ysfgateway 2>/dev/null || true
cp -p "$BIN" /tmp/YSFGateway.new
printf '%s' "$NEW" | dd of=/tmp/YSFGateway.new bs=1 seek="$OFS" conv=notrunc 2>/dev/null
grep -aq "%s>$NEW,TCPIP" /tmp/YSFGateway.new || { echo "YAMA BASARISIZ, dosya degismedi"; systemctl start ysfgateway; exit 1; }
install -m 755 -o root -g bin /tmp/YSFGateway.new "$BIN"
rm -f /tmp/YSFGateway.new
sync
[ "$RO" = 1 ] && mount -o remount,ro / 2>/dev/null || true
systemctl start ysfgateway
sleep 3
printf 'ysfgateway: '; systemctl is-active ysfgateway || true
echo "tocall: $CUR -> $NEW (bir sonraki APRS paketinde gecerli olur)"
