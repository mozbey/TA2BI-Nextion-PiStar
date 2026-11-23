#!/bin/bash
# TA2BI - TG adini ekrana yazan servisin kurulumu.  Kullanim: sudo bash /tmp/kur2.sh
set -e
cd "$(dirname "$0")"
mount -o remount,rw /
install -d -m 755 /opt/ta2bi
install -m 755 -o root -g root tgekran.sh /opt/ta2bi/tgekran.sh
install -m 644 -o root -g root tgekran.service /etc/systemd/system/tgekran.service
systemctl daemon-reload
systemctl enable tgekran.service
systemctl restart tgekran.service
sync; mount -o remount,ro / || true
sleep 1; systemctl is-active tgekran.service
echo "KURULUM TAMAM"
