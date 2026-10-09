// Tasarım CSS'ini (`design/extracted/component-css.css`) kurallara ayrıştırır
// ve token testlerine ölçü okur (T-01; design-contract L1).
//
// Model:
// * `seçici{bildirim;bildirim}` kuralları; virgüllü seçici listeleri ayrı ayrı
//   eşlenir (`.check,.radio{…}` → `.check` ve `.radio`).
// * Aynı seçici birden çok kez geçerse özellik bazında SON tanım kazanır
//   (CSS kaskadı ile aynı yön).
// * `@keyframes ad{adım{…}}` adımları `@keyframes <ad> <adım>` sözde
//   seçicisiyle aynı sorgu API'sinden okunur (ör. `@keyframes scan 50%`).
// * `@media (koşul){…}` blokları ana tabloya karışmaz; `media(koşul)` ile ayrı
//   bir `CssMeasure` olarak okunur. Diğer `@` kuralları atlanır.
// * Tarama testleri için `declarations` her bildirimi (ezilenler, `@keyframes`
//   adımları ve `@media` içindekiler dahil) kaynak sırasıyla verir.
import 'design_sources.dart';

/// Bir özelliğin değeri ve onu son tanımlayan kuralın satırı (1 tabanlı).
typedef CssDeclaration = ({String value, int line});

/// Kaynaktaki tek bir bildirim: seçici (normalize), özellik, ham değer,
/// kuralın satırı ve içinde bulunduğu `@media` koşulu (ana tabloda `null`).
typedef CssDeclarationEntry = ({
  String selector,
  String prop,
  String value,
  int line,
  String? media,
});

/// `component-css.css` ayrıştırıcısı ve ölçü okuyucusu.
final class CssMeasure {
  CssMeasure._(this._rules, this._media, this._keyframes, this._all);

  /// Ham CSS metnini ayrıştırır. Eşleşmeyen süslü parantezde
  /// `FormatException` atar.
  factory CssMeasure.parse(String css) {
    final source = _Source(_stripComments(css));
    final sink = _Sink();
    _collect(source, 0, source.text.length, sink);
    return sink.build();
  }

  /// `design/extracted/component-css.css` dosyasını yükler
  /// (`CssMeasure.load()`).
  factory CssMeasure.load() => CssMeasure.parse(componentCss());

  final Map<String, Map<String, CssDeclaration>> _rules;
  final Map<String, CssMeasure> _media;
  final Set<String> _keyframes;
  final List<CssDeclarationEntry> _all;

  /// Tüm bildirimler kaynak sırasıyla: aynı seçicinin ezilen tanımları,
  /// virgüllü seçici listesinin her öğesi, `@keyframes` adımları ve `@media`
  /// blokları (`media` alanı koşul) dahil. Değer kırpılmış ham metindir
  /// (`!important` dahil); `line` kuralın satırıdır.
  List<CssDeclarationEntry> get declarations => List.unmodifiable(_all);

  /// Tanımlı (normalize edilmiş) seçiciler.
  Iterable<String> get selectors => _rules.keys;

  /// Tanımlı `@keyframes` adları.
  Set<String> get keyframes => Set.unmodifiable(_keyframes);

  /// Tanımlı `@media` koşulları (ör. `(prefers-reduced-motion:reduce)`).
  Iterable<String> get mediaConditions => _media.keys;

  /// Seçici (ve verilirse özellik) tanımlı mı?
  bool has(String selector, [String? prop]) {
    final decls = _rules[normalizeSelector(selector)];
    if (decls == null) return false;
    return prop == null || decls.containsKey(_normalizeProp(prop));
  }

  /// `@media` bloğu; yoksa `StateError`.
  CssMeasure media(String condition) {
    final key = condition.trim();
    final nested = _media[key];
    if (nested == null) {
      throw StateError('CSS @media koşulu bulunamadı: "$key"');
    }
    return nested;
  }

  /// Özelliğin ham değeri (kırpılmış, `!important` dahil).
  /// Seçici ya da özellik yoksa `StateError`.
  String raw(String selector, String prop) => _decl(selector, prop).value;

  /// Özelliği son tanımlayan kuralın satır numarası (1 tabanlı).
  int line(String selector, String prop) => _decl(selector, prop).line;

  /// Tek uzunluk değeri px olarak: `12px`, `-1px`, `0` ya da
  /// `calc(<değişken/yüzde> ± Npx)` (sabit px terimi işaretiyle; ör.
  /// `calc(var(--safe-top) - 4px)` → −4). Değer tek uzunluk değilse
  /// `FormatException`, bulunamazsa `StateError`.
  double px(String selector, String prop) {
    final value = _value(selector, prop);
    final parts = splitTokens(value);
    if (parts.length != 1) {
      throw FormatException('"$selector" $prop tek uzunluk değil: $value');
    }
    return parsePx(parts.single);
  }

  /// Birimsiz sayı: `.5`, `1`, `16/9`.
  double number(String selector, String prop) {
    final value = _value(selector, prop);
    final parts = splitTokens(value);
    if (parts.length != 1) {
      throw FormatException('"$selector" $prop tek sayı değil: $value');
    }
    return parseNumber(parts.single);
  }

  /// Yüzde değeri oran olarak: `90%` → 0.9.
  double percent(String selector, String prop) {
    final value = _value(selector, prop);
    final parts = splitTokens(value);
    if (parts.length != 1) {
      throw FormatException('"$selector" $prop tek yüzde değil: $value');
    }
    return parsePercent(parts.single);
  }

  /// Değerin üst düzey (parantez/tırnak içi bölünmez) boşlukla ayrılmış
  /// parçaları.
  List<String> tokens(String selector, String prop) =>
      splitTokens(_value(selector, prop));

  /// Kısa yazım uzunlukları.
  ///
  /// * `padding`, `margin`, `inset`, `border-width`: 1–4 değer CSS kuralıyla
  ///   `[üst, sağ, alt, sol]` dizisine açılır; uzunluk olmayan parça
  ///   (`auto`) `double.nan` olur.
  /// * Diğerleri (`border:1px solid X`, `box-shadow:inset 0 0 0 2px X`,
  ///   `outline`): yalnızca uzunluk parçaları sırayla döner.
  List<double> box(String selector, String prop) {
    final normalized = _normalizeProp(prop);
    final parts = tokens(selector, normalized);
    if (_boxProps.contains(normalized)) {
      final values = [
        for (final p in parts) _isLength(p) ? parsePx(p) : double.nan,
      ];
      return switch (values.length) {
        1 => [values[0], values[0], values[0], values[0]],
        2 => [values[0], values[1], values[0], values[1]],
        3 => [values[0], values[1], values[2], values[1]],
        4 => values,
        _ => throw FormatException(
          '"$selector" $prop 1–4 değerli kısa yazım değil: ${parts.join(' ')}',
        ),
      };
    }
    return [
      for (final p in parts)
        if (_isLength(p)) parsePx(p),
    ];
  }

  /// Değerdeki `name(…)` çağrısının `arg`. argümanının ham metni
  /// (ör. `translate(-50%,-110%)` → arg 1 = `-110%`).
  String fnArg(String selector, String prop, String name, {int arg = 0}) {
    final args = functionArgs(_value(selector, prop), name);
    if (arg < 0 || arg >= args.length) {
      throw StateError('"$selector" $prop $name(…) içinde $arg. argüman yok');
    }
    return args[arg];
  }

  /// `fnArg` argümanının son parçasının sayısal değeri: `blur(6px)` → 6,
  /// `rotate(-30deg)` → −30, `brightness(.96)` → 0.96,
  /// `linear-gradient(…,#000 30%,…)` arg 1 → 0.3, `min(320px,calc(100% -
  /// 48px))` arg 1 → −48.
  double fn(String selector, String prop, String name, {int arg = 0}) {
    final parts = splitTokens(fnArg(selector, prop, name, arg: arg));
    if (parts.isEmpty) {
      throw StateError('"$selector" $prop $name(…) $arg. argüman boş');
    }
    return parseValue(parts.last);
  }

  // ── statik ayrıştırıcılar ────────────────────────────────────────────────

  /// Seçiciyi karşılaştırma için normalize eder: boşluklar teke iner,
  /// `>`, `+`, `~` birleştiricilerinin çevresindeki boşluklar silinir.
  static String normalizeSelector(String selector) => selector
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAllMapped(RegExp(r'\s*([>+~])\s*'), (m) => m.group(1)!);

  /// `12px` / `-1px` / `0` / `calc(… ± Npx)` → px.
  static double parsePx(String token) {
    final t = token.trim();
    if (t == '0') return 0;
    final m = _pxRe.firstMatch(t);
    if (m != null) return double.parse(m.group(1)!);
    if (t.startsWith('calc(') && t.endsWith(')')) {
      return _calcPx(t.substring(5, t.length - 1));
    }
    throw FormatException('px uzunluğu değil: $token');
  }

  /// `90%` → 0.9.
  static double parsePercent(String token) {
    final m = RegExp(r'^(-?\d*\.?\d+)%$').firstMatch(token.trim());
    if (m == null) throw FormatException('yüzde değil: $token');
    return double.parse(m.group(1)!) / 100;
  }

  /// `.5` / `1` / `16/9` → sayı.
  static double parseNumber(String token) {
    final t = token.trim();
    final ratio = RegExp(r'^(-?\d*\.?\d+)\s*/\s*(-?\d*\.?\d+)$').firstMatch(t);
    if (ratio != null) {
      return double.parse(ratio.group(1)!) / double.parse(ratio.group(2)!);
    }
    final m = RegExp(r'^(-?\d*\.?\d+)$').firstMatch(t);
    if (m == null) throw FormatException('birimsiz sayı değil: $token');
    return double.parse(m.group(1)!);
  }

  /// Birime göre: px/`calc` → px, `%` → oran, `deg` → derece, birimsiz →
  /// sayı (`A/B` dahil).
  static double parseValue(String token) {
    final t = token.trim();
    if (t.endsWith('%')) return parsePercent(t);
    final deg = RegExp(r'^(-?\d*\.?\d+)deg$').firstMatch(t);
    if (deg != null) return double.parse(deg.group(1)!);
    if (t.endsWith('px') || t.startsWith('calc(')) return parsePx(t);
    return parseNumber(t);
  }

  /// Üst düzey boşlukla bölme (parantez ve tırnak içi korunur).
  static List<String> splitTokens(String value) => _splitTopLevel(
    value.trim(),
    (c) => c == ' ' || c == '\t' || c == '\n' || c == '\r',
  ).where((s) => s.isNotEmpty).toList();

  /// Üst düzey virgülle bölme (parantez ve tırnak içi korunur), parçalar
  /// kırpılmış: `background .12s,color .12s` → 2 öğe (`transition` listesi).
  static List<String> splitList(String value) => _splitTopLevel(
    value.trim(),
    (c) => c == ',',
  ).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  /// `value` içindeki ilk `name(…)` çağrısının üst düzey virgülle ayrılmış
  /// argümanları (kırpılmış). `name` bir kelimenin parçası olarak eşleşmez
  /// (`linear-gradient` ≠ `repeating-linear-gradient`).
  static List<String> functionArgs(String value, String name) {
    final re = RegExp('(?<![\\w-])${RegExp.escape(name)}\\(');
    final m = re.firstMatch(value);
    if (m == null) throw StateError('"$value" içinde $name(…) yok');
    final open = m.end - 1;
    final close = _matching(value, open, value.length, '(', ')');
    return _splitTopLevel(
      value.substring(open + 1, close),
      (c) => c == ',',
    ).map((s) => s.trim()).toList();
  }

  // ── iç ────────────────────────────────────────────────────────────────────

  static final RegExp _pxRe = RegExp(r'^(-?\d*\.?\d+)px$');

  static const Set<String> _boxProps = {
    'padding',
    'margin',
    'inset',
    'border-width',
  };

  static bool _isLength(String token) {
    final t = token.trim();
    if (t == '0' || _pxRe.hasMatch(t)) return true;
    return t.startsWith('calc(') && t.contains('px');
  }

  /// `calc` içindeki toplamsal px sabitlerinin işaretli toplamı; değişken ve
  /// yüzde terimleri yok sayılır. Çarpımsal px terimi `FormatException`.
  static double _calcPx(String expr) {
    final terms = RegExp(
      r'(^|[+\-*/(,])\s*(\d*\.?\d+)px',
    ).allMatches(expr.trim()).toList();
    if (terms.isEmpty) throw FormatException('calc içinde px yok: $expr');
    var sum = 0.0;
    for (final t in terms) {
      final op = t.group(1)!;
      final v = double.parse(t.group(2)!);
      sum += switch (op) {
        '-' => -v,
        '' || '+' || '(' || ',' => v,
        _ => throw FormatException('calc içinde çarpımsal px terimi: $expr'),
      };
    }
    return sum;
  }

  CssDeclaration _decl(String selector, String prop) {
    final key = normalizeSelector(selector);
    final decls = _rules[key];
    if (decls == null) throw StateError('CSS seçici bulunamadı: "$key"');
    final p = _normalizeProp(prop);
    final d = decls[p];
    if (d == null) throw StateError('"$key" içinde "$p" özelliği yok');
    return d;
  }

  String _value(String selector, String prop) =>
      raw(selector, prop).replaceFirst(RegExp(r'\s*!important$'), '').trim();

  static String _normalizeProp(String prop) => prop.trim().toLowerCase();

  static String _stripComments(String css) => css.replaceAllMapped(
    RegExp(r'/\*[\s\S]*?\*/'),
    (m) => m.group(0)!.replaceAll(RegExp(r'[^\n]'), ' '),
  );

  static void _collect(_Source src, int from, int to, _Sink sink) {
    for (final b in _blocks(src, from, to)) {
      final prelude = b.prelude;
      if (prelude.startsWith('@keyframes')) {
        final name = prelude.substring('@keyframes'.length).trim();
        sink.keyframes.add(name);
        for (final step in _blocks(src, b.bodyStart, b.bodyEnd)) {
          final decls = _declarations(
            src.text.substring(step.bodyStart, step.bodyEnd),
          );
          for (final s in _splitTopLevel(step.prelude, (c) => c == ',')) {
            sink.add('@keyframes $name ${s.trim()}', decls, step.line);
          }
        }
      } else if (prelude.startsWith('@media')) {
        final condition = prelude.substring('@media'.length).trim();
        final nested = _Sink();
        _collect(src, b.bodyStart, b.bodyEnd, nested);
        sink.media[condition] = nested.build();
        sink.all.addAll([
          for (final d in nested.all)
            (
              selector: d.selector,
              prop: d.prop,
              value: d.value,
              line: d.line,
              media: d.media ?? condition,
            ),
        ]);
      } else if (prelude.startsWith('@')) {
        continue; // @font-face, @supports vb. token testinde kullanılmaz.
      } else {
        final decls = _declarations(src.text.substring(b.bodyStart, b.bodyEnd));
        for (final s in _splitTopLevel(prelude, (c) => c == ',')) {
          final selector = normalizeSelector(s);
          if (selector.isNotEmpty) sink.add(selector, decls, b.line);
        }
      }
    }
  }

  static List<_Block> _blocks(_Source src, int from, int to) {
    final text = src.text;
    final out = <_Block>[];
    var preludeStart = from;
    String? quote;
    var i = from;
    while (i < to) {
      final c = text[i];
      if (quote != null) {
        if (c == quote) quote = null;
      } else if (c == '"' || c == "'") {
        quote = c;
      } else if (c == ';') {
        preludeStart = i + 1; // gövdesiz deyim (@import vb.) atlanır.
      } else if (c == '{') {
        final close = _matching(text, i, to, '{', '}');
        final rawPrelude = text.substring(preludeStart, i);
        final lead = rawPrelude.length - rawPrelude.trimLeft().length;
        out.add(
          _Block(
            prelude: rawPrelude.trim(),
            bodyStart: i + 1,
            bodyEnd: close,
            line: src.lineAt(preludeStart + lead),
          ),
        );
        i = close + 1;
        preludeStart = i;
        continue;
      } else if (c == '}') {
        throw FormatException('Eşleşmeyen "}" (satır ${src.lineAt(i)})');
      }
      i++;
    }
    return out;
  }

  static int _matching(String text, int open, int to, String o, String c) {
    var depth = 0;
    String? quote;
    for (var i = open; i < to; i++) {
      final ch = text[i];
      if (quote != null) {
        if (ch == quote) quote = null;
      } else if (ch == '"' || ch == "'") {
        quote = ch;
      } else if (ch == o) {
        depth++;
      } else if (ch == c) {
        depth--;
        if (depth == 0) return i;
      }
    }
    throw FormatException('Kapanmayan "$o" (konum $open)');
  }

  static Map<String, String> _declarations(String body) {
    final out = <String, String>{};
    for (final d in _splitTopLevel(body, (c) => c == ';')) {
      final idx = d.indexOf(':');
      if (idx <= 0) continue;
      final prop = _normalizeProp(d.substring(0, idx));
      final value = d.substring(idx + 1).trim();
      if (prop.isEmpty) continue;
      out[prop] = value;
    }
    return out;
  }

  static List<String> _splitTopLevel(String s, bool Function(String) isSep) {
    final out = <String>[];
    final buf = StringBuffer();
    var depth = 0;
    String? quote;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (quote != null) {
        if (c == quote) quote = null;
        buf.write(c);
        continue;
      }
      if (c == '"' || c == "'") {
        quote = c;
      } else if (c == '(' || c == '[') {
        depth++;
      } else if (c == ')' || c == ']') {
        depth--;
      } else if (depth == 0 && isSep(c)) {
        out.add(buf.toString());
        buf.clear();
        continue;
      }
      buf.write(c);
    }
    out.add(buf.toString());
    return out;
  }
}

final class _Source {
  _Source(this.text)
    : _newlines = [
        for (var i = 0; i < text.length; i++)
          if (text.codeUnitAt(i) == 10) i,
      ];

  final String text;
  final List<int> _newlines;

  /// `offset` konumunun 1 tabanlı satırı.
  int lineAt(int offset) {
    var lo = 0;
    var hi = _newlines.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_newlines[mid] < offset) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo + 1;
  }
}

final class _Block {
  const _Block({
    required this.prelude,
    required this.bodyStart,
    required this.bodyEnd,
    required this.line,
  });

  final String prelude;
  final int bodyStart;
  final int bodyEnd;
  final int line;
}

final class _Sink {
  final Map<String, Map<String, CssDeclaration>> rules = {};
  final Map<String, CssMeasure> media = {};
  final Set<String> keyframes = {};
  final List<CssDeclarationEntry> all = [];

  void add(String selector, Map<String, String> decls, int line) {
    final target = rules.putIfAbsent(selector, () => {});
    for (final e in decls.entries) {
      target[e.key] = (value: e.value, line: line);
      all.add(
        (
          selector: selector,
          prop: e.key,
          value: e.value,
          line: line,
          media: null,
        ),
      );
    }
  }

  CssMeasure build() => CssMeasure._(rules, media, keyframes, all);
}
