#!/bin/bash
# TA2BI - guncelleme/Apply sonrasi onarim servisinin kurulumu (Pi-Star uzerinde root olarak).
#   sudo bash kur-yama.sh [TOCALL] ["APRS aciklamasi"]
#   ornek: sudo bash kur-yama.sh AP2BIG "TA2BI Hotspot&Nextion"
# Once usb-kur.sh ve (kullaniliyorsa) tocall.sh ile yamalari yapin; bu betik o anki yamali
# NextionDriver'i yedekleyip yama-kontrol.sh'i 10 dakikalik timer ile calistirir.
set -e
cd "$(dirname "$0")"
for f in yama-kontrol.sh tocall.sh ta2bi-yama.service ta2bi-yama.timer; do [ -f "$f" ] || { echo "EKSIK: $f"; exit 1; }; done
[ "$(id -u)" = 0 ] || { echo "root olarak calistirin"; exit 1; }
RO=0
if grep -qE '^\S+ / \S+ ro[ ,]' /proc/mounts; then RO=1; mount -o remount,rw /; fi
install -d -m 755 /opt/ta2bi /opt/ta2bi/yedek
install -m 755 -o root -g root yama-kontrol.sh /opt/ta2bi/yama-kontrol.sh
install -m 755 -o root -g root tocall.sh /opt/ta2bi/tocall.sh
install -m 755 -o root -g bin /usr/local/bin/NextionDriver /opt/ta2bi/yedek/NextionDriver
{
  echo "PORT=/dev/ttyUSB0"
  echo "TOCALL=${1:-}"
  echo "DESC=\"${2:-}\""
} > /etc/default/ta2bi-yama
# TOCALL bos birakildiysa mevcut degeri kullan
if [ -z "${1:-}" ]; then
  MEV=$(grep -aoE '%s>AP[A-Z0-9]{4},TCPIP' /usr/local/bin/YSFGateway | head -1 | cut -c4-9)
  sed -i "s/^TOCALL=.*/TOCALL=${MEV:-APDG03}/" /etc/default/ta2bi-yama
fi
install -m 644 -o root -g root ta2bi-yama.service /etc/systemd/system/ta2bi-yama.service
install -m 644 -o root -g root ta2bi-yama.timer /etc/systemd/system/ta2bi-yama.timer
systemctl daemon-reload
systemctl enable --now ta2bi-yama.timer >/dev/null 2>&1
sync
[ "$RO" = 1 ] && mount -o remount,ro / 2>/dev/null || true
echo "--- /etc/default/ta2bi-yama ---"; cat /etc/default/ta2bi-yama
printf 'timer: '; systemctl is-active ta2bi-yama.timer
echo "KURULUM TAMAM"
