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
1. Dönüştürücüyü Pi'ye takın. SSH'ta `ls /dev/ttyUSB*` komutu `/dev/ttyUSB0` göstermeli. CH340/CP2102 sürücüleri Pi-Star'da hazır gelir.
2. **Configuration → MMDVMHost Configuration** bölümünde:
   - MMDVM Display Type: `Nextion`
   - Port: `/dev/ttyUSB0`
   - Nextion Layout: `ON7LDS L2`
   - **Apply Changes** (önce sayfayı F5 ile yenileyin)
3. Bu ayardan sonra `[Transparent Data]` bölümüne gerek kalmaz; isterseniz `Enable=0` yapabilirsiniz.
4. Kontrol için SSH'ta şunları çalıştırın:
   ```bash
   grep -A2 '^\[NextionDriver\]' /etc/mmdvmhost     # Port=/dev/ttyUSB0 olmalı
   sudo systemctl restart nextiondriver mmdvmhost
   ```

## Sorun giderme
Ekranda hiçbir şey görünmüyorsa:
- TX ve RX kablolarının yerini değiştirin. En sık yapılan hata budur.
- GND'nin bağlı olduğundan emin olun.
- `/var/log/pi-star/` içindeki MMDVM kaydında NextionDriver hatası olup olmadığına bakın.

## Dokunmatik düğmeler
USB-TTL bağlantısında ekrandan gönderilen komutlar NextionDriver'a ulaşır. Bu sayede TG sayfasındaki düğmelerin çalışması beklenir.
> Not: Yazarın kurulumunda ekran henüz modem portunda olduğu için düğmeler USB-TTL ile **test edilmedi**. Deneyimlerinizi bir Issue açarak paylaşabilirsiniz.
