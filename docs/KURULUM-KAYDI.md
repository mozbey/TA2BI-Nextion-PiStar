# Kurulum kaydı: Nextion + USB-TTL + Pi-Star (çalışan düzen)

Bu not, çalışan kurulumun özeti ve başka bir Pi'ye aynısını kurarken izlenecek yoldur. Doğrulandığı donanım: Raspberry Pi 2 Model B, Pi-Star 4.2.6 (MMDVMHost 20240210_PS4), MMDVM_HS_Hat, Nextion NX4832T035_011R, CH340 USB-TTL, YSF2DMR → BrandMeister.

## Çalışan düzen
```
Yaesu telsiz ─RF─ modem ─ MMDVMHost ─ /dev/ttyNextionDriver ─ NextionDriver ─ /dev/ttyUSB0 (CH340) ─ Nextion
                                                  ▲                │
                                  tgekran servisi ┘                └─ ekran düğmesi komutu → sudo ... ysf2dmr
```
- `/etc/mmdvmhost`: `[Nextion] Port=/dev/ttyNextionDriver`, `[NextionDriver] Port=/dev/ttyUSB0`
- Ekran hızı 9600 baud. Layout `ON7LDS L2` (ScreenLayout 2). `ScreenLayout=4` seçilirse sürücü 115200 açar, ekran konuşmaz.
- `tgekran` servisi (root): TG adı ve YSF operatör bilgisini `/dev/ttyNextionDriver`'a yazar (modem bağlantısında UDP 40095 kullanır, `[NextionDriver] Port` değerinden otomatik anlar).
- Telefon/PC TG sayfası: `http://<pi>/admin/tg.php` (`kur.sh`).

## Başka Pi'ye kurulum (özet)
1. Ekranı USB-TTL'e bağlayın: Nextion TX → RXD, RX → TXD, 5V, GND. Modem konnektöründen çıkarın.
2. Pi-Star panelinde: Display `Nextion`, Port `/dev/ttyNextionDriver`, Layout `ON7LDS L2`, Apply (önce F5).
3. TFT dosyasını (`tft/TA2BI.tft` ya da `TA2BI_K035.tft`) ekrana SD kartla yükleyin (README, adım 2).
4. Pi'de: `sudo bash pistar/usb-kur.sh` (NextionDriver yamalı derleme + port ayarı + `tgekran`).
5. İsteğe bağlı: `sudo bash pistar/kur.sh` (web TG sayfası).
6. Kontrol: bkz. aşağıdaki liste.

## Doğrulama komutları
```bash
grep -A1 '^\[Nextion\]'       /etc/mmdvmhost    # Port=/dev/ttyNextionDriver
grep -A1 '^\[NextionDriver\]' /etc/mmdvmhost    # Port=/dev/ttyUSB0
grep NextionDriver /var/log/syslog | grep 'Found Nextion display'
stty -F /dev/ttyUSB0 speed                      # 9600
systemctl is-active nextiondriver mmdvmhost tgekran ysf2dmr
vcgencmd get_throttled                          # 0x0 olmalı
```
Ekran → Pi yolu: TG sayfasında düğmeye basınca syslog'da `Received command 0xF1` ve `Command response "Baglandi TG ..."` görünür.

## Bulunan sorunlar ve çözümleri
| Belirti | Neden | Çözüm |
|---|---|---|
| USB-TTL takılı, ekranda TG/isim yok | `tgekran` yalnızca modem yolunu (UDP 40095) kullanıyordu | Servis `[NextionDriver] Port`'a bakıp `/dev/ttyNextionDriver`'a yazar |
| Ekran hiç veri almıyor, log'da `No Nextion display found` | `[NextionDriver] Port=modem` kalmıştı. Panelde `/dev/ttyUSB0` seçmek yalnızca `[Nextion] Port`'u değiştirir | `[Nextion]=/dev/ttyNextionDriver`, `[NextionDriver]=/dev/ttyUSB0` (`usb-kur.sh`) |
| Pi'den gelen veri ekranda görünmüyor, Nextion yanıt vermiyor | TX/RX ters ya da port hızı yanlış | TX↔RX çaprazlayın. Hız 9600 |
| Operatör adı/bayrak hiç çıkmıyor | MMDVMHost YSF sayfasında `t0.txt="R TA2BI     "` yazar (tip + çağrı). Ekran kodu `t0` başını `MMDVM.opcall` ile karşılaştırır | `tgekran` `MMDVM.opcall` değerini `R TA2BI` / `N TA2BI` biçiminde yazar (R=RF, N=ağ) |
| RF `late entry` yayınında bilgi yok | Log satırı `received RF late entry from` idi, `header` aranıyordu | Üç satır tipi de tanınır |
| Bilgi yayın bitince hemen siliniyor | MMDVMHost `t0="Listening"` yazar, ekran isimleri siler | `tgekran` yayın bitince (4 sn sonra) `t0`'ı son konuşanla geri yazar, Idle'a kadar kalır |
| Ekran bir görünüp kayboluyor / yanıtsız | NextionDriver çalışırken USB port hızı 9600→115200'e kayıyor | `tgekran` hızı 2 sn'de bir denetler, 9600'e geri alır |
| Komutlar eksik/bozuk, ekran hata kodu `0x1C` | NextionDriver 1.25'te 9600 baud bekleme süreleri ters (komutlar çok hızlı yazılıyor) | 1.26'da düzeltilmiş (`usb-kur.sh` 1.26 derler) |
| TG düğmesi "yanıt gelmedi" | Düğme ~190 baytlık komut gönderir. NextionDriver 100 baytı aşan alımı atar (`RXtail>100`) | `RXtail>500` yaması |
| TG düğmesi bir kez çalışıp sürücü çöküyor (`SEGV`) | `handleButton` içinde `char text[150]`, gelen baytları hex döker, 190 bayt taşar | `text[2048]` yaması |
| Pi'de `Under-voltage detected`, `throttled=0x50005` | Güç yetersiz (Pi 2, WLAN dongle, ekran). Bu kurulumda ekranı doğrudan bozduğu kanıtlanamadı | Kaliteli adaptör ve kısa kablo, gerekirse ekranı ayrı beslemek |

## Yapılmaması gerekenler
- Pi-Star panelinde Port'u `/dev/ttyUSB0` yapmak (NextionDriver devre dışı kalır).
- `ScreenLayout=4` / "ON7LDS L3 HS" seçmek (115200 baud).
- Çalışan NextionDriver'a `kill -STOP` / elle seri komut göndermek. Dondurulup çözülünce sürücü çöktü.
- Panelde "Değişiklikleri Uygula" sonrası `[NextionDriver] Port`'u kontrol etmeyi unutmak.

## Notlar
- NextionDriver yaması stok GPL kaynağına iki küçük `sed` değişikliğidir (bkz. `pistar/usb-kur.sh`). Kaynak: https://github.com/on7lds/NextionDriver (commit 03b9042, sürüm 1.26).
- Pi-Star güncellemesi sonrası `NextionDriver --version` ve `[NextionDriver] Port` değerini kontrol edin. Gerekirse `usb-kur.sh`'ı yeniden çalıştırın.
- Çökerse `sudo systemctl restart nextiondriver mmdvmhost tgekran` (sırayla, `nextiondriver` önce).
