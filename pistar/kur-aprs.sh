#!/bin/bash
# TA2BI - APRS telemetri servisinin kurulumu (Pi-Star uzerinde root olarak).
#   sudo bash kur-aprs.sh [aralik_dakika]     (varsayilan 10)
# Kaldirma: sudo systemctl disable --now ta2bi-aprs; sudo rm /etc/systemd/system/ta2bi-aprs.service /opt/ta2bi/aprs-telemetri.sh
set -e
cd "$(dirname "$0")"
for f in aprs-telemetri.sh ta2bi-aprs.service; do [ -f "$f" ] || { echo "EKSIK: $f"; exit 1; }; done
[ "$(id -u)" = 0 ] || { echo "root olarak calistirin"; exit 1; }
RO=0
if grep -qE '^\S+ / \S+ ro[ ,]' /proc/mounts; then RO=1; mount -o remount,rw /; fi
install -d -m 755 /opt/ta2bi
install -m 755 -o root -g root aprs-telemetri.sh /opt/ta2bi/aprs-telemetri.sh
install -m 644 -o root -g root ta2bi-aprs.service /etc/systemd/system/ta2bi-aprs.service
echo "ARALIK=${1:-10}" > /etc/default/ta2bi-aprs
systemctl daemon-reload
systemctl enable ta2bi-aprs.service >/dev/null 2>&1
systemctl restart ta2bi-aprs.service
sync
[ "$RO" = 1 ] && mount -o remount,ro / 2>/dev/null || true
sleep 2
printf 'ta2bi-aprs: '; systemctl is-active ta2bi-aprs.service
echo "KURULUM TAMAM. Ornek paketler: /opt/ta2bi/aprs-telemetri.sh --dry"
