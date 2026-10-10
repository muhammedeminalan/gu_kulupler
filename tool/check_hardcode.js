#!/usr/bin/env node
'use strict';
/**
 * Hardcode denetimi (CLAUDE.md §6, D-15).
 *   node tool/check_hardcode.js                 # tüm proje
 *   node tool/check_hardcode.js --files a.dart b.dart
 *   node tool/check_hardcode.js --list          # kural listesi
 *   node tool/check_hardcode.js --root <dir>    # (test) proje kökü
 * Satır içi istisna:  // ignore-hardcode: <gerekçe>   (aynı satır ya da bir önceki yorum satırı)
 * Çıkış kodu: 0 temiz, 1 ihlal.
 */
const fs = require('fs');
const path = require('path');
const core = require('./lib/scan_core');

const argv = process.argv.slice(2);
const root = core.projectRoot(argv);
const M = core.STR_MARK;

// ── yol sınıfları ──────────────────────────────────────────
const isGenerated = (p) => /\.(g|gen|freezed)\.dart$/.test(p) || /lib\/l10n\/app_localizations/.test(p) || /(^|\/)firebase_options\.dart$/.test(p);
const inLib = (p) => /\.dart$/.test(p) && /^(lib|packages\/[^/]+\/lib)\//.test(p) && !isGenerated(p);
const isTokenish = (p) => /\/(tokens|theme|constants)\//.test(p) || /(^|\/)(gu_icons|gu_illustrations|app_constants)\.dart$/.test(p);
const isUi = (p) => inLib(p) && (/^lib\/(features|product)\//.test(p) || /^packages\/gu_ui\/lib\//.test(p)) && !isTokenish(p);
const isApp = (p) => inLib(p) && /^lib\/(features|product)\//.test(p);
const isAny = (p) => inLib(p) && !isTokenish(p);
const isViewish = (p) => inLib(p) && (/^lib\/features\/[^/]+\/view\//.test(p) || /^lib\/product\/(widget|navigation)\//.test(p) || /^packages\/gu_ui\/lib\//.test(p) || /_(view|widget|sheet|dialog)\.dart$/.test(p));
const isOverlayDir = (p) => /^packages\/gu_ui\/lib\/src\/overlay\//.test(p) || /^lib\/product\/feedback\//.test(p);
const isLogger = (p) => /(^|\/)app_logger\.dart$/.test(p);
// HC12c (CD-113): overlay açan çağıranlar — feature kodu ve alan-bilen ortak widget'lar.
const isFeedbackCaller = (p) => inLib(p) && (/^lib\/features\//.test(p) || /^lib\/product\/widget\//.test(p));
// gu_ui primitifleri + Flutter'ın eşdeğer global fonksiyonları (tek giriş FeedbackService — CLAUDE.md §7).
const OVERLAY_CALL_RE = /(?<![\w.$])(?:showGuSheet|showGuDialog|showGuPopMenu|showGuOverlay|showModalBottomSheet|showBottomSheet|showDialog|showGeneralDialog|showAdaptiveDialog|showCupertinoDialog|showCupertinoModalPopup|showMenu)\s*(?:<[^;(){}]*>)?\s*\(/;
// Çağrı mı, aynı adlı metot bildirimi mi? Bildirimde addan önce dönüş tipi gelir (`Future<void> showMenu(`, `bool? showDialog(`,
// `void showMenu(`); çağrıda ifade başı, `=>`, üçlü `? ` ya da bir anahtar sözcük (`await`, `return` …).
const CALL_PREFIX_WORDS = /^(?:await|return|yield|throw|else|do|in|case|when|is|as)$/;
function isCallSite(m, lines, text) {
  const before = text.slice(Math.max(0, m.index - 200), m.index).replace(/\s+$/, '');
  if (/=>$/.test(before)) return true;
  if (/[\w$>\]]\?$/.test(before) || /[>\]]$/.test(before)) return false;
  const word = /([A-Za-z_$][\w$]*)$/.exec(before);
  return !word || CALL_PREFIX_WORDS.test(word[1]);
}

const LETTER = /[A-Za-zÇĞİÖŞÜçğıöşüÂâÎîÛû]/;
const stripInterp = (s) => s.replace(/\$\{[^}]*\}/g, '').replace(/\$[A-Za-z_]\w*/g, '');

function literalFinder(re, label) {
  return ({ lines, text, offs }) => {
    const out = [];
    const r = new RegExp(re.source, re.flags.includes('g') ? re.flags : re.flags + 'g');
    let m;
    while ((m = r.exec(text))) {
      const idx = core.lineAt(offs, m.index);
      const k = m[m.length - 1];
      // string literal dizinini bul (satırın strs'i)
      const mm = /\u0001(\d+)\u0001/.exec(m[0]);
      if (!mm) continue;
      // literal hangi satırda? m[0] içindeki işaretin bulunduğu satır
      const pos = m.index + m[0].indexOf(mm[0]);
      const li = core.lineAt(offs, pos);
      const s = lines[li].strs[parseInt(mm[1], 10)];
      if (s === undefined) continue;
      if (!LETTER.test(stripInterp(s))) continue;
      if (core.markerOn(lines, li, core.IGNORE_RE)) continue;
      out.push({ line: li + 1, msg: `${label}: "${s.slice(0, 40)}" → ARB (context.l10n.*)` });
    }
    return out;
  };
}

const NUM = '(?<![\\w.$])\\d';
const rules = [
  { id: 'HC01', msg: 'Renk literal: Color(0x…)/Color.fromARGB → context.gu.colors.*', scope: isAny, re: /\bColor\(\s*0x|\bColor\.from(?:ARGB|RGBO)\(/ },
  { id: 'HC02', msg: 'Material/Cupertino renk sabiti → context.gu.colors.* (Colors.transparent serbest)', scope: isAny, re: /\b(?:Colors|CupertinoColors)\.(?!transparent\b)\w+/ },
  { id: 'HC03', msg: 'Theme.of(context) doğrudan → context.gu.* extension', scope: (p) => inLib(p) && !/^packages\/gu_ui\/lib\/src\/theme\//.test(p), re: /\bTheme\.of\(/ },
  { id: 'HC04', msg: 'Sayısal boşluk: EdgeInsets → GuSpacing/GuInsets', scope: isUi, re: /\bEdgeInsets(?:Directional)?\.(?:all|only|symmetric|fromLTRB|fromSTEB)\(([^)]*)\)/, test: (m) => core.hasNonZeroNumber(m[1]) },
  { id: 'HC06', msg: 'Sayısal radius → GuRadius.*', scope: isUi, re: /\b(?:BorderRadius\.(?:circular|all)|Radius\.circular)\(([^)]*)\)/, test: (m) => core.hasNonZeroNumber(m[1]) },
  { id: 'HC07', msg: 'Tipografi literal (fontSize/FontWeight/fontFamily) → context.gu.text.*', scope: isUi, re: /\bfontSize\s*:\s*[\d.]|\bFontWeight\.\w+|\bfontFamily\s*:|\bletterSpacing\s*:\s*-?[\d.]/ },
  { id: 'HC08', msg: 'Süre/eğri literal → GuMotion.* (iş süreleri Limits/constants içinde)', scope: isUi, re: /\bDuration\(\s*(?:microseconds|milliseconds|seconds|minutes|hours|days)\s*:\s*\d|\bCurves\.\w+/ },
  {
    id: 'HC09', msg: 'UI metni → ARB', scope: isUi,
    fn: (ctx) => []
      .concat(literalFinder(/\b(?:Text|SelectableText|Tooltip)\(\s*(?:message\s*:\s*|text\s*:\s*)?"\u0001\d+\u0001"/, 'Text')(ctx))
      .concat(literalFinder(/\b(?:label|title|subtitle|hint|hintText|helperText|errorText|labelText|tooltip|semanticLabel|semanticsLabel|message|description|placeholder|content|actionLabel|caption|text)\s*:\s*"\u0001\d+\u0001"/, 'Parametre')(ctx)),
  },
  { id: 'HC10', msg: 'Material/Cupertino ikon → GuIcon(GuIcons.*)', scope: isAny, re: /\b(?:Icons|CupertinoIcons)\.[a-z_]\w*|\bIconData\(/ },
  { id: 'HC11', msg: 'print/debugPrint → AppLogger', scope: (p) => inLib(p) && !isLogger(p), re: /(?<![\w.])(?:print|debugPrint)\s*\(/ },
  { id: 'HC12', msg: 'Navigator.push* yasak → go_router (guard\'lı rota: go)', scope: inLib, re: /\bNavigator\.(?:push|pushNamed|pushReplacement|pushReplacementNamed|pushAndRemoveUntil|pushNamedAndRemoveUntil|popAndPushNamed)\b/ },
  { id: 'HC12b', msg: 'Navigator.of/pop yalnızca overlay çerçevelerinde (gu_ui/overlay, product/feedback); başka yerde context.pop()/FeedbackService', scope: (p) => inLib(p) && !isOverlayDir(p), re: /\bNavigator\.(?:of|pop|maybePop|canPop)\b/ },
  { id: 'HC12c', msg: 'Overlay primitifi doğrudan çağrılamaz (showGuSheet/showGuDialog/showGuPopMenu/showModalBottomSheet/showDialog/showMenu …) → FeedbackService.showSheet/showDialog/showMenu (CD-113)', scope: isFeedbackCaller, re: OVERLAY_CALL_RE, test: isCallSite },
  { id: 'HC13', msg: 'View/widget katmanında GetIt yasak → mixin (AppProviderMixin/ProjectDependencyMixin)', scope: (p) => inLib(p) && (isViewish(p) || /^packages\/gu_ui\//.test(p)), re: /\bGetIt\b/ },
  { id: 'HC14', msg: 'Düz StatefulWidget/State yasak → ConsumerStatefulWidget/ConsumerState', scope: isApp, re: /\bextends\s+(?:StatefulWidget|State<)/ },
  { id: 'HC15', msg: 'Sayısal ölçü parametresi → token (GuSizes/GuSpacing/…)', scope: isUi, re: new RegExp('\\b(?:width|height|size|minWidth|minHeight|maxWidth|maxHeight|radius|thickness|elevation|blurRadius|spreadRadius|strokeWidth|dimension|iconSize|top|bottom|left|right)\\s*:\\s*' + NUM + '[\\d.]*'), test: (m) => core.hasNonZeroNumber(m[0].replace(/^[^:]*:/, '')) },
  { id: 'HC16', msg: 'Sayısal Size(…)/Offset(…) → token', scope: isUi, re: /\b(?:Size|Offset)\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)/, test: (m) => parseFloat(m[1]) !== 0 || parseFloat(m[2]) !== 0 },
  { id: 'HC17', msg: 'Opaklık literal (withOpacity/withValues(alpha:)/withAlpha/Opacity) → renk token\'ı', scope: isUi, re: /\.withOpacity\(|\.withValues\(\s*alpha\s*:\s*[\d.]|\.withAlpha\(\s*\d|\bOpacity\(\s*opacity\s*:\s*[\d.]/ },
  {
    id: 'HC18', msg: 'URL/e-posta literal → AppConstants/constants', scope: (p) => inLib(p) && !isTokenish(p),
    fn: ({ lines }) => {
      const out = [];
      lines.forEach((l, i) => l.strs.forEach((s) => { if (/\b(?:https?:\/\/|mailto:|tel:)/i.test(s) && !core.markerOn(lines, i, core.IGNORE_RE)) out.push({ line: i + 1, msg: `URL/e-posta literal: "${s.slice(0, 40)}"` }); }));
      return out;
    },
  },
  { id: 'HC19', msg: 'Limit sayısı kodda sabit → Limits sabiti', scope: isAny, re: /\.length\s*(?:<=|>=|==|!=|<|>)\s*\d{2,}|\b\d{2,}\s*(?:<=|>=|<|>)\s*[\w.]+\.length/ },
  { id: 'HC20', msg: 'Placeholder() yalnızca sahibi yazılı geçici sekme kökü olabilir: // TODO(T-xx)', scope: isApp,
    re: /\bPlaceholder\(/, test: (m, lines, text) => {
      const idx = text.slice(0, m.index).split('\n').length - 1;
      return !(/TODO\(T-\d\d\)/.test(lines[idx].comment) || (lines[idx - 1] && /TODO\(T-\d\d\)/.test(lines[idx - 1].comment)));
    }, ignorable: false },
  {
    id: 'HC21', msg: 'TODO/FIXME sahibi olmadan yazılamaz: // TODO(T-xx): …', scope: inLib,
    fn: ({ lines }) => lines.filter((l) => /\b(?:TODO|FIXME|HACK|XXX)\b(?!\(T-\d\d\))/.test(l.comment)).map((l) => ({ line: l.no })),
  },
];

if (argv.includes('--list')) {
  for (const r of rules) console.log(`${r.id}\t${r.msg}`);
  console.log('HC00\tignore-hardcode işaretinde gerekçe zorunlu');
  console.log('HC22\tSVG içinde rgba() (flutter_svg desteklemez; K-12)');
  process.exit(0);
}

let viol = [];
let files = core.filesFromArgs(argv, root);
if (!files) files = core.walk(root, (f) => /\.dart$/.test(f) || (/\.svg$/.test(f) && /\/assets\//.test(core.toPosix(f))));
for (const f of files) {
  const rel = core.toPosix(path.relative(root, f));
  if (/\.svg$/.test(rel)) {
    const s = fs.readFileSync(f, 'utf8');
    const m = /rgba\(/.exec(s);
    if (m) viol.push({ file: rel, line: s.slice(0, m.index).split('\n').length, rule: 'HC22', msg: 'SVG içinde rgba() — flutter_svg desteklemez (K-12); #hex + opacity özniteliği kullan', text: '' });
    continue;
  }
  if (!/\.dart$/.test(rel)) continue;
  if (/(^|\/)(test|integration_test)\//.test(rel)) continue;
  viol = viol.concat(core.runRules(rel, fs.readFileSync(f, 'utf8'), rules));
}
process.exit(core.report(viol, argv, 'check_hardcode'));
