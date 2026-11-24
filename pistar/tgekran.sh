#!/bin/bash
# TA2BI - Nextion ekrana Pi tarafindan bilgi "iten" servis.
#  1) YSF2DMR'nin aktif TG'si        -> MMDVM.tgad.txt  ("TG 28681 Turkiye Fusion")
#                                       MMDVM.tgno.txt  ("28681")
#  2) YSF'de konusanin isim bilgileri -> MMDVM.opcall.txt ("AJ5DG")
#     (nextionUsers.csv'den)            MMDVM.opad.txt   ("Matthew")
#                                       MMDVM.opyer.txt  ("Angeles City, United States")
#                                       MMDVM.opulke.txt ("United States")  (bayrak icin)
# Iki yol vardir, ekranin nereye bagli oldugu /etc/mmdvmhost'tan otomatik anlasilir:
#  - Ekran modem kartinda ([NextionDriver] Port=modem):
#      UDP 127.0.0.1:40095 (MMDVMHost Transparent Data) -> modem -> Nextion
#      Paket: 0x80 + Nextion komutu + FF FF FF
#  - Ekran USB-TTL'de ([NextionDriver] Port=/dev/ttyUSB0):
#      /dev/ttyNextionDriver (NextionDriver'in sanal portu) -> USB-TTL -> Nextion
#      Paket: Nextion komutu + FF FF FF  (MMDVMHost'un NextionDriver'a yazdigi bicim)
MMDVMINI=/etc/mmdvmhost
NDLINK=/dev/ttyNextionDriver
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

yol_bul() {  # YOL=usb (NextionDriver USB-TTL'e bagli) | udp (modem)
  local l sec="" port=""
  YOL=udp
  [ -e "$NDLINK" ] || return
  while IFS= read -r l; do
    l=${l%$'\r'}
    case "$l" in
      "["*) sec=$l ;;
      Port=*) [ "$sec" = "[NextionDriver]" ] && { port=${l#Port=}; break; } ;;
    esac
  done < "$MMDVMINI"
  port=${port//[$' \t\r']/}
  case "$port" in ""|modem) ;; *) YOL=usb; NDPORT=$port ;; esac
}

hiz_denetle() {  # NextionDriver USB portu 9600 baud'dan kayarsa (ekran 9600'da konusur) geri alir
  [ "$YOL" = usb ] && [ -n "$NDPORT" ] || return
  [ "$(stty -F "$NDPORT" speed 2>/dev/null)" = 9600 ] || stty -F "$NDPORT" 9600 2>/dev/null
}

gonder() {  # $1 = Nextion komutu
  if [ "$YOL" = usb ]; then
    printf '%s\xff\xff\xff' "$1" > "$NDLINK" 2>/dev/null
  else
    printf '\x80%s\xff\xff\xff' "$1" > /dev/udp/127.0.0.1/40095 2>/dev/null
  fi
}

operator_gonder() {  # $1 = cagri isareti (ham), $2 = R (RF) | N (ag)
  local ham="$1" tip="$2" call ad yer ulke satir
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
  # MMDVMHost YSF sayfasinda t0.txt="R TA2BI     " yazar (tip harfi + bosluk + cagri).
  # Ekran kodu t0'in basini MMDVM.opcall ile karsilastirir, bu yuzden ayni bicimde gonderilir.
  SONT0="${tip} $(echo "$ham" | temizle 10)"
  gonder "MMDVM.opcall.txt=\"${SONT0}\""
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

ESKI=""; SONTG=0; SONCALL=""; SONT0=""; ESKITG="-"; METIN=""
yol_bul
log_ac
while true; do
  # 2 sn boyunca yeni kayit satiri bekle (islemci harcamadan)
  if IFS= read -r -t 2 -u 3 SATIR; then
    case "$SATIR" in
      *"YSF, received RF header from "*|*"YSF, received RF late entry from "*|*"YSF, received network data from "*)
        CALL=${SATIR#*from }; CALL=${CALL%% *}
        case "$SATIR" in *"received RF "*) TIP=R ;; *) TIP=N ;; esac
        if [ -n "$CALL" ] && [ "$CALL" != "$SONCALL" ]; then operator_gonder "$CALL" "$TIP"; SONCALL="$CALL"; fi ;;
      *"end of transmission"*|*"watchdog has expired"*)
        SONCALL=""
        # Yayin bitince MMDVMHost t0'i "Listening" yapar ve ekran isimleri siler.
        # Mode Hang suresince (Idle'a kadar) son konusanin t0'ini geri yaziyoruz.
        # NextionDriver ekrana yaklasik 3 sn gec yazdigi icin MMDVMHost'un "Listening"inden SONRA gitmeli
        if [ -n "$SONT0" ]; then ( sleep 4; gonder "t0.txt=\"${SONT0}\"" ) & fi ;;
      *"Mode set to Idle"*)
        SONCALL=""; SONT0="" ;;
    esac
  fi
  printf -v SIMDI '%(%s)T' -1
  if [ $((SIMDI - SONTG)) -ge 2 ]; then
    SONTG=$SIMDI
    tg_oku; yol_bul; hiz_denetle
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
