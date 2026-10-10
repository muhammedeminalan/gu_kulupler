// T-08 · EmailDomainValidator (D-27, CD-76): biçim denetimi (isWellFormed)
// ve alan adı denetimi (isAllowedDomain → EmailDomainPolicy). İzinli iki
// alan geçer; alt alan / benzer alan, boşluk ve bozuk biçim reddedilir.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/repo_sources.dart';

/// Bir adres için beklenen iki yanıt.
typedef _Expected = ({bool wellFormed, bool allowed});

const _Expected _ok = (wellFormed: true, allowed: true);
const _Expected _foreign = (wellFormed: true, allowed: false);
const _Expected _brokenAllowed = (wellFormed: false, allowed: true);
const _Expected _broken = (wellFormed: false, allowed: false);

/// 64 karakterlik (izinli en uzun) yerel kısım.
final String _local64 = 'a' * 64;

/// 65 karakterlik (bir fazla) yerel kısım.
final String _local65 = 'a' * 65;

/// Biçimce geçerli **ve** alan adı izinli adresler.
final Map<String, String> _valid = {
  'öğrenci alanı': 'ayse.demir@ogr.gumushane.edu.tr',
  'personel alanı': 'zeynep.kaya@gumushane.edu.tr',
  'tek harf yerel (öğrenci)': 'a@ogr.gumushane.edu.tr',
  'tek harf yerel (personel)': 'a@gumushane.edu.tr',
  'öğrenci numarası': '2101234567@ogr.gumushane.edu.tr',
  'artı etiketi': 'a.b+etiket@gumushane.edu.tr',
  'alt çizgi ve tire': 'a_b-c@gumushane.edu.tr',
  'kesme işareti': "o'brien@gumushane.edu.tr",
  'yerel kısım büyük harf': 'Ayse.Demir@gumushane.edu.tr',
  'alan adı büyük harf (öğrenci)': 'a@OGR.GUMUSHANE.EDU.TR',
  'alan adı büyük harf (personel)': 'a@GUMUSHANE.EDU.TR',
  'alan adı karışık harf': 'Ayse.Demir@Ogr.Gumushane.Edu.Tr',
  'yerel kısımda alan adı': 'gmail.com@gumushane.edu.tr',
  '64 karakter yerel': '$_local64@gumushane.edu.tr',
};

/// Biçimce geçerli ama alan adı izinli **olmayan** adresler.
const Map<String, String> _foreignDomain = {
  // Alt alan adları.
  'alt alan: mail.': 'a@mail.gumushane.edu.tr',
  'alt alan: x.ogr.': 'a@x.ogr.gumushane.edu.tr',
  'alt alan: ogr.ogr.': 'a@ogr.ogr.gumushane.edu.tr',
  'alt alan: personel.': 'a@personel.gumushane.edu.tr',
  'alt alan: kulupler.': 'a@kulupler.gumushane.edu.tr',
  // Benzer alan adları.
  'benzer: sonek alanı': 'a@gumushane.edu.tr.evil.com',
  'benzer: önek x': 'a@xgumushane.edu.tr',
  'benzer: önek evil': 'a@evilgumushane.edu.tr',
  'benzer: ogr bitişik': 'a@ogrgumushane.edu.tr',
  'benzer: tire': 'a@gumushane-edu.tr',
  'benzer: ogr tire': 'a@ogr-gumushane.edu.tr',
  'benzer: nokta eksik': 'a@gumushaneedu.tr',
  'benzer: TLD yok': 'a@gumushane.edu',
  'benzer: com.tr': 'a@gumushane.com.tr',
  'benzer: yazım': 'a@gumushhane.edu.tr',
  'benzer: rakam': 'a@gumu5hane.edu.tr',
  // Başka alan adları.
  'başka: gmail': 'a@gmail.com',
  'başka: edu.tr': 'a@edu.tr',
  'başka: başka üniversite': 'a@ogr.atauni.edu.tr',
  'başka: iki etiket': 'a@x.y',
  'başka: sayısal etiketler': 'a@127.0.0.1',
  'başka: iç tire': 'kulup@ornek-alan.com.tr',
  'izinli alan adı yerel kısımda': 'gumushane.edu.tr@gmail.com',
  'şema önekli yerel kısım': 'mailto:a@gmail.com',
};

/// Biçimi bozuk olduğu hâlde `EmailDomainPolicy.isAllowed`'ın tek başına
/// kabul ettiği adresler (iki denetim birlikte aranmalı).
final Map<String, String> _brokenButAllowedDomain = {
  'yerel kısım boş': '@gumushane.edu.tr',
  'iki @ (son alan izinli)': 'a@b@gumushane.edu.tr',
  'üç @': 'a@@@gumushane.edu.tr',
  'başta boşluk': ' a@gumushane.edu.tr',
  'yerel kısımda boşluk': 'a b@gumushane.edu.tr',
  'yerel kısım yalnız boşluk': ' @gumushane.edu.tr',
  'yerel kısımda sekme': 'a\tb@gumushane.edu.tr',
  'yerel kısımda satır sonu': 'a\nb@gumushane.edu.tr',
  'yerel kısımda NUL': 'a\u0000b@gumushane.edu.tr',
  'yerel kısımda DEL': 'a\u007Fb@gumushane.edu.tr',
  'yerel kısımda bölünemez boşluk': 'a\u00A0b@gumushane.edu.tr',
  'yerel kısımda sıfır genişlikli boşluk': 'a\u200Bb@gumushane.edu.tr',
  'yerel kısımda sağdan sola işareti': 'a\u202Eb@gumushane.edu.tr',
  'yerel kısımda Türkçe harf': 'ayşe@gumushane.edu.tr',
  'yerel kısım Türkçe büyük harf': 'ÇĞİÖŞÜ@ogr.gumushane.edu.tr',
  'yerel kısımda emoji': 'a😀@gumushane.edu.tr',
  '65 karakter yerel': '$_local65@gumushane.edu.tr',
  'görünen ad + adres': 'Ayşe Demir <a@gumushane.edu.tr',
};

/// Biçimi bozuk ve alan adı da izinli olmayan girdiler.
const Map<String, String> _brokenAndForeign = {
  // @ işareti.
  'boş': '',
  'yalnız @': '@',
  'yalnız @@': '@@',
  '@ yok': 'gumushane.edu.tr',
  '@ yok (bitişik)': 'agumushane.edu.tr',
  'alan adı boş': 'a@',
  'iki @ (son alan başka)': 'a@gumushane.edu.tr@gmail.com',
  // Boşluk (girdi kırpılmaz).
  'sonda boşluk': 'a@gumushane.edu.tr ',
  '@ sonrası boşluk': 'a@ gumushane.edu.tr',
  'alan adında boşluk': 'a@gumushane .edu.tr',
  'sonda sekme': 'a@gumushane.edu.tr\t',
  'sonda satır sonu': 'a@gumushane.edu.tr\n',
  'sonda sıfır genişlikli boşluk': 'a@gumushane.edu.tr\u200B',
  'yalnız boşluk': '   ',
  // Alan adı yapısı.
  'nokta yok': 'a@gumushane',
  'tek etiket TLD': 'a@tr',
  'baştaki nokta': 'a@.gumushane.edu.tr',
  'sondaki nokta': 'a@gumushane.edu.tr.',
  'çift nokta': 'a@gumushane..edu.tr',
  'yalnız nokta': 'a@.',
  'yalnız noktalar': 'a@..',
  'etiket tire ile başlar': 'a@-gumushane.edu.tr',
  'etiket tire ile biter': 'a@gumushane-.edu.tr',
  'alan adı tire ile biter': 'a@gumushane.edu.tr-',
  'yalnız tire etiketi': 'a@-.tr',
  // Alan adı karakterleri.
  'alt çizgi': 'a@gumushane_edu.tr',
  'virgül': 'a@gumushane,edu.tr',
  'eğik çizgi': 'a@gumushane.edu.tr/x',
  'iki nokta (port)': 'a@gumushane.edu.tr:25',
  'köşeli parantez': 'a@[127.0.0.1]',
  'büyüktür işareti': 'a@gumushane.edu.tr>',
  'Türkçe ş': 'a@gumuşhane.edu.tr',
  'Türkçe Ş': 'a@GUMUŞHANE.EDU.TR',
  'Türkçe ü': 'a@gümüşhane.edu.tr',
  'Türkçe İ': 'a@GUMUSHANE.EDU.TR.İ',
  'noktasız ı (U+0131)': 'a@gumushane.edu.tr.\u0131',
  'uzun s (U+017F)': 'a@gumu\u017Fhane.edu.tr',
  'Kelvin işareti (U+212A)': 'a@\u212Aulup.gumushane.edu.tr',
  'Kiril e (U+0435)': 'a@gumushane.\u0435du.tr',
  'tam genişlik g (U+FF47)': 'a@\uFF47umushane.edu.tr',
  'ideografik nokta (U+3002)': 'a@gumushane\u3002edu\u3002tr',
  'punycode olmayan IDN': 'a@örnek.com',
};

/// Tüm külliyat: adres → beklenen yanıt.
final Map<String, _Expected> _corpus = {
  for (final email in _valid.values) email: _ok,
  for (final email in _foreignDomain.values) email: _foreign,
  for (final email in _brokenButAllowedDomain.values) email: _brokenAllowed,
  for (final email in _brokenAndForeign.values) email: _broken,
};

/// Prototipin biçim denetimi (`screens-auth.js` `emailOk`).
final RegExp _prototypeEmailOk = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Test adında güvenle gösterilebilen biçim (denetim karakterleri kaçışlı).
String _show(String value) => Uri.encodeFull(value);

void main() {
  group('T-08 · EmailDomainValidator · külliyat', () {
    test('dört grup birbirinden ayrık ve yeterince büyük', () {
      final total =
          _valid.length +
          _foreignDomain.length +
          _brokenButAllowedDomain.length +
          _brokenAndForeign.length;

      expect(_corpus, hasLength(total), reason: 'gruplar arasında tekrar var');
      expect(total, greaterThan(90));
    });

    for (final MapEntry(key: reason, value: email) in _valid.entries) {
      test('geçerli ve izinli ($reason): ${_show(email)}', () {
        expect(EmailDomainValidator.isWellFormed(email), isTrue);
        expect(EmailDomainValidator.isAllowedDomain(email), isTrue);
      });
    }

    for (final MapEntry(key: reason, value: email) in _foreignDomain.entries) {
      test('biçim geçerli, alan adı izinsiz ($reason): ${_show(email)}', () {
        expect(EmailDomainValidator.isWellFormed(email), isTrue);
        expect(EmailDomainValidator.isAllowedDomain(email), isFalse);
      });
    }

    for (final MapEntry(key: reason, value: email)
        in _brokenButAllowedDomain.entries) {
      test('biçim bozuk, alan adı izinli ($reason): ${_show(email)}', () {
        expect(EmailDomainValidator.isWellFormed(email), isFalse);
        expect(EmailDomainValidator.isAllowedDomain(email), isTrue);
      });
    }

    for (final MapEntry(key: reason, value: email)
        in _brokenAndForeign.entries) {
      test('biçim bozuk, alan adı izinsiz ($reason): ${_show(email)}', () {
        expect(EmailDomainValidator.isWellFormed(email), isFalse);
        expect(EmailDomainValidator.isAllowedDomain(email), isFalse);
      });
    }
  });

  group('T-08 · EmailDomainValidator · isAllowedDomain', () {
    test('izinli iki alan adını kabul eder', () {
      expect(
        EmailDomainValidator.isAllowedDomain('a@ogr.gumushane.edu.tr'),
        isTrue,
      );
      expect(
        EmailDomainValidator.isAllowedDomain('a@gumushane.edu.tr'),
        isTrue,
      );
    });

    test('listedeki her alan adını kabul eder; alt alan ve benzerini '
        'reddeder', () {
      for (final domain in EmailDomainPolicy.allowedDomains) {
        expect(EmailDomainValidator.isAllowedDomain('kisi@$domain'), isTrue);
        expect(
          EmailDomainValidator.isAllowedDomain('kisi@${domain.toUpperCase()}'),
          isTrue,
        );
        expect(EmailDomainValidator.isAllowedDomain('a@sub.$domain'), isFalse);
        expect(EmailDomainValidator.isAllowedDomain('a@x$domain'), isFalse);
        expect(
          EmailDomainValidator.isAllowedDomain('a@$domain.evil.com'),
          isFalse,
        );
        expect(EmailDomainValidator.isAllowedDomain('a@${domain}x'), isFalse);
      }
    });

    test('EmailDomainPolicy.isAllowed ile her girdide aynı yanıt (delege)', () {
      for (final email in _corpus.keys) {
        expect(
          EmailDomainValidator.isAllowedDomain(email),
          EmailDomainPolicy.isAllowed(email),
          reason: _show(email),
        );
      }
    });

    test('alan adı listesi bu dosyada tutulmaz (CD-76 tek kaynak)', () {
      final code =
          readRepoFile(
                'packages/gu_data/lib/src/utils/email_domain_validator.dart',
              )
              .split('\n')
              .where((line) => !line.trimLeft().startsWith('//'))
              .join('\n');

      expect(code, contains('EmailDomainPolicy.isAllowed(email)'));
      expect(code, isNot(contains('gumushane')));
      expect(code, isNot(contains('allowedDomains')));
      expect(code, isNot(contains('edu.tr')));
    });
  });

  group('T-08 · EmailDomainValidator · isWellFormed · @ işareti', () {
    test('tam olarak bir @ ister', () {
      expect(EmailDomainValidator.isWellFormed('ab.cd'), isFalse);
      expect(EmailDomainValidator.isWellFormed('a@b.cd'), isTrue);
      expect(EmailDomainValidator.isWellFormed('a@b@c.de'), isFalse);
      expect(EmailDomainValidator.isWellFormed('a@@b.cd'), isFalse);
      expect(EmailDomainValidator.isWellFormed('@a@b.cd'), isFalse);
      expect(EmailDomainValidator.isWellFormed('a@b.cd@'), isFalse);
    });

    test('@ başta ya da sonda olamaz', () {
      expect(EmailDomainValidator.isWellFormed('@b.cd'), isFalse);
      expect(EmailDomainValidator.isWellFormed('a@'), isFalse);
      expect(EmailDomainValidator.isWellFormed('@'), isFalse);
    });
  });

  group('T-08 · EmailDomainValidator · isWellFormed · yerel kısım', () {
    test('uzunluk sınırları: 1 ve 64 geçer; 0 ve 65 geçmez', () {
      expect(EmailDomainValidator.isWellFormed('@b.cd'), isFalse);
      expect(EmailDomainValidator.isWellFormed('a@b.cd'), isTrue);
      expect(EmailDomainValidator.isWellFormed('${'a' * 63}@b.cd'), isTrue);
      expect(EmailDomainValidator.isWellFormed('$_local64@b.cd'), isTrue);
      expect(EmailDomainValidator.isWellFormed('$_local65@b.cd'), isFalse);
      expect(EmailDomainValidator.isWellFormed('${'a' * 1000}@b.cd'), isFalse);
    });

    test('yazdırılabilir her ASCII karakteri (boşluk ve @ hariç) kabul '
        'edilir', () {
      var accepted = 0;
      for (var unit = 0x21; unit <= 0x7E; unit++) {
        final char = String.fromCharCode(unit);
        if (char == '@') continue;

        expect(
          EmailDomainValidator.isWellFormed('a${char}b@b.cd'),
          isTrue,
          reason: 'karakter "$char"',
        );
        accepted++;
      }

      expect(accepted, 93);
    });

    test('boşluk ve denetim karakterleri (0x00–0x20, 0x7F) reddedilir', () {
      for (final unit in [for (var u = 0; u <= 0x20; u++) u, 0x7F]) {
        expect(
          EmailDomainValidator.isWellFormed(
            'a${String.fromCharCode(unit)}b@b.cd',
          ),
          isFalse,
          reason: 'kod birimi 0x${unit.toRadixString(16)}',
        );
      }
    });

    test('ASCII dışı her kod birimi reddedilir (0x80–0xFFFF örneklemi)', () {
      for (final unit in [
        0x80,
        0x85,
        0xA0,
        0xC7,
        0xE7,
        0x11E,
        0x130,
        0x131,
        0x15F,
        0x2000,
        0x200B,
        0x2028,
        0x202E,
        0x3000,
        0xFEFF,
        0xFF21,
        0xFFFF,
      ]) {
        expect(
          EmailDomainValidator.isWellFormed(
            'a${String.fromCharCode(unit)}b@b.cd',
          ),
          isFalse,
          reason: 'U+${unit.toRadixString(16).toUpperCase()}',
        );
      }
    });

    test('yalnızca yerel kısım uzunluğu sayılır (alan adı hariç)', () {
      final longDomain = '${'a' * 63}.${'b' * 63}.${'c' * 63}.tr';

      expect(EmailDomainValidator.isWellFormed('a@$longDomain'), isTrue);
      expect(
        EmailDomainValidator.isWellFormed('$_local64@$longDomain'),
        isTrue,
      );
    });
  });

  group('T-08 · EmailDomainValidator · isWellFormed · alan adı', () {
    test('en az bir nokta ister', () {
      expect(EmailDomainValidator.isWellFormed('a@localhost'), isFalse);
      expect(EmailDomainValidator.isWellFormed('a@b.c'), isTrue);
      expect(EmailDomainValidator.isWellFormed('a@b.c.d.e.f'), isTrue);
    });

    test('her etiket doludur (baş, son ve ardışık nokta yok)', () {
      expect(EmailDomainValidator.isWellFormed('a@.b.c'), isFalse);
      expect(EmailDomainValidator.isWellFormed('a@b.c.'), isFalse);
      expect(EmailDomainValidator.isWellFormed('a@b..c'), isFalse);
      expect(EmailDomainValidator.isWellFormed('a@.'), isFalse);
      expect(EmailDomainValidator.isWellFormed('a@...'), isFalse);
    });

    test('tire yalnızca etiket içinde olabilir', () {
      expect(EmailDomainValidator.isWellFormed('a@b-c.de'), isTrue);
      expect(EmailDomainValidator.isWellFormed('a@b--c.de'), isTrue);
      expect(EmailDomainValidator.isWellFormed('a@b.c-d'), isTrue);
      expect(EmailDomainValidator.isWellFormed('a@-b.cd'), isFalse);
      expect(EmailDomainValidator.isWellFormed('a@b-.cd'), isFalse);
      expect(EmailDomainValidator.isWellFormed('a@b.-cd'), isFalse);
      expect(EmailDomainValidator.isWellFormed('a@b.cd-'), isFalse);
      expect(EmailDomainValidator.isWellFormed('a@-.cd'), isFalse);
      expect(EmailDomainValidator.isWellFormed('a@--.cd'), isFalse);
    });

    test('ASCII taraması: yalnızca harf, rakam, tire ve nokta kabul '
        'edilir', () {
      final allowed = RegExp(r'^[A-Za-z0-9.\-]$');
      var accepted = 0;
      for (var unit = 0; unit <= 0x7F; unit++) {
        final char = String.fromCharCode(unit);
        if (char == '@') continue;
        final expected = allowed.hasMatch(char);

        expect(
          EmailDomainValidator.isWellFormed('a@b${char}c.de'),
          expected,
          reason: 'kod birimi 0x${unit.toRadixString(16)}',
        );
        if (expected) accepted++;
      }

      // 26 küçük + 26 büyük harf + 10 rakam + tire + nokta.
      expect(accepted, 64);
    });

    test('ASCII büyük harf kabul edilir; EmailDomainPolicy ile tutarlı', () {
      for (final domain in EmailDomainPolicy.allowedDomains) {
        final upper = 'a@${domain.toUpperCase()}';

        expect(EmailDomainValidator.isWellFormed(upper), isTrue);
        expect(EmailDomainValidator.isAllowedDomain(upper), isTrue);
      }
    });

    test('ASCII dışı harf büyük/küçük katlamasıyla da kabul edilmez', () {
      // Dart'ta U+017F.toUpperCase() == 'S', U+0131.toUpperCase() == 'I',
      // U+212A.toLowerCase() == 'k'; hiçbiri ASCII harf sayılmaz.
      expect(
        EmailDomainValidator.isWellFormed('a@gumu\u017Fhane.edu.tr'),
        isFalse,
      );
      expect(
        EmailDomainValidator.isWellFormed('a@gumushane.edu.tr.\u0131o'),
        isFalse,
      );
      expect(EmailDomainValidator.isWellFormed('a@\u212Aulup.edu.tr'), isFalse);
      expect(EmailDomainValidator.isWellFormed('a@gumushane.edu.tİ'), isFalse);
    });

    test('sayısal etiketler ve tek karakterli etiketler geçerlidir', () {
      expect(EmailDomainValidator.isWellFormed('a@1.2'), isTrue);
      expect(EmailDomainValidator.isWellFormed('a@x.y'), isTrue);
      expect(EmailDomainValidator.isWellFormed('a@3com.com'), isTrue);
    });
  });

  group('T-08 · EmailDomainValidator · isWellFormed · sağlamlık', () {
    test('girdi kırpılmaz', () {
      expect(EmailDomainValidator.isWellFormed('a@gumushane.edu.tr'), isTrue);
      expect(EmailDomainValidator.isWellFormed(' a@gumushane.edu.tr'), isFalse);
      expect(EmailDomainValidator.isWellFormed('a@gumushane.edu.tr '), isFalse);
      expect(
        EmailDomainValidator.isWellFormed('\ta@gumushane.edu.tr\n'),
        isFalse,
      );
    });

    test('saf işlevdir: aynı girdiye aynı yanıt', () {
      for (final email in _corpus.keys) {
        expect(
          EmailDomainValidator.isWellFormed(email),
          EmailDomainValidator.isWellFormed(email),
          reason: _show(email),
        );
      }
    });

    test('çok uzun ve bozuk girdide hata fırlatmaz', () {
      final inputs = [
        'a' * 200000,
        '@' * 50000,
        '.' * 50000,
        'a@${'-' * 100000}.tr',
        'a@${'a.' * 50000}tr',
        'a@${'a' * 100000}!',
        '${'a' * 100000}@b.cd',
        String.fromCharCodes([0xD83D]),
        'a@${String.fromCharCodes([0xDE00])}.tr',
      ];

      for (final input in inputs) {
        expect(() => EmailDomainValidator.isWellFormed(input), returnsNormally);
        expect(
          () => EmailDomainValidator.isAllowedDomain(input),
          returnsNormally,
        );
      }
      expect(EmailDomainValidator.isWellFormed('a@${'a.' * 50000}tr'), isTrue);
      expect(EmailDomainValidator.isWellFormed('a@${'a' * 100000}!'), isFalse);
    });
  });

  group('T-08 · EmailDomainValidator · iki denetim birlikte', () {
    bool accepted(String email) =>
        EmailDomainValidator.isWellFormed(email) &&
        EmailDomainValidator.isAllowedDomain(email);

    test('yalnızca "geçerli ve izinli" grubu kayıt için kabul edilir', () {
      for (final MapEntry(key: email, value: expected) in _corpus.entries) {
        expect(
          accepted(email),
          expected.wellFormed && expected.allowed,
          reason: _show(email),
        );
      }
      expect(_corpus.keys.where(accepted), unorderedEquals(_valid.values));
    });

    test('EmailDomainPolicy tek başına bozuk adresleri kabul eder; biçim '
        'denetimi bu boşluğu kapatır', () {
      for (final email in _brokenButAllowedDomain.values) {
        expect(
          EmailDomainPolicy.isAllowed(email),
          isTrue,
          reason: _show(email),
        );
        expect(accepted(email), isFalse, reason: _show(email));
      }
    });

    test('demo verideki 226 kullanıcı e-postası geçerli ve izinlidir', () {
      final users =
          readRepoJson('tool/seed/demo-data.json')['users']!
              as Map<String, Object?>;
      final emails = [
        for (final user in users.values)
          (user! as Map<String, Object?>)['email']! as String,
      ];

      expect(emails, hasLength(226));
      expect(emails.where((email) => !accepted(email)), isEmpty);
    });

    test('demo verideki 14 kulüp iletişim e-postası biçimce geçerlidir', () {
      final clubs =
          readRepoJson('tool/seed/demo-data.json')['clubs']!
              as Map<String, Object?>;
      final emails = [
        for (final club in clubs.values)
          ((club! as Map<String, Object?>)['social']!
                  as Map<String, Object?>)['email']!
              as String,
      ];

      expect(emails, hasLength(14));
      expect(
        emails.where((email) => !EmailDomainValidator.isWellFormed(email)),
        isEmpty,
      );
    });
  });

  group('T-08 · EmailDomainValidator · prototip uyumu', () {
    test('prototip emailOk deseni kaynakta duruyor', () {
      expect(
        readRepoFile('design/prototype/app/screens-auth.js'),
        contains(r'const emailOk = (e) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/'),
      );
    });

    test('isWellFormed prototipten daha gevşek değildir (kabul ettiği her '
        'adresi prototip de kabul eder)', () {
      final wellFormed = _corpus.keys.where(EmailDomainValidator.isWellFormed);

      expect(wellFormed.length, greaterThan(30));
      for (final email in wellFormed) {
        expect(_prototypeEmailOk.hasMatch(email), isTrue, reason: _show(email));
      }
    });

    test('prototipin kabul edip isWellFormed reddettiği adresler yalnızca '
        'ASCII dışı / yapısı bozuk olanlardır', () {
      final stricter = _corpus.keys.where(
        (email) =>
            _prototypeEmailOk.hasMatch(email) &&
            !EmailDomainValidator.isWellFormed(email),
      );

      expect(stricter, isNotEmpty);
      for (final email in stricter) {
        final at = email.indexOf('@');
        final local = email.substring(0, at);
        final domain = email.substring(at + 1);
        final nonAscii = email.codeUnits.any((u) => u > 0x7E || u < 0x21);
        final badDomain = !RegExp(
          '^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?'
          r'(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+$',
        ).hasMatch(domain);

        expect(
          nonAscii || badDomain || local.length > 64,
          isTrue,
          reason: _show(email),
        );
      }
    });
  });
}
