#!/bin/bash
# TA2BI - YSF2DMR hedef TG degistirme yardimcisi
# Kurulum yeri: /opt/ta2bi/tgset.sh (root:root 755)
# www-data bunu sudo ile calistirir (/etc/sudoers.d/ta2bi-tg).
# Kullanim: tgset.sh <TG>     ornek: tgset.sh 286
set -u
TG="${1:-}"
CONF=/etc/ysf2dmr

if ! [[ "$TG" =~ ^[0-9]{1,7}$ ]] || [ "$TG" -lt 1 ]; then
    echo "HATA: gecersiz TG numarasi"
    exit 1
fi

CUR=$(awk -F= '/^StartupDstId=/{print $2; exit}' "$CONF")
if [ "$CUR" = "$TG" ]; then
    echo "TG zaten $TG"
    exit 0
fi

RO=0
if grep -qE '^\S+ / \S+ ro[ ,]' /proc/mounts; then RO=1; mount -o remount,rw / ; fi
cp -p "$CONF" "/etc/ysf2dmr.tg-onceki"
sed -i "s/^StartupDstId=.*/StartupDstId=${TG}/" "$CONF"
sync
[ "$RO" = 1 ] && mount -o remount,ro / 2>/dev/null

logger -t ta2bi-tg "YSF2DMR TG $CUR -> $TG"
systemctl stop ysf2dmr.service
systemctl start ysf2dmr.service
echo "OK: TG $CUR -> $TG"
