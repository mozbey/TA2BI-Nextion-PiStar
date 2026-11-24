#!/bin/bash
# TA2BI - Wi-Fi bekcisi kurulumu (Pi-Star uzerinde root olarak).  sudo bash kur-wifi.sh
# Kaldirma: sudo systemctl disable --now ta2bi-wifi; sudo rm /etc/systemd/system/ta2bi-wifi.service /opt/ta2bi/wifi-bekci.sh
set -e
cd "$(dirname "$0")"
for f in wifi-bekci.sh ta2bi-wifi.service; do [ -f "$f" ] || { echo "EKSIK: $f"; exit 1; }; done
[ "$(id -u)" = 0 ] || { echo "root olarak calistirin"; exit 1; }
RO=0
if grep -qE '^\S+ / \S+ ro[ ,]' /proc/mounts; then RO=1; mount -o remount,rw /; fi
install -d -m 755 /opt/ta2bi
install -m 755 -o root -g root wifi-bekci.sh /opt/ta2bi/wifi-bekci.sh
install -m 644 -o root -g root ta2bi-wifi.service /etc/systemd/system/ta2bi-wifi.service
systemctl daemon-reload
systemctl enable ta2bi-wifi.service >/dev/null 2>&1
systemctl restart ta2bi-wifi.service
sync
if [ "$RO" = 1 ]; then mount -o remount,ro / 2>/dev/null || true; fi
sleep 2
printf 'ta2bi-wifi: '; systemctl is-active ta2bi-wifi.service
echo "KURULUM TAMAM"
