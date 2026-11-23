"""TA2BI Nextion NX4832T035 (480x320) koyu tema tasarimi.

Ciktilar (bu dosyanin klasorune):
  bg_MMDVM.png, bg_DMR.png         -> Nextion Editor'de sayfa arka plani (sta=image)
  onizleme_MMDVM.png, onizleme_DMR.png -> ornek verili gorunum
  bilesenler.csv                   -> Editor'de olusturulacak bilesen listesi
"""
import csv
import os
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.dirname(os.path.abspath(__file__))
W, H = 480, 320
FONTS = r"C:\Windows\Fonts"

# Renkler (RGB565'e iyi oturan tonlar)
BG = (8, 12, 24)
PANEL = (20, 28, 46)
LINE = (44, 56, 84)
WHITE = (236, 240, 248)
GREY = (140, 152, 176)
CYAN = (0, 200, 248)
AMBER = (248, 176, 0)
GREEN = (64, 216, 104)
VIOLET = (168, 128, 248)
RED = (248, 72, 72)

# Nextion font id -> yukseklik (Editor > Tools > Font Generator ile ayni sirada uretin)
NX_FONTS = {0: 16, 1: 24, 2: 32, 3: 48}


def font(px, bold=False, mono=False):
    if mono:
        name = "consolab.ttf" if bold else "consola.ttf"
    else:
        name = "segoeuib.ttf" if bold else "seguisb.ttf"
    return ImageFont.truetype(os.path.join(FONTS, name), px)


def rgb565(c):
    r, g, b = c
    return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)


def panel(d, x, y, w, h, accent, label=None):
    d.rounded_rectangle([x, y, x + w - 1, y + h - 1], radius=8, fill=PANEL, outline=LINE)
    d.rectangle([x + 1, y + 8, x + 4, y + h - 9], fill=accent)
    if label:
        d.text((x + 12, y + 5), label, font=font(13, bold=True), fill=accent)


# ---------------------------------------------------------------- sayfalar
# Her alan: (ad, x, y, w, h, nx_font, renk, hizalama, ornek_metin, aciklama)
PAGES = {}


def page_mmdvm():
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    # baslik
    d.rectangle([0, 0, W, 46], fill=(14, 22, 40))
    d.rectangle([0, 46, W, 47], fill=CYAN)
    d.text((14, 2), "TA2BI", font=font(34, bold=True), fill=WHITE)
    d.text((132, 18), "DMR HOTSPOT", font=font(13, bold=True), fill=CYAN)
    # durum seridi
    panel(d, 8, 54, 464, 32, CYAN)
    # frekanslar
    panel(d, 8, 92, 228, 64, AMBER, "TX FREKANS")
    panel(d, 244, 92, 228, 64, AMBER, "RX FREKANS")
    d.text((196, 124), "MHz", font=font(13, bold=True), fill=GREY)
    d.text((432, 124), "MHz", font=font(13, bold=True), fill=GREY)
    # cpu
    panel(d, 8, 162, 228, 112, GREEN, "İŞLEMCİ")
    d.text((20, 236), "YÜK", font=font(12, bold=True), fill=GREY)
    d.text((128, 236), "FREKANS", font=font(12, bold=True), fill=GREY)
    d.rectangle([20, 222, 223, 230], outline=LINE)  # cubuk cercevesi
    # ag
    panel(d, 244, 162, 228, 112, VIOLET, "AĞ")
    d.text((256, 184), "IP", font=font(12, bold=True), fill=GREY)
    d.text((256, 220), "MASTER", font=font(12, bold=True), fill=GREY)
    d.text((402, 186), "DISK", font=font(12, bold=True), fill=GREY)
    # alt bilgi
    d.rectangle([0, 280, W, 281], fill=LINE)
    fields = [
        ("t2", 230, 10, 240, 28, 1, WHITE, "sag", "11/22/26 23:41:05", "Tarih/saat (MMDVMHost)"),
        ("t1", 20, 58, 230, 24, 1, GREEN, "sol", "MMDVM IDLE", "Durum"),
        ("t0", 254, 60, 210, 20, 0, GREY, "sag", "TA2BI/1234567", "Cagri/ID"),
        ("t32", 16, 116, 176, 34, 2, WHITE, "sol", "438.800000", "TX frekans (NextionDriver)"),
        ("t30", 252, 116, 176, 34, 2, WHITE, "sol", "438.800000", "RX frekans (NextionDriver)"),
        ("t20", 20, 180, 200, 36, 2, WHITE, "sol", "47.24 'C", "CPU sicaklik"),
        ("j0", 21, 223, 202, 7, None, GREEN, "-", "", "Ilerleme cubugu (yuk %) - bco=PANEL pco=GREEN"),
        ("t22", 20, 250, 96, 20, 0, WHITE, "sol", "0.42", "Sistem yuku"),
        ("t21", 128, 250, 100, 20, 0, WHITE, "sol", "1200 MHz", "CPU frekans"),
        ("t3", 256, 198, 140, 22, 1, WHITE, "sol", "192.168.1.50", "IP adresi"),
        ("t23", 402, 198, 62, 22, 1, WHITE, "sol", "71%", "Bos disk %"),
        ("msg", 256, 234, 208, 34, 1, AMBER, "sol", "BM 2841 Bulgaria", "Master adi (komut sonucu)"),
        ("t31", 10, 288, 300, 26, 1, GREY, "sol", "Istanbul, TR", "Konum (MMDVM.ini)"),
        ("cpuload", None, None, None, None, None, None, "-", "", "Variable (Number) - NextionDriver yazar"),
    ]
    PAGES["MMDVM"] = (img, fields)


def page_dmr():
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, 38], fill=(14, 22, 40))
    d.rectangle([0, 38, W, 39], fill=AMBER)
    d.text((14, 2), "TA2BI", font=font(26, bold=True), fill=WHITE)
    d.rounded_rectangle([108, 9, 160, 30], radius=5, fill=AMBER)
    d.text((116, 9), "DMR", font=font(15, bold=True), fill=BG)
    d.text((176, 12), "SLOT 2", font=font(13, bold=True), fill=GREY)
    # aktif konusan
    panel(d, 8, 46, 300, 158, CYAN, "KONUŞAN")
    # tg
    panel(d, 316, 46, 156, 158, AMBER, "KONUŞMA GRUBU")
    # istatistik
    panel(d, 8, 210, 148, 46, GREEN, "SİNYAL")
    panel(d, 164, 210, 148, 46, GREEN, "BER")
    panel(d, 320, 210, 152, 46, GREEN, "SÜRE")
    # onceki
    panel(d, 8, 262, 464, 30, VIOLET)
    d.text((18, 269), "ÖNCEKİ", font=font(12, bold=True), fill=VIOLET)
    # slot 1 seridi
    d.text((10, 300), "TS1", font=font(12, bold=True), fill=GREY)
    fields = [
        ("t13", 20, 64, 280, 50, 3, WHITE, "sol", "TA1ABC", "Cagri isareti (NextionDriver)"),
        ("t14", 20, 116, 280, 34, 2, CYAN, "sol", "Mehmet", "Isim"),
        ("t15", 20, 152, 280, 24, 1, GREY, "sol", "Ankara", "Sehir"),
        ("t17", 20, 176, 280, 24, 1, GREY, "sol", "Turkey", "Ulke"),
        ("t2", 324, 172, 140, 24, 0, GREY, "sol", "2 Net TA1ABC", "Ham kaynak (MMDVMHost)"),
        ("t3", 324, 66, 140, 36, 2, AMBER, "sol", "TG2841", "Hedef TG"),
        ("t8", 324, 106, 140, 60, 1, WHITE, "sol", "Bulgaria", "TG adi (NextionDriver), ism=1 cok satir"),
        ("t5", 18, 228, 130, 24, 1, WHITE, "sol", "-62dBm", "RSSI slot 2"),
        ("t7", 174, 228, 130, 24, 1, WHITE, "sol", "0.4%", "BER slot 2"),
        ("tsure", 330, 228, 130, 24, 1, WHITE, "sol", "00:12", "Sure (ekran kodu sayar)"),
        ("tonc", 80, 266, 384, 24, 1, WHITE, "sol", "TA2XYZ  Ali  Izmir", "Onceki konusan (ekran kodu)"),
        ("t0", 44, 296, 190, 22, 0, GREY, "sol", "1 Listening", "Slot 1 kaynak"),
        ("t1", 240, 296, 110, 22, 0, GREY, "sol", "", "Slot 1 hedef"),
        ("t4", 356, 296, 56, 22, 0, GREY, "sag", "", "Slot 1 RSSI"),
        ("t6", 416, 296, 56, 22, 0, GREY, "sag", "", "Slot 1 BER"),
        ("t9", 0, 0, 1, 1, 0, BG, "-", "", "Talker alias slot2 - vis 0"),
        ("t16", 0, 0, 1, 1, 0, BG, "-", "", "Eyalet - vis 0"),
        ("tm0", None, None, None, None, None, None, "-", "", "Timer 1000 ms - sure/onceki kodu"),
        ("pbay", 424, 3, 48, 32, None, None, "-", "tr", "Picture - ulke bayragi (pic 3 = bos)"),
    ]
    PAGES["DMR"] = (img, fields)


def page_ysf():
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, 38], fill=(14, 22, 40))
    d.rectangle([0, 38, W, 39], fill=VIOLET)
    d.text((14, 2), "TA2BI", font=font(26, bold=True), fill=WHITE)
    d.rounded_rectangle([108, 9, 160, 30], radius=5, fill=VIOLET)
    d.text((117, 9), "YSF", font=font(15, bold=True), fill=BG)
    d.text((176, 12), "SYSTEM FUSION", font=font(13, bold=True), fill=GREY)
    panel(d, 8, 46, 300, 158, CYAN, "KONUŞAN")
    panel(d, 316, 46, 156, 158, AMBER, "HEDEF")
    panel(d, 8, 210, 148, 46, GREEN, "SİNYAL")
    panel(d, 164, 210, 148, 46, GREEN, "BER")
    panel(d, 320, 210, 152, 46, GREEN, "SÜRE")
    panel(d, 8, 262, 464, 30, VIOLET)
    d.text((18, 269), "ÖNCEKİ", font=font(12, bold=True), fill=VIOLET)
    fields = [
        ("t0", 20, 80, 280, 50, 3, WHITE, "sol", "Net TA1ABC", "Kaynak (tip + cagri)"),
        ("t2", 20, 150, 280, 34, 1, CYAN, "sol", "at TA1ABC-HS", "Gelis yeri (at/via)"),
        ("t1", 324, 76, 140, 36, 2, AMBER, "sol", "ALL", "Hedef / DG-ID"),
        ("t3", 18, 228, 130, 24, 1, WHITE, "sol", "-58dBm", "RSSI"),
        ("t4", 174, 228, 130, 24, 1, WHITE, "sol", "0.0%", "BER"),
        ("tsure", 330, 228, 130, 24, 1, WHITE, "sol", "00:07", "Sure (ekran kodu sayar)"),
        ("tonc", 80, 266, 384, 24, 1, WHITE, "sol", "Net TA2XYZ", "Onceki konusan (ekran kodu)"),
        ("tm0", None, None, None, None, None, None, "-", "", "Timer 1000 ms - sure/onceki kodu"),
    ]
    PAGES["YSF"] = (img, fields)


def render():
    page_mmdvm()
    page_dmr()
    page_ysf()
    rows = []
    for name, (bg, fields) in PAGES.items():
        bg.save(os.path.join(OUT, f"bg_{name}.png"))
        prev = bg.copy()
        d = ImageDraw.Draw(prev)
        for (fid, x, y, w, h, nf, col, al, sample, desc) in fields:
            rows.append([name, fid, x, y, w, h, nf, NX_FONTS.get(nf, ""),
                         rgb565(col) if col else "", al, desc])
            if x is None or not sample and fid != "j0":
                continue
            if fid == "pbay":
                flag = os.path.join(OUT, "bayraklar", "010_tr.png")
                if os.path.exists(flag):
                    prev.paste(Image.open(flag), (x, y))
                continue
            if fid == "j0":
                d.rectangle([x, y, x + int(w * 0.42), y + h - 1], fill=GREEN)
                continue
            f = font(int(NX_FONTS[nf] * 0.78), bold=nf >= 2, mono=fid in ("t32", "t30", "t3", "t2") and name == "MMDVM")
            tw = d.textlength(sample, font=f)
            tx = x + w - tw if al == "sag" else x
            d.text((tx, y + (h - NX_FONTS[nf]) // 2), sample, font=f, fill=col)
        prev.save(os.path.join(OUT, f"onizleme_{name}.png"))
        prev.resize((W * 2, H * 2), Image.NEAREST).save(os.path.join(OUT, f"onizleme_{name}_2x.png"))
    with open(os.path.join(OUT, "bilesenler.csv"), "w", newline="", encoding="utf-8-sig") as fh:
        wr = csv.writer(fh, delimiter=";")
        wr.writerow(["sayfa", "ad", "x", "y", "w", "h", "font_id", "font_px", "pco_rgb565", "hiza", "aciklama"])
        wr.writerows(rows)


if __name__ == "__main__":
    render()
    print("tamam:", OUT)
