// T-08 · EmailDomainPolicy (CD-76, D-27): izinli iki alan adı, alt alan ve
// benzer alan reddi, Rules regex paritesi.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/repo_sources.dart';

/// İzinli sayılması gereken adresler.
const List<String> _allowed = [
  'ayse.demir@ogr.gumushane.edu.tr',
  'zeynep.kaya@gumushane.edu.tr',
  'a@ogr.gumushane.edu.tr',
  'a@gumushane.edu.tr',
  // Alan adı büyük/küçük harf duyarsız (ASCII).
  'a@OGR.GUMUSHANE.EDU.TR',
  'a@GUMUSHANE.EDU.TR',
  'a@Ogr.Gumushane.Edu.Tr',
  'a@gUmUsHaNe.EdU.tR',
  // Yerel kısım politikayı etkilemez.
  'A.B+etiket@gumushane.edu.tr',
  'ÇĞİÖŞÜ@ogr.gumushane.edu.tr',
  'gmail.com@gumushane.edu.tr',
  // Biçim denetimi burada yapılmaz (EmailDomainValidator.isWellFormed).
  '@gumushane.edu.tr',
  'a@b@gumushane.edu.tr',
  ' a@gumushane.edu.tr',
];

/// Reddedilmesi gereken adresler (neden → adres).
const Map<String, String> _rejected = {
  // Alt alan adları.
  'alt alan: mail.': 'a@mail.gumushane.edu.tr',
  'alt alan: x.ogr.': 'a@x.ogr.gumushane.edu.tr',
  'alt alan: ogr.ogr.': 'a@ogr.ogr.gumushane.edu.tr',
  'alt alan: personel.': 'a@personel.gumushane.edu.tr',
  'alt alan: boş etiket': 'a@.gumushane.edu.tr',
  // Benzer alan adları.
  'benzer: önek': 'a@evilgumushane.edu.tr',
  'benzer: sonek alanı': 'a@gumushane.edu.tr.evil.com',
  'benzer: ogr bitişik': 'a@ogrgumushane.edu.tr',
  'benzer: nokta eksik': 'a@gumushaneedu.tr',
  'benzer: tire': 'a@gumushane-edu.tr',
  'benzer: kısa TLD': 'a@gumushane.edu.t',
  'benzer: TLD yok': 'a@gumushane.edu',
  'benzer: com.tr': 'a@gumushane.com.tr',
  'benzer: sondaki nokta': 'a@gumushane.edu.tr.',
  'benzer: çift nokta': 'a@gumushane..edu.tr',
  'benzer: yazım': 'a@gumushhane.edu.tr',
  // Başka alan adları.
  'başka: gmail': 'a@gmail.com',
  'başka: edu.tr': 'a@edu.tr',
  'başka: tr': 'a@tr',
  'başka: başka üniversite': 'a@ogr.atauni.edu.tr',
  // İzinli alan adı yerel kısımda.
  'yerel kısımda alan adı': 'gumushane.edu.tr@gmail.com',
  'son @ başka alan': 'a@gumushane.edu.tr@gmail.com',
  // @ işareti eksik ya da alan adı boş.
  '@ yok': 'gumushane.edu.tr',
  '@ yok (bitişik)': 'agumushane.edu.tr',
  'boş': '',
  'yalnız @': '@',
  'alan adı boş': 'a@',
  // Boşluk ve görünmez karakterler (girdi kırpılmaz).
  'sonda boşluk': 'a@gumushane.edu.tr ',
  '@ sonrası boşluk': 'a@ gumushane.edu.tr',
  'sonda sekme': 'a@gumushane.edu.tr\t',
  'sonda satır sonu': 'a@gumushane.edu.tr\n',
  'sıfır genişlikli boşluk': 'a@gumushane.edu.tr​',
  // ASCII dışı harfler: Unicode harf katlaması yapılmaz.
  'Türkçe ş': 'a@gumuşhane.edu.tr',
  'Türkçe Ş': 'a@GUMUŞHANE.EDU.TR',
  'Türkçe ü': 'a@gümüşhane.edu.tr',
  'uzun s (U+017F)': 'a@gumuſhane.edu.tr',
  'Kiril е (U+0435)': 'a@gumushane.еdu.tr',
  'Kiril о (U+043E)': 'a@оgr.gumushane.edu.tr',
  'tam genişlik g (U+FF47)': 'a@ｇumushane.edu.tr',
  'ideografik nokta (U+3002)': 'a@gumushane。edu。tr',
};

/// Rules `email.lower().matches(regex)` davranışının Dart karşılığı:
/// `matches` tüm dizgiyi eşler.
bool _rulesMatches(String loweredEmail) =>
    RegExp('^(?:${EmailDomainPolicy.rulesRegex()})\$').hasMatch(loweredEmail);

/// Yalnızca A–Z küçültür.
String _asciiLower(String value) => value.replaceAllMapped(
  RegExp('[A-Z]'),
  (match) => match.group(0)!.toLowerCase(),
);

void main() {
  group('T-08 · EmailDomainPolicy · allowedDomains', () {
    test('tam olarak iki alan adı, sırayla', () {
      expect(EmailDomainPolicy.allowedDomains, [
        'ogr.gumushane.edu.tr',
        'gumushane.edu.tr',
      ]);
    });

    test('tasarım sabiti ALLOWED_EMAIL_DOMAINS ile aynı (registry.json)', () {
      final constants =
          readRepoJson('design/extracted/registry.json')['constants']!
              as Map<String, Object?>;

      expect(
        EmailDomainPolicy.allowedDomains,
        constants['ALLOWED_EMAIL_DOMAINS'],
      );
    });

    test('D-27 karar metnindeki liste ile aynı', () {
      expect(
        readRepoFile('docs/decisions.md'),
        contains(
          '`ALLOWED_EMAIL_DOMAINS = '
          '${EmailDomainPolicy.allowedDomains.join(', ')}`',
        ),
      );
    });

    test('alan adları küçük harf ASCII, noktalı, tekil ve kırpılmış', () {
      expect(
        EmailDomainPolicy.allowedDomains.toSet(),
        hasLength(EmailDomainPolicy.allowedDomains.length),
      );
      for (final domain in EmailDomainPolicy.allowedDomains) {
        expect(
          domain,
          matches(RegExp(r'^[a-z0-9]+(?:\.[a-z0-9]+)+$')),
          reason: domain,
        );
        expect(domain, endsWith('.edu.tr'));
      }
    });

    test('liste değiştirilemez', () {
      expect(
        () => EmailDomainPolicy.allowedDomains.add('gmail.com'),
        throwsUnsupportedError,
      );
      expect(
        () => EmailDomainPolicy.allowedDomains[0] = 'gmail.com',
        throwsUnsupportedError,
      );
    });
  });

  group('T-08 · EmailDomainPolicy · isAllowed', () {
    test('iki izinli alan adını kabul eder', () {
      expect(EmailDomainPolicy.isAllowed('a@ogr.gumushane.edu.tr'), isTrue);
      expect(EmailDomainPolicy.isAllowed('a@gumushane.edu.tr'), isTrue);
    });

    test('listedeki her alan adı kendisiyle kabul edilir', () {
      for (final domain in EmailDomainPolicy.allowedDomains) {
        expect(EmailDomainPolicy.isAllowed('kisi@$domain'), isTrue);
        expect(
          EmailDomainPolicy.isAllowed('kisi@${domain.toUpperCase()}'),
          isTrue,
        );
      }
    });

    for (final email in _allowed) {
      test('kabul: "$email"', () {
        expect(EmailDomainPolicy.isAllowed(email), isTrue);
      });
    }

    for (final MapEntry(key: reason, value: email) in _rejected.entries) {
      test('ret ($reason): ${Uri.encodeFull(email)}', () {
        expect(EmailDomainPolicy.isAllowed(email), isFalse);
      });
    }

    test('alt alan adı hiçbir izinli alan için kabul edilmez', () {
      for (final domain in EmailDomainPolicy.allowedDomains) {
        expect(EmailDomainPolicy.isAllowed('a@sub.$domain'), isFalse);
        expect(EmailDomainPolicy.isAllowed('a@x$domain'), isFalse);
        expect(EmailDomainPolicy.isAllowed('a@$domain.com'), isFalse);
        expect(EmailDomainPolicy.isAllowed('a@${domain}x'), isFalse);
      }
    });

    test('son @ işaretinden sonraki kısım esas alınır', () {
      expect(
        EmailDomainPolicy.isAllowed('a@gmail.com@gumushane.edu.tr'),
        isTrue,
      );
      expect(
        EmailDomainPolicy.isAllowed('a@gumushane.edu.tr@gmail.com'),
        isFalse,
      );
    });

    test('demo verideki tüm kullanıcı e-postaları izinlidir (iki alan da '
        'temsil edilir)', () {
      final users =
          readRepoJson('tool/seed/demo-data.json')['users']!
              as Map<String, Object?>;
      final emails = [
        for (final user in users.values)
          (user! as Map<String, Object?>)['email']! as String,
      ];

      expect(emails, hasLength(226));
      expect(emails.where((e) => !EmailDomainPolicy.isAllowed(e)), isEmpty);
      expect(
        {for (final email in emails) email.split('@').last},
        EmailDomainPolicy.allowedDomains.toSet(),
      );
    });
  });

  group('T-08 · EmailDomainPolicy · rulesRegex', () {
    test(r'değer .*@(ogr\.gumushane\.edu\.tr|gumushane\.edu\.tr)', () {
      expect(
        EmailDomainPolicy.rulesRegex(),
        r'.*@(ogr\.gumushane\.edu\.tr|gumushane\.edu\.tr)',
      );
    });

    test('allowedDomains listesinden üretilir (sıra ve sayı aynı)', () {
      final regex = EmailDomainPolicy.rulesRegex();
      final alternatives = regex
          .substring(regex.indexOf('(') + 1, regex.lastIndexOf(')'))
          .split('|');

      expect(regex, startsWith('.*@('));
      expect(regex, endsWith(')'));
      expect(
        [for (final alt in alternatives) alt.replaceAll(r'\.', '.')],
        EmailDomainPolicy.allowedDomains,
      );
      expect(
        alternatives,
        everyElement(isNot(matches(RegExp(r'(?<!\\)\.')))),
        reason: 'kaçışsız nokta her karakteri eşler',
      );
    });

    test('Rules taslağındaki emailOk() deseni ile birebir (iki yerde)', () {
      // Rules kaynak metninde dizgi literal'i: ters bölüler çiftlenir.
      final literal =
          ".matches('${EmailDomainPolicy.rulesRegex().replaceAll(r'\', r'\\')}')";
      final spec = readRepoFile('docs/firestore-rules-spec.md');

      expect(literal.allMatches(spec), hasLength(2));
      expect(
        spec
            .split('\n')
            .where((line) => line.contains('.lower().matches('))
            .every((line) => line.contains(literal)),
        isTrue,
        reason: 'farklı bir e-posta deseni var',
      );
    });

    test('PLAN §9.1 tanımındaki desen ile birebir', () {
      // Markdown tablosunda boru kaçışlıdır (`\|`).
      expect(
        readRepoFile('docs/PLAN.md'),
        contains(
          '`static String rulesRegex()` → '
          '`${EmailDomainPolicy.rulesRegex().replaceAll('|', r'\|')}`',
        ),
      );
    });

    test('geçerli bir RegExp olarak derlenir', () {
      expect(() => RegExp(EmailDomainPolicy.rulesRegex()), returnsNormally);
    });

    test('isAllowed ile aynı kararı verir (ASCII ve Unicode küçültme)', () {
      final corpus = [..._allowed, ..._rejected.values];

      expect(corpus.length, greaterThan(50));
      for (final email in corpus) {
        final expected = EmailDomainPolicy.isAllowed(email);

        expect(
          _rulesMatches(_asciiLower(email)),
          expected,
          reason: 'ASCII küçültme: ${Uri.encodeFull(email)}',
        );
        expect(
          _rulesMatches(email.toLowerCase()),
          expected,
          reason: 'Unicode küçültme: ${Uri.encodeFull(email)}',
        );
      }
    });

    test('tam eşleşme ister: sonda ek olan adres deseni geçemez', () {
      expect(_rulesMatches('a@gumushane.edu.tr'), isTrue);
      expect(_rulesMatches('a@gumushane.edu.tr.evil.com'), isFalse);
      expect(_rulesMatches('a@gumushaneXeduXtr'), isFalse);
    });
  });
}
