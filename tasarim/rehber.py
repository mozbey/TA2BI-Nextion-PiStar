"""Nextion Editor kurulum rehberini (rehber.html) ve resim klasorunu uretir.
Once: python render.py ve python bayraklar.py ulke_sayilari.txt
"""
import html
import os
import shutil

import render

OUT = os.path.dirname(os.path.abspath(__file__))
RES = os.path.join(OUT, "resimler")
PAGE_ORDER = ["MMDVM", "DMR", "YSF"]          # page id 0,1,2  ve pic id 0,1,2
GREEN565 = render.rgb565(render.GREEN)
RED565 = render.rgb565(render.RED)
PANEL565 = render.rgb565(render.PANEL)

MAXL = {"t2": 24, "t8": 40, "t13": 16, "t14": 30, "t15": 30, "t17": 30, "t16": 30, "t9": 40,
        "tonc": 60, "msg": 30, "t31": 40, "t0": 30, "t1": 30, "t3": 20}
DEFAULT_TXT = {("DMR", "t0"): "1 Listening", ("DMR", "t2"): "2 Listening", ("YSF", "t0"): "Listening"}

MASTER_CMD = "sed -n '/^\\[DMR Network\\]/,/^\\[/s/^Address=\\([0-9]*\\).*/BM \\1/p' /etc/mmdvmhost"

SURE_KOD = """  sure.val++
  dk.val=sure.val/60
  sn.val=sure.val%60
  covx dk.val,tmp.txt,0,0
  if(dk.val<10)
  {
    tsure.txt="0"+tmp.txt
  }else
  {
    tsure.txt=tmp.txt
  }
  covx sn.val,tmp.txt,0,0
  if(sn.val<10)
  {
    tsure.txt=tsure.txt+":0"+tmp.txt
  }else
  {
    tsure.txt=tsure.txt+":"+tmp.txt
  }"""

KOD_MMDVM_TM0 = f"""j0.val=cpuload.val
if(cpuload.val>80)
{{
  j0.pco={RED565}
}}else
{{
  j0.pco={GREEN565}
}}"""

KOD_DMR_TM0 = f"""if(t2.txt!="2 Listening")
{{
{SURE_KOD}
  if(sure.val<4)
  {{
    click pbay,1
  }}
  son.txt=t13.txt+"  "+t14.txt+"  "+t15.txt
}}else
{{
  if(sure.val>0)
  {{
    tonc.txt=son.txt
    sure.val=0
    pbay.pic=3
  }}
}}"""

KOD_YSF_TM0 = f"""if(t0.txt!="Listening")
{{
{SURE_KOD}
  son.txt=t0.txt
}}else
{{
  if(sure.val>0)
  {{
    tonc.txt=son.txt
    sure.val=0
  }}
}}"""


def master_printh():
    hx = " ".join(f"{b:02X}" for b in MASTER_CMD.encode("ascii"))
    return f"printh 2A F1\nprinth {hx}\nprinth FF FF FF"


def copy_images():
    if os.path.isdir(RES):
        shutil.rmtree(RES)
    os.makedirs(RES)
    for i, p in enumerate(PAGE_ORDER):
        shutil.copy(os.path.join(OUT, f"bg_{p}.png"), os.path.join(RES, f"{i:03d}_{p}.png"))
    flags = sorted(os.listdir(os.path.join(OUT, "bayraklar")))
    for f in flags:
        shutil.copy(os.path.join(OUT, "bayraklar", f), os.path.join(RES, f))
    return len(PAGE_ORDER) + len(flags)


def esc(s):
    return html.escape(str(s))


def code_block(code):
    return f'<div class="code"><button onclick="kopyala(this)">Kopyala</button><pre>{esc(code)}</pre></div>'


def page_table(pid, name):
    _, fields = render.PAGES[name]
    rows = []
    for (fid, x, y, w, h, nf, col, al, sample, desc) in fields:
        if x is None or fid in ("j0", "pbay"):
            continue
        vis = "0 (gizli)" if w == 1 else "1"
        xcen = {"sol": "0 (Left)", "sag": "2 (Right)"}.get(al, "0")
        txt = DEFAULT_TXT.get((name, fid), "")
        isbr = "True" if fid == "t8" else "False"
        sw = "#%02x%02x%02x" % col
        rows.append(
            f"<tr><td><b>{fid}</b></td><td>{x}</td><td>{y}</td><td>{w}</td><td>{h}</td>"
            f"<td>{nf}</td><td><span class='sw' style='background:{sw}'></span>{render.rgb565(col)}</td>"
            f"<td>{xcen}</td><td>{MAXL.get(fid, 20)}</td><td>{isbr}</td><td>{vis}</td>"
            f"<td>{esc(txt)}</td><td class='d'>{esc(desc)}</td></tr>")
    return ("<table><tr><th>objname</th><th>x</th><th>y</th><th>w</th><th>h</th><th>font</th>"
            "<th>pco</th><th>xcen</th><th>txt_maxl</th><th>isbr</th><th>vis</th><th>txt</th>"
            "<th>açıklama</th></tr>" + "".join(rows) + "</table>"
            f"<p class='note'>Hepsinde ortak: <b>sta = crop image</b>, <b>picc = {pid}</b>, "
            "<b>ycen = 1 (Center)</b>. Metin kutusu eklemek: Toolbox → <b>Text</b>.</p>")


def build_html(n_pics):
    p = []
    a = p.append
    a("""<!doctype html><html lang="tr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>TA2BI Nextion Rehberi</title>
<style>
:root{--bg:#f6f7fb;--fg:#1a2233;--card:#fff;--mut:#5a6680;--acc:#0a84c6;--line:#dde2ee;--code:#0f1626;--codefg:#e6edf7}
@media (prefers-color-scheme:dark){:root{--bg:#0b1020;--fg:#e6ebf5;--card:#141c2e;--mut:#93a0bc;--acc:#3cc4ff;--line:#26324c}}
body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.55 system-ui,Segoe UI,sans-serif}
main{max-width:1100px;margin:auto;padding:16px}
h1{margin:.2em 0}h2{margin-top:1.8em;border-bottom:2px solid var(--acc);padding-bottom:4px}
.card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:12px 16px;margin:12px 0}
table{border-collapse:collapse;width:100%;font-size:13px;display:block;overflow-x:auto}
th,td{border:1px solid var(--line);padding:4px 7px;text-align:left;white-space:nowrap}
th{background:var(--line)}td.d{white-space:normal;color:var(--mut)}
.sw{display:inline-block;width:12px;height:12px;border-radius:3px;margin-right:5px;vertical-align:-1px;border:1px solid #888}
.code{position:relative}.code pre{background:var(--code);color:var(--codefg);padding:12px;border-radius:8px;overflow-x:auto;font:13px/1.45 Consolas,monospace}
.code button{position:absolute;right:8px;top:8px;border:0;border-radius:6px;padding:4px 10px;background:var(--acc);color:#fff;cursor:pointer}
img.prev{max-width:100%;border-radius:8px;border:1px solid var(--line)}
.note{color:var(--mut)}ol li{margin:4px 0}.warn{border-left:4px solid #e8a400}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:12px}
input[type=checkbox]{transform:scale(1.2);margin-right:6px}
</style></head><body><main>
<h1>TA2BI Nextion Ekran – Kurulum Rehberi</h1>
<p class="note">Ekran: NX4832T035 (480×320, Basic) · Pi-Star + NextionDriver · ScreenLayout 3 · Modlar: DMR + YSF</p>
<div class="grid"><img class="prev" src="onizleme_MMDVM.png"><img class="prev" src="onizleme_DMR.png"><img class="prev" src="onizleme_YSF.png"></div>
""")
    a("""<h2>1. Yeni proje</h2><div class="card"><ol>
<li><code>NextionEditor\\Nextion Editor.exe</code> → <b>File → New</b>, dosya adı: <code>TA2BI.HMI</code> (bu klasöre kaydedin).</li>
<li>Cihaz: <b>Basic → NX4832T035</b> (sekmeden <b>T035</b>'i seçin).</li>
<li>Display Direction: <b>90</b> (yatay, 480×320). Character encoding: <b>iso-8859-9</b> (Türkçe).</li>
</ol></div>""")
    a("""<h2>2. Yazı tipleri (Fonts)</h2><div class="card"><p><b>Tools → Font Generator</b> ile şu sırada 4 font üretin
ve her birini projeye ekleyin (<i>Add the generated font</i> kutusu işaretli). Sıra önemli: font id 0,1,2,3 olur.</p>
<table><tr><th>id</th><th>Height</th><th>Font</th><th>Bold</th><th>Encoding</th></tr>
<tr><td>0</td><td>16</td><td>Segoe UI Semibold</td><td>✔</td><td>iso-8859-9</td></tr>
<tr><td>1</td><td>24</td><td>Segoe UI Semibold</td><td>✔</td><td>iso-8859-9</td></tr>
<tr><td>2</td><td>32</td><td>Segoe UI</td><td>✔</td><td>iso-8859-9</td></tr>
<tr><td>3</td><td>48</td><td>Segoe UI</td><td>✔</td><td>iso-8859-9</td></tr></table></div>""")
    a(f"""<h2>3. Resimler (Pictures)</h2><div class="card"><p>Sol alttaki <b>Picture</b> panelinde <b>+</b> (Add) →
<code>tasarim\\resimler</code> klasöründeki <b>{n_pics} dosyanın hepsini</b> seçin (Ctrl+A) → Aç.</p>
<p>Kontrol: <b>0</b> = MMDVM arka planı, <b>1</b> = DMR, <b>2</b> = YSF, <b>3</b> = boş bayrak, <b>4</b> ve sonrası = bayraklar
(4 ABD, 5 İngiltere, … 10 Türkiye). Dosya adlarının başındaki numara = resim id'si olmalı. Sıra karışırsa durun, bana söyleyin.</p></div>""")
    a("""<h2>4. Sayfalar</h2><div class="card"><p>Sağ üstteki <b>Page</b> panelinde 3 sayfa olsun ve sırayla şöyle adlandırın
(sayfaya tıkla → Attribute'ta <b>objname</b>). Her sayfada: <b>sta = image</b>, <b>pic</b> = aşağıdaki id.</p>
<table><tr><th>page id</th><th>objname</th><th>pic</th></tr><tr><td>0</td><td>MMDVM</td><td>0</td></tr>
<tr><td>1</td><td>DMR</td><td>1</td></tr><tr><td>2</td><td>YSF</td><td>2</td></tr></table>
<p class="note">Her sayfaya ayrıca bir <b>Hotspot</b> ekleyin: objname <b>S0</b>, x=0 y=0 w=120 h=38 (kod gerekmez; MMDVMHost buna tıklar).</p></div>""")

    for pid, name in enumerate(PAGE_ORDER):
        a(f"<h2>{5 + pid}. Sayfa {pid}: {name}</h2><div class='card'>")
        a(page_table(pid, name))
        if name == "MMDVM":
            a(f"""<h3>Ek bileşenler</h3><ul>
<li><b>Progress bar</b> → objname <b>j0</b>, x=21 y=223 w=202 h=7, sta=solid color, bco={PANEL565}, pco={GREEN565}, val=0</li>
<li><b>Variable</b> → objname <b>status</b>, sta=Number, <b>vscope = global</b></li>
<li><b>Variable</b> → objname <b>cpuload</b>, sta=Number</li>
<li><b>Timer</b> → objname <b>tm0</b>, tim=1000, en=1. Timer Event kodu:</li></ul>
{code_block(KOD_MMDVM_TM0)}
<h3>Sayfa olayı: Postinitialize Event (master adını sorar)</h3>
<p class="note">MMDVM sayfasına tıklayın → alttaki Event panelinde <b>Postinitialize Event</b> sekmesine yapıştırın.
NextionDriver bu komutu çalıştırıp sonucu <b>msg</b> kutusuna yazar ("BM 2841").</p>
{code_block(master_printh())}""")
        if name == "DMR":
            a(f"""<h3>Ek bileşenler</h3><ul>
<li><b>Picture</b> → objname <b>pbay</b>, x=424 y=3 w=48 h=32, pic=3</li>
<li><b>Variable</b> sta=Number: <b>sure</b>, <b>dk</b>, <b>sn</b></li>
<li><b>Variable</b> sta=String: <b>tmp</b> (txt_maxl 10), <b>son</b> (txt_maxl 60, <b>vscope = global</b>)</li>
<li><b>tonc</b> metin kutusu: <b>vscope = global</b> (sayfa değişince önceki konuşan kaybolmasın)</li>
<li><b>Timer</b> → objname <b>tm0</b>, tim=1000, en=1. Timer Event kodu:</li></ul>
{code_block(KOD_DMR_TM0)}
<h3>pbay → Touch Press Event (bayrak seçimi)</h3>
<p class="note"><code>tasarim\\bayrak_kodu.txt</code> dosyasının <b>tamamını</b> kopyalayıp pbay'in <b>Touch Press Event</b> sekmesine yapıştırın
(Not Defteri ile açın → Ctrl+A → Ctrl+C). Kod, konuşanın ülkesine (t17) göre bayrağı seçer.</p>""")
        if name == "YSF":
            a(f"""<h3>Ek bileşenler</h3><ul>
<li><b>Variable</b> sta=Number: <b>sure</b>, <b>dk</b>, <b>sn</b></li>
<li><b>Variable</b> sta=String: <b>tmp</b> (txt_maxl 10), <b>son</b> (txt_maxl 60, <b>vscope = global</b>)</li>
<li><b>tonc</b> metin kutusu: <b>vscope = global</b></li>
<li><b>Timer</b> → objname <b>tm0</b>, tim=1000, en=1. Timer Event kodu:</li></ul>
{code_block(KOD_YSF_TM0)}""")
        a("</div>")
    a("""<h2>8. Derle ve SD karta yaz</h2><div class="card"><ol>
<li><b>Compile</b> (F5) → alt pencerede hata olmamalı. Hata varsa metnini bana yapıştırın.</li>
<li><b>Debug</b> ile önizleyin (isterseniz).</li>
<li><b>File → TFT file output</b> → <code>derleme</code> klasörüne kaydedin.</li>
<li>Bana <b>"derledim"</b> yazın: SD karta ben kopyalarım, Pi-Star ayarlarını (ON7LDS, ScreenLayout 3, DMR açık) ben yaparım.</li>
</ol></div>
<h2>Bilinen notlar</h2><div class="card warn"><ul>
<li>Kullanıcı listesindeki Türkçe harfli isimler (ş, ğ, ı) ekranda bozuk görünebilir; liste UTF-8, ekran iso-8859-9.</li>
<li>YSF'de kullanıcı listesi araması yok; bu yüzden YSF sayfasında bayrak/isim gösterilmiyor.</li>
<li>TG adı alanı (t8) NextionDriver'ın belgelerine göre yerleştirildi. İlk DMR denemesinde log'dan doğrulayacağım.</li>
</ul></div>
<script>function kopyala(b){navigator.clipboard.writeText(b.nextElementSibling.textContent);b.textContent='Kopyalandı ✓';setTimeout(()=>b.textContent='Kopyala',1500)}</script>
</main></body></html>""")
    with open(os.path.join(OUT, "rehber.html"), "w", encoding="utf-8") as fh:
        fh.write("".join(p))


if __name__ == "__main__":
    render.render()
    n = copy_images()
    build_html(n)
    print("rehber.html hazir,", n, "resim")
