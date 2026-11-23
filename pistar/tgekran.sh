#!/bin/bash
# TA2BI - Nextion ekrana Pi tarafindan bilgi "iten" servis.
#  1) YSF2DMR'nin aktif TG'si        -> MMDVM.tgad.txt  ("TG 28681 Turkiye Fusion")
#                                       MMDVM.tgno.txt  ("28681")
#  2) YSF'de konusanin isim bilgileri -> MMDVM.opcall.txt ("AJ5DG")
#     (nextionUsers.csv'den)            MMDVM.opad.txt   ("Matthew")
#                                       MMDVM.opyer.txt  ("Angeles City, United States")
#                                       MMDVM.opulke.txt ("United States")  (bayrak icin)
# Ekran -> Pi yonu modem uzerinden calismadigi icin bilgi Pi tarafindan gonderilir.
# Yol: UDP 127.0.0.1:40095 (MMDVMHost Transparent Data) -> modem -> Nextion
# Paket: 0x80 + Nextion komutu + FF FF FF  (NextionDriver'in kullandigi bicim)
CONF=/etc/ysf2dmr
LIST=/usr/local/etc/TGList_BM.txt
USERS=/usr/local/etc/nextionUsers.csv
LOGDIR=/var/log/pi-star

ad_bul() {
  case "$1" in
    286)   echo "Turkiye" ;;
    2861)  echo "Turkiye 1" ;;
    28681) echo "Turkiye Fusion" ;;
    9)     echo "Yerel" ;;
    91)    echo "Dunya" ;;
    92)    echo "Avrupa" ;;
    4000)  echo "Baglanti kes" ;;
    *)     grep -m1 "^$1;" "$LIST" 2>/dev/null | cut -d';' -f3 | tr -cd 'A-Za-z0-9 .-' | cut -c1-24 ;;
  esac
}

temizle() {  # UTF-8 -> duz ASCII, tirnak yok, en fazla $1 karakter
  iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null | tr -cd 'A-Za-z0-9 .,/()-' | sed 's/  */ /g; s/^ //; s/ $//' | cut -c1-"$1"
}

gonder() {  # $1 = Nextion komutu
  printf '\x80%s\xff\xff\xff' "$1" > /dev/udp/127.0.0.1/40095 2>/dev/null
}

operator_gonder() {  # $1 = cagri isareti (ham)
  local ham="$1" call ad yer ulke satir
  call=$(echo "$ham" | tr '[:lower:]' '[:upper:]' | sed 's#[/-].*##' | tr -cd 'A-Z0-9')
  [ -z "$call" ] && return
  # CSV: RADIO_ID,CALLSIGN,FIRST_NAME,LAST_NAME,CITY,STATE,COUNTRY
  satir=$(grep -m1 -i ",${call}," "$USERS" 2>/dev/null)
  if [ -n "$satir" ]; then
    ad=$(echo "$satir"   | awk -F, '{print $3" "$4}' | temizle 24)
    ulke=$(echo "$satir" | awk -F, '{print $7}'      | temizle 30)
    yer=$(echo "$satir"  | awk -F, '{ if ($5!="") print $5", "$7; else print $7 }' | temizle 40)
  else
    ad=""; yer=""; ulke=""
  fi
  gonder "MMDVM.opcall.txt=\"$(echo "$ham" | temizle 12)\""
  gonder "MMDVM.opad.txt=\"${ad}\""
  gonder "MMDVM.opyer.txt=\"${yer}\""
  gonder "MMDVM.opulke.txt=\"${ulke}\""
}

ESKI=""; SAYAC=0; LOG=""; POS=0; SONCALL=""
while true; do
  # --- 1) TG: her 2 sn kontrol, degisince hemen, ayrica ~10 sn'de bir tekrar ---
  if [ $((SAYAC % 4)) -eq 0 ]; then
    TG=$(sed -n 's/^StartupDstId=//p' "$CONF" | tr -cd '0-9')
    METIN="TG $TG $(ad_bul "$TG")"; METIN="${METIN% }"
    if [ "$METIN" != "$ESKI" ] || [ $SAYAC -ge 20 ]; then
      gonder "MMDVM.tgad.txt=\"${METIN}\""
      gonder "MMDVM.tgno.txt=\"${TG}\""
      ESKI="$METIN"; SAYAC=0
    fi
  fi
  SAYAC=$((SAYAC+1))

  # --- 2) Operator: MMDVMHost gunluk kaydindaki yeni YSF satirlari ---
  YENI=$(ls -t "$LOGDIR"/MMDVM-*.log 2>/dev/null | head -1)
  if [ -n "$YENI" ]; then
    if [ "$YENI" != "$LOG" ]; then LOG="$YENI"; POS=$(stat -c %s "$LOG"); fi
    BOY=$(stat -c %s "$LOG" 2>/dev/null || echo 0)
    [ "$BOY" -lt "$POS" ] && POS=0
    if [ "$BOY" -gt "$POS" ]; then
      CALL=$(tail -c +$((POS+1)) "$LOG" | head -c $((BOY-POS)) \
             | sed -n 's/.*YSF, received \(RF header\|network data\) from \([^ ]*\).*/\2/p' | tail -1)
      POS=$BOY
      if [ -n "$CALL" ] && [ "$CALL" != "$SONCALL" ]; then
        operator_gonder "$CALL"; SONCALL="$CALL"
      fi
      # Yayin bitince ayni kisi tekrar konusursa yine gonderilsin
      [ -z "$CALL" ] && SONCALL=""
    fi
  fi
  sleep 0.5
done
