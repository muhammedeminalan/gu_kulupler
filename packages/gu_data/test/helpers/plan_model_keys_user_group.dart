// T-09 · Grup A (kullanıcı modelleri) testlerinin ortak yardımcıları.
//
// PLAN §9.6 okuyucusu: bir koleksiyon tablosunun ya da gömülü model tanımının
// JSON anahtar kümesi docs/PLAN.md'den OKUNUR; modelin toJson() anahtarları
// bununla karşılaştırılır. Ayrıca alan başına copyWith + eşitlik denetimi.
import 'package:flutter_test/flutter_test.dart';

import 'repo_sources.dart';

final String _plan = readRepoFile('docs/PLAN.md');

/// §9.2 `BaseFields` tablosunda `createdBy` satırının JSON anahtarı.
const String _createdBy = 'createdBy';

/// PLAN §[section] (ör. `9.6.1`) tablosundaki JSON anahtarları.
///
/// Belge kimliği satırları (JSON hücresi `—` ile başlar) atlanır.
/// `BaseFields (5 alan)` satırı §9.2 tablosundaki anahtarlara açılır
/// (`createdBy` hariç; onu taşıyan tablolar ayrı satırda bildirir). Tablo
/// beklenen biçimde değilse [StateError] fırlatır — sessizce eksik küme
/// dönmez.
Set<String> planJsonKeys(String section) {
  final table = markdownTable(_plan, heading: '#### $section ');
  if (table.header.take(2).join('|') != 'Alan|JSON') {
    throw StateError('PLAN §$section başlığı değişmiş: ${table.header}');
  }
  final keys = <String>{};
  for (final row in table.rows) {
    final jsonCell = row[1];
    if (row.first == 'BaseFields (5 alan)') {
      keys.addAll(_baseKeys().difference({_createdBy}));
    } else if (jsonCell.startsWith('—')) {
      // Belge kimliği: JSON'a yazılmaz.
    } else if (codeSpans(jsonCell) case [
      final key,
    ] when jsonCell == '`$key`') {
      if (!keys.add(key)) {
        throw StateError('PLAN §$section: "$key" iki kez geçiyor.');
      }
    } else {
      throw StateError('PLAN §$section satırı ayrıştırılamadı: $row');
    }
  }
  return keys;
}

/// PLAN §9.6'daki gömülü [model] tanımının JSON anahtarları.
///
/// Tanım biçimi: `` `XModel` (`models/x_model.dart`[, gömülü]): `a` (…) ·
/// `b` (…) `` — anahtarlar satır başında ya da ` · ` ayracından sonra gelen,
/// hemen ardından parantez açılan kod parçalarıdır. Tanım tam bir kez
/// geçmiyorsa ya da anahtar bulunamazsa [StateError] fırlatır.
Set<String> planEmbeddedKeys(String model) {
  final definition = RegExp(
    '^`$model` \\(`models/\\w+\\.dart`(?:, gömülü)?\\): (.*)\$',
    multiLine: true,
  );
  final matches = definition.allMatches(_plan).toList();
  if (matches.length != 1) {
    throw StateError(
      'PLAN §9.6: $model tanımı tam bir kez geçmeli; bulunan: '
      '${matches.length}.',
    );
  }
  final keys = {
    for (final key in RegExp(
      r'(?:^| · )`(\w+)` \(',
    ).allMatches(matches.single.group(1)!))
      key.group(1)!,
  };
  if (keys.isEmpty) {
    throw StateError('PLAN §9.6: $model tanımında anahtar bulunamadı.');
  }
  return keys;
}

/// §9.2 `BaseFields` tablosundaki JSON anahtarları (altı ortak alan).
Set<String> _baseKeys() {
  final table = markdownTable(_plan, heading: '### 9.2 ');
  if (table.header.take(2).join('|') != 'Alan (Dart)|JSON') {
    throw StateError('PLAN §9.2 başlığı değişmiş: ${table.header}');
  }
  final keys = {for (final row in table.rows) codeSpans(row[1]).single};
  if (!keys.contains(_createdBy)) {
    throw StateError('PLAN §9.2 tablosunda `$_createdBy` satırı yok.');
  }
  return keys;
}

/// [changed], [base] modelinin tek alanı değiştirilmiş kopyasıdır: alanın yeni
/// değeri [expected] olmalı ve kopya [base] ile eşit **olmamalıdır**.
///
/// Tek çağrı iki şeyi kanıtlar: `copyWith` alanı taşıyor ve alan `props`
/// içinde (eşitliğe giriyor). [expected], [base] içindeki değerden farklı
/// seçilmelidir.
void expectFieldChange<M extends Object, V>(
  M base,
  M changed,
  V Function(M model) read,
  V expected,
) {
  expect(read(changed), expected);
  expect(changed, isNot(base));
}
