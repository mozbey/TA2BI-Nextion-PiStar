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

tg_oku() {  # /etc/ysf2dmr'den StartupDstId -> $TG (alt kabuk acmadan)
  local l; TG=""
  while IFS= read -r l; do
    case "$l" in StartupDstId=*) l=${l#StartupDstId=}; TG=${l//[^0-9]/}; return ;; esac
  done < "$CONF"
}

bugun_log() { TZ=UTC printf -v BUGUN '%(%Y-%m-%d)T' -1; BUGUNLOG="$LOGDIR/MMDVM-$BUGUN.log"; }

TPID=""
log_ac() {  # gunun MMDVM kaydini 'tail -F' ile fd 3'e bagla
  [ -n "$TPID" ] && kill "$TPID" 2>/dev/null
  bugun_log; LOG=$BUGUNLOG
  exec 3< <(exec tail -F -n0 "$LOG" 2>/dev/null)
  TPID=$!
}
trap '[ -n "$TPID" ] && kill $TPID 2>/dev/null' EXIT

ESKI=""; SONTG=0; SONCALL=""; ESKITG="-"; METIN=""
log_ac
while true; do
  # 2 sn boyunca yeni kayit satiri bekle (islemci harcamadan)
  if IFS= read -r -t 2 -u 3 SATIR; then
    case "$SATIR" in
      *"YSF, received RF header from "*|*"YSF, received network data from "*)
        CALL=${SATIR#*from }; CALL=${CALL%% *}
        if [ -n "$CALL" ] && [ "$CALL" != "$SONCALL" ]; then operator_gonder "$CALL"; SONCALL="$CALL"; fi ;;
      *"end of transmission"*|*"watchdog has expired"*|*"Mode set to Idle"*)
        SONCALL="" ;;
    esac
  fi
  printf -v SIMDI '%(%s)T' -1
  if [ $((SIMDI - SONTG)) -ge 2 ]; then
    SONTG=$SIMDI
    tg_oku
    if [ "$TG" != "$ESKITG" ]; then   # ad yalnizca TG degisince aranir
      METIN="TG $TG $(ad_bul "$TG")"; METIN="${METIN% }"; ESKITG=$TG
    fi
    if [ "$METIN" != "$ESKI" ] || [ $((SIMDI - ${SONGONDER:-0})) -ge 10 ]; then
      gonder "MMDVM.tgad.txt=\"${METIN}\""
      gonder "MMDVM.tgno.txt=\"${TG}\""
      ESKI="$METIN"; SONGONDER=$SIMDI
    fi
    # gun degisti mi (kayit dosyasi yeni ada gecer)
    bugun_log; [ "$BUGUNLOG" != "$LOG" ] && log_ac
  fi
done
