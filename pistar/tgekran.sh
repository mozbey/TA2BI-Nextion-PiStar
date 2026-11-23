#!/bin/bash
# TA2BI - YSF2DMR'nin aktif TG'sini Nextion ekrandaki global degiskene yazar.
# Ekran -> Pi yonu modem uzerinden calismadigi icin bilgi Pi tarafindan "itilir".
# Yol: UDP 127.0.0.1:40095 (MMDVMHost Transparent Data) -> modem -> Nextion
# Paket: 0x80 + Nextion komutu + FF FF FF  (NextionDriver'in kullandigi bicim)
CONF=/etc/ysf2dmr
LIST=/usr/local/etc/TGList_BM.txt
HEDEF=MMDVM.tgad          # HMI'deki global metin degiskeni (vscope=global)
ESKI=""; SAYAC=0

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

gonder() {  # $1 = Nextion komutu
  printf '\x80%s\xff\xff\xff' "$1" > /dev/udp/127.0.0.1/40095 2>/dev/null
}

while true; do
  TG=$(sed -n 's/^StartupDstId=//p' "$CONF" | tr -cd '0-9')
  METIN="TG $TG $(ad_bul "$TG")"
  METIN="${METIN% }"
  # Degisince hemen, degismese de 10 sn'de bir gonder (ekran yeniden acilirsa diye)
  if [ "$METIN" != "$ESKI" ] || [ $SAYAC -ge 5 ]; then
    gonder "${HEDEF}.txt=\"${METIN}\""
    ESKI="$METIN"; SAYAC=0
  fi
  SAYAC=$((SAYAC+1))
  sleep 2
done
