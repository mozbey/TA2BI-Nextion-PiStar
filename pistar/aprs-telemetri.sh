#!/bin/bash
# TA2BI - APRS telemetri ve durum (TG) servisi.
#
# APRSGateway'in UDP girisine (127.0.0.1:8673) ham APRS satirlari yazar; APRSGateway bunlari
# APRS-IS'e oldugu gibi iletir. Kaynak istasyon YSFGateway ile ayni: <Callsign>-<Suffix> (ornek TA2BI-Y).
#
#  - Her ARALIK dakikada telemetri:  T#sss,a1,a2,a3,a4,a5,bbbbbbbb
#      a1 CPU sicakligi (C)          a2 sistem yuku (x50)       a3 aralikta biten YSF yayin sayisi
#      a4 Wi-Fi sinyali (-dBm)       a5 bos disk (%)
#      b1 dusuk gerilim uyarisi      b2 mmdvmhost  b3 ysfgateway  b4 ysf2dmr  b5 nextiondriver
#      b6 USB-TTL portu              b7 tgekran    b8 yedek
#  - 6 saatte bir tanimlar (PARM/UNIT/EQNS/BITS)
#  - TG degisince ve her aralikta durum satiri:  >TG 28681 Turkiye Fusion
# Ayarlar /etc/default/ta2bi-aprs (yoksa varsayilanlar): ARALIK=10 (dakika)
#   --dry : paketleri gondermeden ekrana yazar
LOGDIR=/var/log/pi-star
YSFCONF=/etc/ysfgateway
YSF2DMR=/etc/ysf2dmr
LIST=/usr/local/etc/TGList_BM.txt
UDPHOST=127.0.0.1; UDPPORT=8673
ARALIK=10
[ -r /etc/default/ta2bi-aprs ] && . /etc/default/ta2bi-aprs
KURU=0; [ "$1" = "--dry" ] && KURU=1

ini_oku() {  # $1 dosya, $2 bolum, $3 anahtar
  awk -v s="[$2]" -v k="$3" -F= '$0==s{b=1;next} /^\[/{b=0} b&&$1==k{print $2; exit}' "$1" | tr -d '\r \t'
}
CALL=$(ini_oku "$YSFCONF" General Callsign); SUF=$(ini_oku "$YSFCONF" APRS Suffix)
[ -n "$CALL" ] || { echo "Callsign bulunamadi ($YSFCONF)"; exit 1; }
KAYNAK="$CALL${SUF:+-$SUF}"
ADRES=$(printf '%-9s' "$KAYNAK")
# tocall YSFGateway ikilisinden okunur (tocall.sh ile degistirildiyse ayni kod kullanilir)
TOC=$(grep -aoE '%s>AP[A-Z0-9]{4},TCPIP' /usr/local/bin/YSFGateway 2>/dev/null | head -1 | cut -c4-9)
BASLIK="$KAYNAK>${TOC:-APDG03},TCPIP*,qAC,$KAYNAK"

gonder() {  # $1 = bilgi alani (':' baslik sonuna eklenir)
  local p="$BASLIK:$1"
  # APRSGateway satiri oldugu gibi APRS-IS'e iletir; satir sonu (CRLF) gonderen eklemelidir
  if [ "$KURU" = 1 ]; then echo "$p"; else printf '%s\r\n' "$p" > /dev/udp/$UDPHOST/$UDPPORT 2>/dev/null; fi
}

ad_bul() {
  case "$1" in
    286) echo "Turkiye" ;; 2861) echo "Turkiye 1" ;; 28681) echo "Turkiye Fusion" ;;
    9) echo "Yerel" ;; 91) echo "Dunya" ;; 92) echo "Avrupa" ;; 4000) echo "Baglanti kes" ;;
    *) grep -m1 "^$1;" "$LIST" 2>/dev/null | cut -d';' -f3 | tr -cd 'A-Za-z0-9 .-' | cut -c1-24 ;;
  esac
}
tg_oku() { TG=$(awk -F= '/^StartupDstId=/{gsub(/[^0-9]/,"",$2); print $2; exit}' "$YSF2DMR"); }

sinir() { local v=$1; [ "$v" -lt 0 ] && v=0; [ "$v" -gt 255 ] && v=255; echo "$v"; }
aktif() { systemctl is-active --quiet "$1" && echo 1 || echo 0; }

tanimlar() {
  gonder ":$ADRES:PARM.T,Load,TX,WiFi,Disk,LowV,MMDVM,YSF,Y2D,Nxt,USB,TG,x"
  gonder ":$ADRES:UNIT.C,x,n,dBm,%,v,on,on,on,on,v,on,v"
  gonder ":$ADRES:EQNS.0,1,0,0,0.02,0,0,1,0,0,-1,0,0,1,0"
  gonder ":$ADRES:BITS.11111111,TA2BI Hotspot&Nextion"
}

yayin_sayisi() {  # bugunku kayitta biten YSF yayin sayisi
  local gun; TZ=UTC printf -v gun '%(%Y-%m-%d)T' -1
  local n; n=$(grep -c 'YSF, received .*end of transmission' "$LOGDIR/MMDVM-$gun.log" 2>/dev/null); echo "${n:-0}"
}

telemetri() {
  local vc cpu yuk wifi disk dusuk b2 b3 b4 b5 b6 b7 sinyal say yeni tx
  cpu=$(( $(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0) / 1000 ))
  yuk=$(awk '{printf "%d", $1*50}' /proc/loadavg)
  yeni=$(yayin_sayisi); tx=$(( yeni - ${ESKI_TX:-$yeni} )); [ "$tx" -lt 0 ] && tx=$yeni; ESKI_TX=$yeni
  sinyal=$(awk 'NR>2 && $1 ~ /^wlan/ {gsub(/\./,"",$4); print $4; exit}' /proc/net/wireless 2>/dev/null)
  sinyal=${sinyal:-0}; wifi=$(( sinyal < 0 ? -sinyal : sinyal ))
  disk=$(df / | awk 'NR==2{gsub(/%/,"",$5); print 100-$5}')
  vc=$(vcgencmd get_throttled 2>/dev/null | sed 's/.*=//'); dusuk=$(( ${vc:-0} & 1 ))
  b2=$(aktif mmdvmhost); b3=$(aktif ysfgateway); b4=$(aktif ysf2dmr); b5=$(aktif nextiondriver)
  b6=0; [ -e /dev/ttyUSB0 ] && b6=1; b7=$(aktif tgekran)
  printf -v say '%03d' $(( ($(printf '%(%s)T' -1) / 60 / ARALIK) % 1000 ))
  gonder "T#$say,$(sinir $cpu),$(sinir $yuk),$(sinir $tx),$(sinir $wifi),$(sinir ${disk:-0}),${dusuk:-0}$b2$b3$b4$b5$b6${b7}0"
}

durum() {
  [ -n "$TG" ] || return
  gonder ">TG $TG $(ad_bul "$TG")"
}

son_tanim=0; son_tel=0; son_tg=""
while true; do
  simdi=$(printf '%(%s)T' -1)
  tg_oku
  if [ $((simdi - son_tanim)) -ge 21600 ]; then tanimlar; son_tanim=$simdi; fi
  if [ $((simdi - son_tel)) -ge $((ARALIK * 60)) ]; then telemetri; durum; son_tel=$simdi; son_tg=$TG
  elif [ "$TG" != "$son_tg" ] && [ -n "$TG" ]; then durum; son_tg=$TG; fi
  [ "$KURU" = 1 ] && exit 0
  sleep 30
done
