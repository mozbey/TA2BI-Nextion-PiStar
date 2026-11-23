<?php
/**
 * TA2BI - YSF2DMR TG secimi (telefon icin)
 * Adres: http://<hotspot>/admin/tg.php  (Pi-Star admin sifresi ister)
 * Islem: sudo /opt/ta2bi/tgset.sh <TG>
 */
require_once($_SERVER['DOCUMENT_ROOT'].'/config/security_headers.php');
require_once($_SERVER['DOCUMENT_ROOT'].'/config/csrf.php');
setSecurityHeaders();
csrf_verify();

$CONF = '/etc/ysf2dmr';
$HAZIR = array(
    286   => 'Türkiye',
    2861  => 'TG 2861',
    28681 => 'TG 28681',
    91    => 'Dünya',
    92    => 'Avrupa',
    9     => 'Yerel',
    4000  => 'Bağlantıları kes',
);

function mevcut_tg($conf) {
    foreach (@file($conf) ?: array() as $l) {
        if (preg_match('/^StartupDstId=(\d+)/', $l, $m)) return $m[1];
    }
    return '?';
}

function son_log() {
    $f = glob('/var/log/pi-star/YSF2DMR-*.log');
    if (!$f) return array();
    rsort($f);
    $satirlar = @file($f[0]) ?: array();
    $ilgili = array();
    foreach ($satirlar as $s) {
        if (preg_match('/Logged into|DstID: TG|timed out|Socket has failed|Opening DMR|Closing DMR|Connect to TG/', $s)) $ilgili[] = trim($s);
    }
    return array_slice($ilgili, -6);
}

$mesaj = '';
$yenile = false;
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $tg = isset($_POST['tg']) ? trim($_POST['tg']) : '';
    if (!preg_match('/^\d{1,7}$/', $tg) || intval($tg) < 1) {
        $mesaj = 'Geçersiz TG numarası.';
    } else {
        $cikti = array(); $rc = 0;
        exec('sudo /opt/ta2bi/tgset.sh ' . escapeshellarg($tg) . ' 2>&1', $cikti, $rc);
        $mesaj = implode(' ', $cikti);
        if ($rc === 0) { $yenile = true; }
    }
}
$tg_simdi = mevcut_tg($CONF);
$log = son_log();
$bagli = false;
foreach ($log as $s) { if (strpos($s, 'Logged into') !== false) $bagli = true; if (strpos($s, 'Closing DMR') !== false || strpos($s, 'Opening DMR') !== false) $bagli = false; if (strpos($s, 'Logged into') !== false) $bagli = true; }
?><!doctype html>
<html lang="tr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<?php if ($yenile) { echo '<meta http-equiv="refresh" content="15;url=tg.php">'; } ?>
<title>TA2BI TG</title>
<style>
:root{--bg:#080c18;--panel:#141c2e;--line:#2c3854;--fg:#ecf0f8;--mut:#8c98b0;--cyan:#00c8f8;--amber:#f8b000;--green:#40d868;--red:#f84848}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.4 system-ui,Segoe UI,sans-serif}
main{max-width:520px;margin:auto;padding:16px}
h1{font-size:22px;margin:4px 0 12px}h1 span{color:var(--cyan)}
.card{background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:14px;margin:12px 0}
.big{font-size:40px;font-weight:700;color:var(--amber)}
.dur{display:inline-block;padding:2px 10px;border-radius:20px;font-size:13px;font-weight:600}
.ok{background:#12351f;color:var(--green)}.bekle{background:#3a2e08;color:var(--amber)}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:10px}
button{width:100%;padding:14px 8px;border-radius:10px;border:1px solid var(--line);background:#1c2742;color:var(--fg);font-size:17px;font-weight:600}
button small{display:block;font-size:12px;color:var(--mut);font-weight:400}
button.aktif{border-color:var(--amber);background:#33290a}
.ozel{display:flex;gap:8px}.ozel input{flex:1;padding:12px;border-radius:10px;border:1px solid var(--line);background:#0f1628;color:var(--fg);font-size:18px}
.ozel button{width:auto;padding:12px 18px;background:var(--cyan);color:#06101c;border:0}
.msg{padding:10px;border-radius:8px;background:#10263a;color:var(--cyan)}
pre{white-space:pre-wrap;font:12px/1.4 Consolas,monospace;color:var(--mut);margin:0}
a{color:var(--cyan)}
</style></head><body><main>
<h1>TA2BI <span>YSF → DMR</span> TG</h1>
<div class="card">
  <div>Şu anki TG</div>
  <div class="big">TG <?php echo htmlspecialchars($tg_simdi); ?></div>
  <?php if ($yenile): ?><span class="dur bekle">BrandMeister'a bağlanıyor… (15 sn)</span>
  <?php elseif ($bagli): ?><span class="dur ok">BrandMeister bağlı</span>
  <?php else: ?><span class="dur bekle">Bağlantı bekleniyor</span><?php endif; ?>
</div>
<?php if ($mesaj !== ''): ?><div class="msg"><?php echo htmlspecialchars($mesaj); ?></div><?php endif; ?>
<form method="post" class="card">
  <?php csrf_field(); ?>
  <div class="grid">
  <?php foreach ($HAZIR as $no => $ad): ?>
    <button name="tg" value="<?php echo $no; ?>" class="<?php echo ((string)$no === $tg_simdi) ? 'aktif' : ''; ?>">TG <?php echo $no; ?><small><?php echo htmlspecialchars($ad); ?></small></button>
  <?php endforeach; ?>
  </div>
</form>
<div class="card" style="font-size:14px;color:var(--mut)"><b style="color:var(--amber)">Eski TG duyulmaya devam ederse:</b> BrandMeister, PTT yaptığınız her TG'yi 15 dk "dinamik" olarak açık tutar. Temizlemek için: <b>TG 4000</b>'e basın → 15 sn bekleyin → 1 sn PTT → sonra istediğiniz TG'yi seçip 1 sn PTT.</div>
<form method="post" class="card">
  <?php csrf_field(); ?>
  <div style="margin-bottom:8px">Başka bir TG</div>
  <div class="ozel"><input name="tg" inputmode="numeric" pattern="[0-9]{1,7}" placeholder="örn. 28625" required><button>Geç</button></div>
</form>
<div class="card"><div style="margin-bottom:6px">Son olaylar (YSF2DMR)</div><pre><?php echo htmlspecialchars(implode("\n", $log)); ?></pre></div>
<p><a href="/admin/">← Pi-Star yönetim</a> · <a href="tg.php">Yenile</a></p>
<p style="color:var(--mut);font-size:13px">Not: TG değişince YSF2DMR yeniden başlar ve BrandMeister'a ~15 saniyede tekrar bağlanır. Pi-Star ayar sayfasında “Apply” yapmadan önce sayfayı yenileyin, yoksa eski TG geri yazılır.</p>
</main></body></html>
