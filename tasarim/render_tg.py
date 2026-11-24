"""TG secme ve Son duyulanlar sayfalarinin ornek cizimleri.

Konumlar, renkler ve yazi tipleri TA2BI.HMI dosyasindaki bilesenlerden alinmistir (gercek ekran fotografi degildir).
Ciktilar: docs/ekran/tg-baglandi.png, docs/ekran/son-duyulan.png
Calistirma: python tasarim/render_tg.py   (Windows yazi tipleri gerekir, render.py ile ayni)
"""
import os
from PIL import Image, ImageDraw
import render as R

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "docs", "ekran")
FLAGS = os.path.join(HERE, "resimler")
W, H = 480, 320


def rgb565(v):
    return (((v >> 11) & 31) * 255 // 31, ((v >> 5) & 63) * 255 // 63, (v & 31) * 255 // 31)


BG = rgb565(2113)          # sayfa arka plani
WHITE = rgb565(61343)
AMBER = rgb565(64896)
BTN = rgb565(4325)
BTN_BASILI = rgb565(18125)
LABEL = rgb565(36054)
FONT_PX = R.NX_FONTS       # Nextion font id -> yukseklik


def text(d, box, s, font_id, fill, xcen=0, ycen=1):
    x, y, w, h = box
    f = R.font(FONT_PX[font_id], bold=font_id >= 2)
    tw = d.textlength(s, font=f)
    tx = x + (0 if xcen == 0 else (w - tw) / 2 if xcen == 1 else w - tw)
    ty = y + (0 if ycen == 0 else (h - FONT_PX[font_id]) / 2 - 3 if ycen == 1 else h - FONT_PX[font_id])
    d.text((tx, ty), s, font=f, fill=fill)


def button(d, box, s, pressed=False):
    x, y, w, h = box
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=BTN_BASILI if pressed else BTN)
    text(d, box, s, 2, BG if pressed else WHITE, xcen=1, ycen=1)


def tg_sayfasi(path):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    text(d, (20, 8, 440, 40), "TG SEÇİMİ", 2, WHITE)
    text(d, (20, 52, 440, 30), "Baglandi TG 28681", 1, AMBER)
    button(d, (20, 90, 210, 60), "286 Türkiye")
    button(d, (250, 90, 210, 60), "9 Local")
    button(d, (20, 160, 210, 60), "28681", pressed=True)
    button(d, (250, 160, 210, 60), "Geri")
    d.rectangle([20, 236, 229, 295], fill=(255, 255, 255))      # ntg: sayi kutusu
    text(d, (20, 236, 210, 60), "0", 2, (0, 0, 0), xcen=1)
    button(d, (250, 236, 210, 60), "Bağlan")
    img.save(path)


def son_duyulan(path):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    text(d, (8, 2, 200, 34), "SON DUYULANLAR", 1, AMBER)
    text(d, (210, 2, 124, 34), "TG 28681", 1, WHITE, xcen=2)
    d.rectangle([340, 2, 403, 35], fill=BTN)
    text(d, (340, 2, 64, 34), "Geri", 1, (255, 255, 255), xcen=1)
    d.rectangle([410, 2, 473, 35], fill=BTN)
    text(d, (410, 2, 64, 34), "Sil", 1, (255, 255, 255), xcen=1)
    satirlar = [
        ("010_tr", "N TB2ALO", "12 sn"), ("010_tr", "R TA2BI", "8 sn"),
        ("004_us", "N AJ5DG", "21 sn"), ("006_de", "N DL1ABC", "5 sn"),
        ("010_tr", "N TA6EA", "17 sn"), ("032_fi", "N OH2BH", "9 sn"),
        ("018_nl", "N PA3XYZ", "14 sn"), ("005_gb", "N G4ABC", "7 sn"),
    ]
    for i, (bayrak, cagri, sure) in enumerate(satirlar):
        y = 38 + 35 * i
        fl = Image.open(os.path.join(FLAGS, bayrak + ".png")).convert("RGB").resize((48, 32))
        img.paste(fl, (8, y + 1))
        text(d, (64, y, 280, 34), cagri, 1, (255, 255, 255))
        text(d, (350, y, 122, 34), sure, 1, WHITE, xcen=2)
    img.save(path)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    tg_sayfasi(os.path.join(OUT, "tg-baglandi.png"))
    son_duyulan(os.path.join(OUT, "son-duyulan.png"))
    print("tamam:", OUT)
