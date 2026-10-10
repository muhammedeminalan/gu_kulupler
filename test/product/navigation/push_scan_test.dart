// "push yalnızca LegalRoute" taraması (PLAN §13.10, navigation.md §7,
// CLAUDE.md §5). `lib/**` + `packages/*/lib/**` (üretilen dosyalar hariç):
//   P01 push biçimleri (`context.push*(`, `.push(context)`, `.push<`,
//       `pushReplacement*`, `GoRouter.of(context).push`) — izinli tek biçim
//       `LegalRoute(…).push<void>(context)` ve yalnızca 4 dosyada; ayrıca
//       gu_ui overlay primitifinin rota itmesi `Navigator.of(…).push<T>(`
//       (sheet / dialog / menü rota değildir — PLAN §13.6, CD-113; T-07)
//   P02 view dosyalarında `Navigator.` (overlay çerçeveleri hariç)
//   P03 view dosyalarında `GetIt.I` / `GetIt.instance`
//   P04 `CustomTransitionPage(` yalnızca `gu_page_transitions.dart`
// T-02'de boş geçer; T-11'den (router) itibaren anlamlı.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../helpers/design_files.dart';

/// `LegalRoute(…).push<void>(context)` izinli dosyalar (giriş, kayıt,
/// katılım başvurusu sheet'i, hakkında — PLAN §13.10).
const Set<String> _legalPushFiles = {
  'lib/features/auth/view/login_view.dart',
  'lib/features/auth/view/register_view.dart',
  'lib/features/clubs/view/widget/join_application_sheet.dart',
  'lib/features/settings/view/about_view.dart',
};

typedef _Violation = ({String file, int line, String rule, String text});

final RegExp _pushRe = RegExp(
  r'\bcontext\.push\w*\s*[<(]|\.push\s*\(\s*context\b|\.push\s*<|'
  r'\bpushReplacement\w*\b|\bGoRouter\.of\([^)]*\)\s*\.push',
);
final RegExp _navigatorRe = RegExp(r'\bNavigator\.');
final RegExp _getItRe = RegExp(r'\bGetIt\.(?:I|instance)\b');
final RegExp _trailingCommentRe = RegExp("(?<![:\"'])//");
final RegExp _customTransitionRe = RegExp(r'\bCustomTransitionPage\s*[<(]');

bool _isGenerated(String rel) =>
    RegExp(r'\.(g|gen|freezed)\.dart$').hasMatch(rel) ||
    rel.startsWith('lib/l10n/app_localizations') ||
    rel.endsWith('/firebase_options.dart');

/// `tool/check_hardcode.js` `isViewish` ile aynı sınıf.
bool _isView(String rel) =>
    RegExp('^lib/features/[^/]+/view/').hasMatch(rel) ||
    RegExp('^lib/product/(widget|navigation)/').hasMatch(rel) ||
    rel.startsWith('packages/gu_ui/lib/') ||
    RegExp(r'_(view|widget|sheet|dialog)\.dart$').hasMatch(rel);

/// `Navigator.` serbest: overlay çerçeveleri (CD-02).
bool _isOverlay(String rel) =>
    rel.startsWith('packages/gu_ui/lib/src/overlay/') ||
    rel.startsWith('lib/product/feedback/');

/// Yorum satırları (`//`, `///`) taranmaz; satır sonu yorumu kırpılır.
String _code(String line) {
  final trimmed = line.trimLeft();
  if (trimmed.startsWith('//')) return '';
  final i = line.indexOf(_trailingCommentRe);
  return i < 0 ? line : line.substring(0, i);
}

/// [match] `.push<void>(context)` mı ve içinde bulunduğu ifade (önceki `;`,
/// `{` ya da `}` sonrasından itibaren) `LegalRoute(` içeriyor mu.
bool _isLegalPush(String source, Match match) {
  if (!source.startsWith('.push<void>(context)', match.start)) return false;
  final before = source.substring(0, match.start);
  final cut = [
    before.lastIndexOf(';'),
    before.lastIndexOf('{'),
    before.lastIndexOf('}'),
  ].reduce((a, b) => a > b ? a : b);
  return before.substring(cut + 1).contains('LegalRoute(');
}

/// [match] gu_ui overlay primitifinin (`gu_overlay_route.dart` vb.) kendi
/// rotasını itmesi mi: `Navigator.of(…).push<T>(` ve dosya
/// `packages/gu_ui/lib/src/overlay/` altında. go_router `push` biçimleri
/// (`context.push`, `.push(context)`) burada da yasaktır.
bool _isOverlayRoutePush(String rel, String source, Match match) {
  if (!rel.startsWith('packages/gu_ui/lib/src/overlay/')) return false;
  if (!source.startsWith('.push<', match.start)) return false;
  final before = source.substring(0, match.start);
  final cut = [
    before.lastIndexOf(';'),
    before.lastIndexOf('{'),
    before.lastIndexOf('}'),
  ].reduce((a, b) => a > b ? a : b);
  return before.substring(cut + 1).contains('Navigator.of(');
}

/// Tek dosyanın ihlalleri (saf; sentetik metinle test edilir).
List<_Violation> _scanSource(String rel, String source) {
  final out = <_Violation>[];
  final lines = source.split('\n');
  final code = lines.map(_code).join('\n');
  int lineOf(int offset) =>
      '\n'.allMatches(code.substring(0, offset)).length + 1;

  for (final m in _pushRe.allMatches(code)) {
    final legal = _legalPushFiles.contains(rel) && _isLegalPush(code, m);
    if (legal || _isOverlayRoutePush(rel, code, m)) continue;
    final line = lineOf(m.start);
    out.add((file: rel, line: line, rule: 'P01', text: lines[line - 1].trim()));
  }
  if (_isView(rel) && !_isOverlay(rel)) {
    for (final m in _navigatorRe.allMatches(code)) {
      final line = lineOf(m.start);
      out.add((
        file: rel,
        line: line,
        rule: 'P02',
        text: lines[line - 1].trim(),
      ));
    }
  }
  if (_isView(rel)) {
    for (final m in _getItRe.allMatches(code)) {
      final line = lineOf(m.start);
      out.add((
        file: rel,
        line: line,
        rule: 'P03',
        text: lines[line - 1].trim(),
      ));
    }
  }
  if (!rel.endsWith('/gu_page_transitions.dart')) {
    for (final m in _customTransitionRe.allMatches(code)) {
      final line = lineOf(m.start);
      out.add((
        file: rel,
        line: line,
        rule: 'P04',
        text: lines[line - 1].trim(),
      ));
    }
  }
  return out;
}

/// Taranan kaynak dosyalar (depo köküne göre, sıralı).
List<String> _sourceFiles() {
  final roots = [
    Directory('$repoRoot/lib'),
    for (final pkg in Directory('$repoRoot/packages').listSync())
      if (pkg is Directory) Directory('${pkg.path}/lib'),
  ];
  return [
    for (final dir in roots)
      if (dir.existsSync())
        for (final f in dir.listSync(recursive: true))
          if (f is File && f.path.endsWith('.dart'))
            f.path.substring(repoRoot.length + 1),
  ]..sort();
}

void main() {
  group('T-02 · push taraması (PLAN §13.10, navigation.md §7)', () {
    test('lib/ + packages/*/lib temiz', () {
      final files = _sourceFiles().where((f) => !_isGenerated(f)).toList();
      expect(files, isNotEmpty);
      final violations = [
        for (final f in files) ..._scanSource(f, readText(f)),
      ];
      expect(
        violations.map((v) => '${v.rule} ${v.file}:${v.line} ${v.text}'),
        isEmpty,
      );
    });

    test('P01: push biçimleri yakalanır', () {
      const src = '''
void a(BuildContext context) {
  context.push('/clubs/c01');
  context.pushNamed('x');
  ClubRoute(id: 'c01').push(context);
  EventRoute(id: 'e01').push<void>(context);
  context.pushReplacement('/x');
  GoRouter.of(context).push('/y');
}
''';
      final v = _scanSource('lib/features/clubs/view/club_view.dart', src);
      expect(v.map((e) => e.rule), everyElement('P01'));
      expect(v.map((e) => e.line), [2, 3, 4, 5, 6, 7]);
    });

    test('P01: LegalRoute.push<void> yalnızca izinli 4 dosyada geçer', () {
      const src = '''
void a(BuildContext context) {
  LegalRoute(tip: LegalTip.kvkk).push<void>(context);
  LegalRoute(
    tip: LegalTip.terms,
  ).push<void>(context);
}
''';
      for (final file in _legalPushFiles) {
        expect(_scanSource(file, src), isEmpty, reason: file);
      }
      expect(
        _scanSource('lib/features/profile/view/profile_view.dart', src),
        hasLength(2),
      );
      const other = '''
void b(BuildContext context) {
  EventRoute(id: 'e01').push<void>(context);
}
''';
      expect(
        _scanSource('lib/features/auth/view/login_view.dart', other),
        hasLength(1),
      );
    });

    test('T-07 · P01: overlay rotası itme yalnızca gu_ui/src/overlay', () {
      const src = '''
Future<T?> open<T>(BuildContext context, Route<T> route) =>
    Navigator.of(context, rootNavigator: true).push<T>(route);
''';
      expect(
        _scanSource(
          'packages/gu_ui/lib/src/overlay/gu_overlay_route.dart',
          src,
        ),
        isEmpty,
      );
      for (final file in [
        'lib/product/feedback/feedback_service.dart',
        'lib/core/di/project_dependency.dart',
        'packages/gu_ui/lib/src/widgets/primitives/gu_button.dart',
      ]) {
        expect(
          _scanSource(file, src).map((e) => e.rule),
          contains('P01'),
          reason: file,
        );
      }
      // go_router push biçimleri overlay klasöründe de yasak.
      const router = '''
void a(BuildContext context) {
  context.push('/x');
  ClubRoute(id: 'c01').push<void>(context);
}
''';
      expect(
        _scanSource(
          'packages/gu_ui/lib/src/overlay/gu_sheet_frame.dart',
          router,
        ).map((e) => e.rule),
        ['P01', 'P01'],
      );
    });

    test('P02/P03: view dosyasında Navigator. ve GetIt.I yasak', () {
      const src = '''
void a(BuildContext context) {
  Navigator.of(context).pop();
  final repo = GetIt.I<ClubRepository>();
}
''';
      final view = _scanSource('lib/features/clubs/view/club_view.dart', src);
      expect(view.map((e) => e.rule), ['P02', 'P03']);
      expect(
        _scanSource('lib/product/feedback/feedback_service.dart', src),
        isEmpty,
      );
      expect(
        _scanSource(
          'packages/gu_ui/lib/src/overlay/gu_sheet_frame.dart',
          src,
        ).map((e) => e.rule),
        ['P03'],
      );
      expect(_scanSource('lib/core/di/project_dependency.dart', src), isEmpty);
    });

    test('P04: CustomTransitionPage yalnızca gu_page_transitions.dart', () {
      const src = 'Page<void> p() => CustomTransitionPage<void>(child: c);';
      expect(
        _scanSource('lib/product/navigation/gu_page_transitions.dart', src),
        isEmpty,
      );
      expect(
        _scanSource(
          'lib/product/navigation/routes/app_routes.dart',
          src,
        ).map((e) => e.rule),
        ['P04'],
      );
    });

    test('yorum satırları taranmaz', () {
      const src = '''
/// context.push yerine go kullan; Navigator.push yasak.
// GetIt.I view'da yok
void a() {} // context.push('/x')
''';
      expect(
        _scanSource('lib/features/clubs/view/club_view.dart', src),
        isEmpty,
      );
    });
  });
}
