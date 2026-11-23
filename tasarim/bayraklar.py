"""Ulke bayraklarini indirir, 48x32 Nextion resmine cevirir ve ekran kodunu uretir.

Kullanim: python bayraklar.py <ulke_sayilari.txt>
  (ulke_sayilari.txt: hotspot'taki nextionUsers.csv'den "adet ulke" satirlari)
Cikti:
  bayraklar/NNN_xx.png  -> Editor'e bu sirayla resim olarak eklenir (pic id = NNN)
  bayrak_kodu.txt       -> DMR sayfasindaki koda yapistirilir
"""
import io
import os
import sys
import urllib.request

from PIL import Image

OUT = os.path.dirname(os.path.abspath(__file__))
FLAG_DIR = os.path.join(OUT, "bayraklar")
FW, FH = 48, 32
HEADER_BG = (14, 22, 40)   # render.py baslik rengi ile ayni
LINE = (44, 56, 84)
FIRST_FLAG_PIC = 4         # 0=MMDVM 1=DMR 2=YSF 3=bos bayrak

ISO = {
    "United States": "us", "United Kingdom": "gb", "Germany": "de", "China": "cn", "Italy": "it",
    "Spain": "es", "Turkiye": "tr", "Turkey": "tr", "Brazil": "br", "Canada": "ca", "Poland": "pl",
    "Australia": "au", "Chile": "cl", "Russia": "ru", "France": "fr", "Netherlands": "nl",
    "Japan": "jp", "Austria": "at", "Sweden": "se", "Argentina Republic": "ar",
    "Korea Republic of": "kr", "Greece": "gr", "Thailand": "th", "Switzerland": "ch",
    "Philippines": "ph", "Indonesia": "id", "Belgium": "be", "Denmark": "dk", "Portugal": "pt",
    "Finland": "fi", "Norway": "no", "New Zealand": "nz", "India": "in", "Romania": "ro",
    "Malaysia": "my", "Slovenia": "si", "Czech Republic": "cz", "Mexico": "mx", "Ukraine": "ua",
    "Hungary": "hu", "Colombia": "co", "Bulgaria": "bg", "Serbia": "rs", "South Africa": "za",
    "Puerto Rico": "pr", "Venezuela": "ve", "Croatia": "hr", "Taiwan": "tw",
    "Bosnia and Hercegovina": "ba", "Uruguay": "uy", "Israel": "il", "Ireland": "ie",
    "Panama": "pa", "Hong Kong": "hk", "Slovakia": "sk", "Dominican Republic": "do",
    "Ecuador": "ec", "Luxemburg": "lu", "Costa Rica": "cr", "Belarus": "by", "Kazakhstan": "kz",
    "Lithuania": "lt", "Bangladesh": "bd", "Oman": "om", "Estonia": "ee", "Peru": "pe",
    "Macedonia": "mk", "Trinidad and Tobago": "tt", "Morocco": "ma", "Latvia": "lv", "Cuba": "cu",
    "United Arab Emirates": "ae", "Cyprus": "cy", "Malta": "mt", "Singapore": "sg",
    "Reunion": "re", "Guatemala": "gt", "U.S. Virgin Islands": "vi", "Moldova": "md",
    "Montenegro": "me", "Paraguay": "py", "Kuwait": "kw", "Lebanon": "lb", "Sri Lanka": "lk",
    "Pakistan": "pk", "Iceland": "is", "Bahrain": "bh", "Andorra": "ad", "Guam": "gu",
    "Saudi Arabia": "sa", "Honduras": "hn", "El Salvador": "sv", "San Marino": "sm",
    "Dominica": "dm", "Haiti": "ht", "Georgia": "ge", "Barbados": "bb", "Curacao": "cw",
    "Corsica": "fr", "Qatar": "qa", "Nicaragua": "ni", "Belize": "bz", "Aruba": "aw",
    "Uzbekistan": "uz", "Jamaica": "jm", "Martinique": "mq", "Saint Lucia": "lc",
    "Liechtenstein": "li", "Saint Vincent and the Grenadines": "vc", "Guadeloupe": "gp",
    "Bahamas": "bs", "Algeria": "dz", "Namibia": "na", "Saint Kitts and Nevis": "kn",
    "New Caledonia": "nc", "Gibraltar": "gi", "Bonaire": "bq", "Vietnam": "vn",
    "Mauritius": "mu", "Guyana": "gy", "Papua New Guinea": "pg", "Mozambique": "mz",
    "Jordan": "jo", "Ivory Coast": "ci", "Iraq": "iq", "Grenada": "gd", "Cayman Islands": "ky",
    "Bermuda": "bm", "Azerbaijan": "az", "Armenia": "am", "Nepal": "np", "Kenya": "ke",
    "Ghana": "gh", "Faroe Islands": "fo", "Monaco": "mc", "Maldives": "mv", "Kyrgyzstan": "kg",
    "Iran": "ir", "Greenland": "gl", "Cape Verde": "cv", "Brunei Darussalam": "bn",
    "Micronesia": "fm", "British Virgin Islands": "vg", "Zimbabwe": "zw", "Zambia": "zm",
    "Nigeria": "ng", "Mongolia": "mn", "Madagascar": "mg", "Macao": "mo", "French Guiana": "gf",
    "Falkland Islands": "fk", "Egypt": "eg", "Bolivia": "bo", "Anguilla": "ai", "Vanuatu": "vu",
    "Tanzania": "tz", "Swasiland": "sz", "Suriname": "sr", "Palau": "pw", "Montserrat": "ms",
    "Liberia": "lr", "Lesotho": "ls", "Laos": "la", "Kosovo": "xk", "Chad": "td",
    "Central African Republic": "cf", "Cameroon": "cm", "Burkina Faso": "bf",
    "Antigua and Barbuda": "ag", "Albania": "al", "Aaland Islands": "ax", "Aland Islands": "ax",
    "Yemen": "ye", "Tonga": "to", "Togo": "tg", "Sudan": "sd", "Seychelles": "sc",
    "Senegal": "sn", "Samoa": "ws", "Mauretania": "mr", "Malawi": "mw", "Kiribati": "ki",
    "Guinea": "gn", "Equatorial Guinea": "gq", "Djibouti": "dj", "Cook Islands": "ck",
    "Botswana": "bw", "Ascension Island": "sh", "American Samoa": "as",
}


def read_countries(path):
    names = []
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            parts = line.strip().split(None, 1)
            if len(parts) == 2 and parts[0].isdigit() and not parts[1].startswith("/"):
                names.append((int(parts[0]), parts[1]))
    return names


def make_flag(code):
    url = f"https://flagcdn.com/w80/{code}.png"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    src = Image.open(io.BytesIO(urllib.request.urlopen(req, timeout=30).read())).convert("RGBA")
    src.thumbnail((FW - 2, FH - 2), Image.LANCZOS)
    img = Image.new("RGB", (FW, FH), HEADER_BG)
    ox, oy = (FW - src.width) // 2, (FH - src.height) // 2
    img.paste(src, (ox, oy), src)
    from PIL import ImageDraw
    ImageDraw.Draw(img).rectangle([ox - 1, oy - 1, ox + src.width, oy + src.height], outline=LINE)
    return img


def main():
    countries = read_countries(sys.argv[1])
    os.makedirs(FLAG_DIR, exist_ok=True)
    for f in os.listdir(FLAG_DIR):
        os.remove(os.path.join(FLAG_DIR, f))
    # bos bayrak (bilinmeyen ulke) -> pic 3
    Image.new("RGB", (FW, FH), HEADER_BG).save(os.path.join(FLAG_DIR, "003_bos.png"))

    codes, missing = [], []
    for cnt, name in sorted(countries, key=lambda x: -x[0]):
        code = ISO.get(name)
        if not code:
            missing.append(f"{name} ({cnt})")
        elif code not in codes:
            codes.append(code)
    pic = {c: FIRST_FLAG_PIC + i for i, c in enumerate(codes)}
    for c, n in pic.items():
        make_flag(c).save(os.path.join(FLAG_DIR, f"{n:03d}_{c}.png"))

    # Nextion kodu: en cok kullanicisi olan ulke en basta (hizli eslesme)
    lines = ["// --- bayrak secimi (t17 = ulke) ---", "pbay.pic=3"]
    seen = set()
    for cnt, name in sorted(countries, key=lambda x: -x[0]):
        code = ISO.get(name)
        if code and name not in seen and name.isascii():
            seen.add(name)
            lines.append(f'if(t17.txt=="{name}")\n{{\n  pbay.pic={pic[code]}\n}}')
    with open(os.path.join(OUT, "bayrak_kodu.txt"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    print(f"{len(codes)} bayrak, pic {FIRST_FLAG_PIC}..{FIRST_FLAG_PIC + len(codes) - 1}")
    print("eslesmeyen:", ", ".join(missing) or "yok")


if __name__ == "__main__":
    main()
