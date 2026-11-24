# Nextion ekranı USB-TTL dönüştürücüyle Pi'ye bağlama

## Neden?
Pi-Star'da Nextion ekran genelde modem kartının (MMDVM_HS_Hat, Dual Hat vb.) üzerindeki 4 pinli konnektöre bağlanır. Bu bağlantıda:
- **Pi → ekran** yönü çalışır: saat, çağrılar, bilgiler ekrana gelir.
- **Ekran → Pi** yönü modem yazılımında kaybolur. MMDVMHost kaydında `Modem RX Serial buffer overflow, clearing the buffer` hatası görünür. Bu yüzden dokunmatik düğmeler ve ekranın Pi'den bilgi isteyen komutları çalışmaz.

USB-TTL dönüştürücüyle ekran doğrudan Pi'ye bağlanır, böylece iki yön de çalışır.

## Gerekenler
- **USB-TTL dönüştürücü:** CP2102, CH340G ya da FT232RL tabanlı herhangi bir modül olur. Üzerinde 3.3V/5V seçme köprüsü varsa **5V** konumuna alın.
- Nextion'ın kendi 4'lü kablosu, ya da 4 adet dişi-dişi jumper kablo.

## Bağlantı
TX ve RX **çapraz** bağlanır.

```
  NEXTION                      USB-TTL
  ┌─────────┐                 ┌──────────┐
  │ 5V   🔴 ├─────────────────┤ 5V / VCC │
  │ TX   🔵 ├────────┐  ┌─────┤ TXD      │
  │ RX   🟡 ├─────┐  └──┼────►│ RXD      │
  │ GND  ⚫ ├──┐  └─────┘     │          │
  └─────────┘  └──────────────┤ GND      │
                              └────┬─────┘
                                   │ USB
                              Raspberry Pi
```

| Nextion kablosu | USB-TTL pini |
|---|---|
| 🔴 Kırmızı – **5V** | **5V** (VCC) |
| ⚫ Siyah – **GND** | **GND** |
| 🔵 Mavi – **TX** | **RXD** |
| 🟡 Sarı – **RX** | **TXD** |

> ⚠️ 5V ile GND'yi ters bağlamayın, ekran zarar görür. Kablo renkleri ekrana göre değişebilir; ekranın arkasındaki pin yazılarına bakın.
>
> 3.5" ekran 5V'tan yaklaşık 150–250 mA çeker. Pi'nin USB portu bunu karşılar. Ekran titriyorsa ya da kendiliğinden yeniden başlıyorsa Pi'nin güç adaptörü yetersiz olabilir.

Ekranı modem kartının konnektöründen **çıkarın**. İki yere birden bağlı kalmasın.

## Pi-Star ayarı
Doğru düzende MMDVMHost ekrana doğrudan değil, **NextionDriver** üzerinden bağlanır:

```
MMDVMHost ──[Nextion] Port=/dev/ttyNextionDriver── NextionDriver ──[NextionDriver] Port=/dev/ttyUSB0── ekran
```

> ⚠️ Pi-Star panelinde Port olarak `/dev/ttyUSB0` seçmeyin. Panel yalnızca `[Nextion] Port` satırını yazar ve NextionDriver'ı devre dışı bırakır. Bu durumda ekrana yalnızca MMDVMHost'un temel verisi gider. TG adı, isim bilgileri ve dokunmatik düğmeler çalışmaz.

1. Dönüştürücüyü Pi'ye takın. SSH'ta `ls /dev/ttyUSB*` komutu `/dev/ttyUSB0` göstermeli (CH340/CP2102 sürücüleri Pi-Star'da hazır gelir).
2. **Configuration → MMDVMHost Configuration** bölümünde: MMDVM Display Type `Nextion`, Port `/dev/ttyNextionDriver`, Nextion Layout `ON7LDS L2`. **Apply Changes** (önce sayfayı F5 ile yenileyin).
3. Pi'ye dosyaları kopyalayıp tek komutla kurun (NextionDriver yamasını derler, `[NextionDriver] Port` değerini ayarlar, `tgekran` servisini kurar, servisleri yeniden başlatır):
   ```bash
   cd /tmp && git clone https://github.com/mozbey/TA2BI-Nextion-PiStar.git
   sudo bash /tmp/TA2BI-Nextion-PiStar/pistar/usb-kur.sh          # farklı port için: ... usb-kur.sh /dev/ttyUSB1
   ```
   Telefon TG sayfası isterseniz ayrıca: `sudo bash /tmp/TA2BI-Nextion-PiStar/pistar/kur.sh`
4. Kontrol:
   ```bash
   grep -A1 '^\[NextionDriver\]' /etc/mmdvmhost            # Port=/dev/ttyUSB0
   grep NextionDriver /var/log/syslog | grep 'Found Nextion display'
   stty -F /dev/ttyUSB0 speed                              # 9600
   ```
5. Panelde sonradan "Değişiklikleri Uygula"ya basarsanız `[NextionDriver] Port` değerini yeniden kontrol edin. `modem`'e dönmüşse `usb-kur.sh`'ı tekrar çalıştırın.

Neden yama? NextionDriver 1.25/1.26 ekrandan gelen 100 baytı aşan komutları atar ve 150 baytlık bir dizi yüzünden uzun komutlarda çöker. TG düğmesi ~190 baytlık komut gönderdiği için yama şarttır. Ayrıntılar: [KURULUM-KAYDI.md](KURULUM-KAYDI.md).

## Sorun giderme
Ekranda hiçbir şey görünmüyorsa sırayla şunlara bakın:

1. **Port görünüyor mu?** `ls -l /dev/ttyUSB*` çıktı vermeli. Boşsa dönüştürücü ya da kablo sorunludur (veri kablosu değil, yalnızca şarj kablosu olabilir).
2. **Pi-Star ayarı doğru mu?**
   ```bash
   grep -A3 '^\[Nextion\]' /etc/mmdvmhost          # Port=/dev/ttyNextionDriver, ScreenLayout=2 olmalı
   grep -A3 '^\[NextionDriver\]' /etc/mmdvmhost    # Port=/dev/ttyUSB0 olmalı (modem değil)
   ls -l /dev/ttyNextionDriver
   ```
   `ScreenLayout=4` ("ON7LDS L3 HS") seçiliyse NextionDriver portu 115200 baud ile açar. Bu tasarım ekranı 9600 baud'da çalıştığı için hiçbir veri görünmez. Layout `ON7LDS L2` kalmalıdır.
3. **Doğrudan deneme:** Pi'den ekrana elle komut gönderin. Ekran sayfa 0'a geçmelidir:
   ```bash
   sudo systemctl restart nextiondriver mmdvmhost
   printf 'page 0\xff\xff\xff' | sudo tee /dev/ttyNextionDriver >/dev/null
   ```
   Hiçbir şey olmuyorsa sorun bağlantıdadır: TX/RX yerlerini değiştirin, GND'yi ve 5V'u kontrol edin.
4. **NextionDriver ne diyor?** `sudo journalctl -u nextiondriver -n 30` ya da `grep NextionDriver /var/log/syslog`. `Cannot open /dev/ttyUSB0` yazıyorsa port adı yanlıştır.
5. **TG adı ve operatör bilgisi (tgekran servisi) gelmiyorsa:** eski sürüm yalnızca modem yolunu (UDP 40095) kullanıyordu; USB-TTL'de bilgi ekrana ulaşmıyordu. Güncel `pistar/tgekran.sh` ve `tgekran.service` ile `sudo bash /tmp/TA2BI-Nextion-PiStar/pistar/kur2.sh` komutunu yeniden çalıştırın. Servis artık USB-TTL'de bilgiyi `/dev/ttyNextionDriver` üzerinden gönderir ve bu portu yazabilmek için root olarak çalışır.
6. **Ekran yayın sırasında kendiliğinden başa dönüyor, Pi yeniden başlıyorsa:** güç yetersizdir. Ekran Pi'nin 5V pininden beslendiğinde, telsiz yayın yaparken (TX) gerilim düşer ve ekran sıfırlanır. Kontrol: `vcgencmd get_throttled` çıktısı `throttled=0x0` olmalı. `0x50005` gibi bir değer ya da `dmesg | grep -i voltage` çıktısında `Under-voltage detected` varsa 5V 2.5A kaliteli bir adaptör ve kısa, kalın bir USB kablosu kullanın ya da ekranı ayrı bir 5V kaynaktan besleyin (GND'ler ortak olmalı).
7. **Ekran bir görünüp kayboluyor, bazen hiç cevap vermiyorsa:** NextionDriver çalışırken USB portunun hızı 9600'den 115200'e kayabiliyor. Ekran 9600'da konuşur, hız uyuşmayınca Pi'nin gönderdiklerini işlemez. Kontrol: `stty -F /dev/ttyUSB0 speed` çıktısı `9600` olmalı. Güncel `tgekran.sh` bunu 2 saniyede bir denetler ve 9600'e geri alır.
8. **Ekrandaki TG düğmesi "yanıt gelmedi" diyorsa ya da NextionDriver düğmeye basınca çöküyorsa (`systemctl status nextiondriver` → `SEGV`):** düğme Pi'ye ~190 baytlık komut gönderir. Stok NextionDriver 100 baytı aşan veriyi atar, 150 baytlık bir dizi yüzünden de çöker. `pistar/usb-kur.sh` bu iki sınırı yamalayıp derler. Telefondan `http://<hotspot>/admin/tg.php` bu sorundan etkilenmez.

## Dokunmatik düğmeler
USB-TTL bağlantısında ekrandan gönderilen komutlar NextionDriver'a ulaşır. `usb-kur.sh` yamasıyla TG sayfasındaki düğmeler (286, 9, 28681 ...) Pi-Star'da test edildi ve çalışıyor: düğmeye basınca `/etc/ysf2dmr` içindeki `StartupDstId` değişir, `ysf2dmr` yeniden başlar ve ekranda "Baglandi TG ..." yazar.
> Not: TG sayfasına ana ekrandaki **tarih alanına dokunarak** girilir.
