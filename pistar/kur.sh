#!/bin/bash
# TA2BI - telefon TG sayfasi kurulumu (Pi-Star uzerinde root olarak calistirilir)
# Kullanim: sudo bash /tmp/kur.sh   (tgset.sh ve tg.php ayni klasorde olmali)
set -e
cd "$(dirname "$0")"
for f in tgset.sh tg.php; do [ -f "$f" ] || { echo "EKSIK: $f"; exit 1; }; done

mount -o remount,rw /

install -d -m 755 -o root -g root /opt/ta2bi
install -m 755 -o root -g root tgset.sh /opt/ta2bi/tgset.sh

echo 'www-data ALL=(root) NOPASSWD: /opt/ta2bi/tgset.sh *' > /tmp/ta2bi-tg
visudo -cf /tmp/ta2bi-tg
install -m 440 -o root -g root /tmp/ta2bi-tg /etc/sudoers.d/ta2bi-tg
rm -f /tmp/ta2bi-tg

install -m 644 -o www-data -g www-data tg.php /var/www/dashboard/admin/tg.php

sync
mount -o remount,ro / || true

echo "--- deneme (www-data olarak) ---"
sudo -u www-data sudo -n /opt/ta2bi/tgset.sh "$(awk -F= '/^StartupDstId=/{print $2; exit}' /etc/ysf2dmr)"
echo "KURULUM TAMAM -> http://$(hostname -I | awk '{print $1}')/admin/tg.php"
