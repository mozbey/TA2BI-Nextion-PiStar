#!/bin/bash
# TA2BI - YSFGateway'in APRS "tocall" (hedef kodu) degerini degistirir (root olarak calistirilir).
#
#   sudo bash tocall.sh AP2BIG       # yeni tocall (6 karakter, AP ile baslar)
#   sudo bash tocall.sh --geri       # ilk haline (APDG03 / APDPRS) dondurur
#
# YSFGateway iki tur APRS paketi gonderir ve ikisinde de tocall sabittir:
#   %s>APDG03,TCPIP*,qAC,...     istasyon (gateway) konum paketi
#   %s>APDPRS,C4FM*,qAR,...      telsiz konum paketi ("... via MMDVM")
# aprs.fi bu kodlari cihaz listesinde arar. Betik ikisini de ayni uzunlukta degistirir.
# Ilk degisiklikten once /usr/local/bin/YSFGateway.orig-APDG03 yedeklenir.
# Kendi kodunuzun aprs.fi'de ozel adla gorunmesi icin kodu https://github.com/aprsorg/aprs-deviceid
# deposuna kaydettirmek gerekir. Pi-Star guncellemesi YSFGateway'i degistirirse betigi yeniden calistirin
# (yama-kontrol.sh bunu otomatik yapar).
set -e
BIN=/usr/local/bin/YSFGateway
YEDEK="$BIN.orig-APDG03"
REGS=('%s>AP[A-Z0-9]{4},TCPIP' '%s>AP[A-Z0-9]{4},C4FM[*],qAR')
[ "$(id -u)" = 0 ] || { echo "root olarak calistirin"; exit 1; }
[ -f "$BIN" ] || { echo "$BIN yok"; exit 1; }

RO=0
if grep -qE '^\S+ / \S+ ro[ ,]' /proc/mounts; then RO=1; mount -o remount,rw /; fi
bitir() { if [ "$RO" = 1 ]; then sync; mount -o remount,ro / 2>/dev/null || true; fi; return 0; }

if [ "$1" = "--geri" ]; then
  [ -f "$YEDEK" ] || { echo "Yedek yok: $YEDEK"; bitir; exit 1; }
  systemctl stop ysfgateway 2>/dev/null || true
  install -m 755 -o root -g bin "$YEDEK" "$BIN"
  bitir
  systemctl start ysfgateway
  echo "YSFGateway ilk haline donduruldu"; exit 0
fi

NEW="$1"
[[ "$NEW" =~ ^AP[A-Z0-9]{4}$ ]] || { echo "Kullanim: sudo bash $0 APxxxx | --geri   (6 karakter, buyuk harf/rakam, AP ile baslar)"; bitir; exit 1; }
for r in "${REGS[@]}"; do
  [ "$(grep -aoE "$r" "$BIN" | wc -l)" = 1 ] || { echo "Beklenmeyen: '$r' tam bir kez bulunmadi"; bitir; exit 1; }
done
BITTI=1
for r in "${REGS[@]}"; do
  ESKI=$(grep -aoE "$r" "$BIN" | cut -c4-9)
  [ "$ESKI" = "$NEW" ] || BITTI=0
done
[ "$BITTI" = 1 ] && { echo "Zaten $NEW"; bitir; exit 0; }

[ -e "$YEDEK" ] || cp -p "$BIN" "$YEDEK"
cp -p "$BIN" /tmp/YSFGateway.new
for r in "${REGS[@]}"; do
  OFS=$(grep -obUaE "$r" "$BIN" | head -1 | cut -d: -f1)
  OFS=$((OFS + 3))                     # "%s>" atlanir
  printf '%s' "$NEW" | dd of=/tmp/YSFGateway.new bs=1 seek="$OFS" conv=notrunc 2>/dev/null
done
grep -aq "%s>$NEW,TCPIP" /tmp/YSFGateway.new && grep -aq "%s>$NEW,C4FM" /tmp/YSFGateway.new || { echo "YAMA BASARISIZ, dosya degismedi"; rm -f /tmp/YSFGateway.new; bitir; exit 1; }
systemctl stop ysfgateway 2>/dev/null || true
install -m 755 -o root -g bin /tmp/YSFGateway.new "$BIN"
rm -f /tmp/YSFGateway.new
bitir
systemctl start ysfgateway
sleep 3
printf 'ysfgateway: '; systemctl is-active ysfgateway || true
echo "tocall -> $NEW (APDG03 ve APDPRS paketleri; bir sonraki APRS paketinde gecerli olur)"
