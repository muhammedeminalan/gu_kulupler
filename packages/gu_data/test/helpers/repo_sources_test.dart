// T-08 · test yardımcısı: depo kaynağı okuyucu ve Markdown tablo ayrıştırıcı.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'repo_sources.dart';

const String _doc = r'''
# Belge

### 1.1 Boş bölüm

Düz metin, tablo yok.

### 1.2 Tablo

Açıklama satırı.

| Sabit | Tip | Değer |
|---|:---:|---|
| `a` / `b` | `int` | `1` / `2` |
| `pattern` | `String` | `^(x\|y)$` (`not`) |
|  `spaced`  |  |  `7`  |

Tablodan sonraki metin | boru içerir.

### 1.3 Bozuk tablo

| Yalnızca başlık |
''';

void main() {
  group('T-08 · repo_sources · depo kökü', () {
    test('repoRoot docs/PLAN.md içeren dizindir', () {
      expect(File('$repoRoot/docs/PLAN.md').existsSync(), isTrue);
      expect(File('$repoRoot/pubspec.yaml').existsSync(), isTrue);
      expect(Directory('$repoRoot/packages/gu_data').existsSync(), isTrue);
    });

    test('readRepoFile göreli yolu depo köküne göre okur', () {
      expect(readRepoFile('docs/PLAN.md'), contains('### 9.8 `Limits`'));
    });

    test('readRepoFile olmayan dosyada hata fırlatır', () {
      expect(
        () => readRepoFile('docs/yok-boyle-bir-dosya.md'),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('readRepoJson kök nesneyi döndürür', () {
      final registry = readRepoJson('design/extracted/registry.json');
      expect(registry['constants'], isA<Map<String, Object?>>());
    });
  });

  group('T-08 · repo_sources · markdownTable', () {
    test('başlık altındaki ilk tabloyu başlık + veri satırlarına ayırır', () {
      final table = markdownTable(_doc, heading: '### 1.2 ');

      expect(table.header, ['Sabit', 'Tip', 'Değer']);
      expect(table.rows, hasLength(3));
      expect(table.rows[0], ['`a` / `b`', '`int`', '`1` / `2`']);
    });

    test(r'kaçışlı boru (\|) hücreyi bölmez ve gerçek | olur', () {
      final table = markdownTable(_doc, heading: '### 1.2 ');

      expect(table.rows[1], ['`pattern`', '`String`', r'`^(x|y)$` (`not`)']);
    });

    test('hücreler kırpılır, boş hücre korunur', () {
      final table = markdownTable(_doc, heading: '### 1.2 ');

      expect(table.rows[2], ['`spaced`', '', '`7`']);
    });

    test('tablo, boru ile başlamayan ilk satırda biter', () {
      final table = markdownTable(_doc, heading: '### 1.2 ');

      expect(
        table.rows.expand((row) => row),
        isNot(contains(contains('Tablodan sonraki'))),
      );
    });

    test('rowWhereFirstCell tek satırı bulur; yoksa hata', () {
      final table = markdownTable(_doc, heading: '### 1.2 ');

      expect(table.rowWhereFirstCell('`pattern`')[1], '`String`');
      expect(() => table.rowWhereFirstCell('`yok`'), throwsStateError);
    });

    test('başlık yoksa StateError', () {
      expect(
        () => markdownTable(_doc, heading: '### 9.9 '),
        throwsStateError,
      );
    });

    test('başlık birden çok kez geçerse StateError', () {
      expect(() => markdownTable(_doc, heading: '### 1.'), throwsStateError);
    });

    test('sonraki başlıktan önce tablo yoksa StateError', () {
      expect(
        () => markdownTable(_doc, heading: '### 1.1 '),
        throwsStateError,
      );
    });

    test('ayırıcı satırı olmayan tablo StateError', () {
      expect(
        () => markdownTable(_doc, heading: '### 1.3 '),
        throwsStateError,
      );
    });
  });

  group('T-08 · repo_sources · codeSpans', () {
    test('ters tırnak arasındaki parçaları sırasıyla verir', () {
      expect(codeSpans('`a` / `b` (not) `c d`'), ['a', 'b', 'c d']);
    });

    test('kod parçası yoksa boş liste', () {
      expect(codeSpans('düz metin'), isEmpty);
    });
  });
}
