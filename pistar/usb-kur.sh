#!/bin/bash
# TA2BI - Nextion ekrani USB-TTL ile baglamak icin Pi-Star kurulumu (root olarak calistirilir)
#
#   sudo bash usb-kur.sh [/dev/ttyUSB0]
#
# Yaptiklari:
#   1) NextionDriver kaynagini indirir, iki hatayi duzeltip derler:
#        - ekrandan gelen >100 baytlik komutlar (TG dugmesi ~190 bayt) atiliyordu
#        - 150 baytlik yigit dizisi bu komutlarda tasip NextionDriver'i cokertiyordu
#   2) /etc/mmdvmhost:  [Nextion] Port=/dev/ttyNextionDriver, [NextionDriver] Port=<usb port>
#   3) tgekran servisini (TG adi + operator bilgisi) kurar
#   4) servisleri yeniden baslatir
# Eski NextionDriver /usr/local/bin/NextionDriver.orig-<tarih> olarak saklanir.
# Derleme basarisiz olursa hicbir seye dokunulmaz.
set -e
PORT="${1:-/dev/ttyUSB0}"
ND_REPO=https://github.com/on7lds/NextionDriver
ND_COMMIT=03b904270c9cb54f720d71753fc209afb1d9598f   # 1.26, bu yamayla denenen surum
DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD=/tmp/ta2bi-nd

[ "$(id -u)" = 0 ] || { echo "root olarak calistirin: sudo bash $0"; exit 1; }
for f in tgekran.sh tgekran.service; do [ -f "$DIR/$f" ] || { echo "EKSIK: $DIR/$f"; exit 1; }; done
[ -e "$PORT" ] || { echo "UYARI: $PORT yok. USB-TTL takili mi? (devam ediliyor)"; }
command -v gcc >/dev/null && command -v make >/dev/null && command -v git >/dev/null || { echo "gcc, make ve git gerekli"; exit 1; }

echo "== 1/4 NextionDriver kaynagi hazirlaniyor ve derleniyor"
rm -rf "$BUILD"
if [ -n "$NDSRC" ]; then
  # Pi'nin interneti zayifsa: kaynagi baska makineden kopyalayip NDSRC=/yol ile verin
  [ -f "$NDSRC/NextionDriver.c" ] || { echo "NDSRC icinde NextionDriver.c yok"; exit 1; }
  cp -r "$NDSRC" "$BUILD"
else
  # yalnizca tek commit, gecmis olmadan
  for i in 1 2 3; do
    rm -rf "$BUILD"; mkdir -p "$BUILD"
    if (cd "$BUILD" && git init -q && timeout 240 git fetch -q --depth 1 "$ND_REPO" "$ND_COMMIT" && git checkout -q FETCH_HEAD); then break; fi
    rm -rf "$BUILD"; echo "indirme basarisiz ($i/3), tekrar..."; sleep 5
  done
  [ -f "$BUILD/NextionDriver.c" ] || { echo "KAYNAK INDIRILEMEDI (Pi'nin interneti?). Cozum: kaynagi kopyalayip 'NDSRC=/yol sudo -E bash usb-kur.sh' calistirin"; exit 1; }
fi
cd "$BUILD"
# 100 baytlik alim siniri -> 500
grep -q 'if (RXtail>100) RXtail=0;' NextionDriver.c || { echo "yama yeri bulunamadi (RXtail)"; exit 1; }
sed -i 's/if (RXtail>100) RXtail=0;/if (RXtail>500) RXtail=0;/' NextionDriver.c
# hex dokum dizisi 150 -> 2048 bayt
grep -q 'char code, text\[150\],info\[100\], \*cmd;' NextionDriver.c || { echo "yama yeri bulunamadi (text[150])"; exit 1; }
sed -i 's/char code, text\[150\],info\[100\], \*cmd;/char code, text[2048],info[100], *cmd;/' NextionDriver.c
make >/dev/null 2>&1 || { echo "DERLEME BASARISIZ"; exit 1; }
[ -x NextionDriver ] || { echo "DERLEME BASARISIZ"; exit 1; }
echo "derleme tamam"

echo "== 2/4 Kurulum"
RO=0
if grep -qE '^\S+ / \S+ ro[ ,]' /proc/mounts; then RO=1; mount -o remount,rw /; fi
systemctl stop tgekran 2>/dev/null || true
systemctl stop mmdvmhost 2>/dev/null || true
systemctl stop nextiondriver 2>/dev/null || true
YEDEK=/usr/local/bin/NextionDriver.orig-$(date +%Y%m%d)
[ -e "$YEDEK" ] || cp -p /usr/local/bin/NextionDriver "$YEDEK"
install -m 755 -o root -g bin "$BUILD/NextionDriver" /usr/local/bin/NextionDriver

echo "== 3/4 /etc/mmdvmhost portlari ve tgekran"
cp -p /etc/mmdvmhost /etc/mmdvmhost.ta2bi-onceki
# [Nextion] Port -> sanal port ; [NextionDriver] Port -> gercek USB port
sed -i '/^[[]Nextion[]]/,/^[[]/ s#^Port=.*#Port=/dev/ttyNextionDriver#' /etc/mmdvmhost
sed -i '/^[[]NextionDriver[]]/,/^[[]/ s#^Port=.*#Port='"$PORT"'#' /etc/mmdvmhost
install -d -m 755 -o root -g root /opt/ta2bi
install -m 755 -o root -g root "$DIR/tgekran.sh" /opt/ta2bi/tgekran.sh
install -m 644 -o root -g root "$DIR/tgekran.service" /etc/systemd/system/tgekran.service
systemctl daemon-reload
systemctl enable tgekran.service >/dev/null 2>&1
systemctl enable nextiondriver.service >/dev/null 2>&1 || true
sync

echo "== 4/4 Servisler baslatiliyor"
systemctl reset-failed nextiondriver 2>/dev/null || true
systemctl start nextiondriver
sleep 8
systemctl start mmdvmhost
sleep 6
systemctl start tgekran
sleep 3
[ "$RO" = 1 ] && { sync; mount -o remount,ro / 2>/dev/null || true; }

echo "--- kontrol ---"
grep -A1 '^[[]Nextion[]]' /etc/mmdvmhost | grep -v '^--'
grep -A1 '^[[]NextionDriver[]]' /etc/mmdvmhost | grep -v '^--'
for s in nextiondriver mmdvmhost tgekran; do printf '%s: ' "$s"; systemctl is-active "$s" || true; done
printf 'port hizi: '; stty -F "$PORT" speed 2>/dev/null || echo "?"
grep NextionDriver /var/log/syslog | grep -E 'Found Nextion display|No Nextion display' | tail -1
echo "KURULUM TAMAM. TG sayfasi icin ayrica: sudo bash $DIR/kur.sh"
