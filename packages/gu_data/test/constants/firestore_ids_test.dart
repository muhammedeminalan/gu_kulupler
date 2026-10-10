// T-08 · FirestoreIds: bileşik belge ID biçimleri (PLAN §9.4 tablosuyla
// parite), bilet kodu / destek numarası desenleri, QR yükü ve parseTicketQr
// (geçerli / geçersiz), demo veriyle uyum.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/repo_sources.dart';

/// PLAN §9.4 tablosu (`Belge | ID biçimi | Üretici / sabit | Not`).
final MarkdownTable _idTable = markdownTable(
  readRepoFile('docs/PLAN.md'),
  heading: '### 9.4 ',
);

/// §9.4 tablosunda [document] satırının [column] hücresindeki kod parçaları.
List<String> _spans(String document, int column) =>
    codeSpans(_idTable.rowWhereFirstCell(document)[column]);

/// [spans] içinde `<prefix>` ile başlayan tek parçanın kalanı.
String _valueAfter(List<String> spans, String prefix) =>
    spans.singleWhere((s) => s.startsWith(prefix)).substring(prefix.length);

final RegExp _ticketCode = RegExp(FirestoreIds.ticketCodePattern);
final RegExp _supportTicketNo = RegExp(FirestoreIds.supportTicketNoPattern);

/// Demo verideki bir koleksiyon (belge ID → belge).
Map<String, Map<String, Object?>> _demo(String collection) =>
    (readRepoJson('tool/seed/demo-data.json')[collection]!
            as Map<String, Object?>)
        .map((id, doc) => MapEntry(id, doc! as Map<String, Object?>));

/// Desendeki `[A-HJ-NP-Z2-9]` karakter sınıfını tek tek karakterlere açar.
Set<String> _expandClass(String characterClass) {
  final chars = <String>{};
  final units = characterClass.codeUnits;
  for (var i = 0; i < units.length; i++) {
    if (i + 2 < units.length && units[i + 1] == 0x2D) {
      for (var unit = units[i]; unit <= units[i + 2]; unit++) {
        chars.add(String.fromCharCode(unit));
      }
      i += 2;
    } else {
      chars.add(String.fromCharCode(units[i]));
    }
  }
  return chars;
}

/// Geçerli bir bilet kodu (demo veriden).
const String _code = 'GU-CWV4-JMW9';

/// `parseTicketQr`'ın `null` dönmesi gereken girdiler (neden → yük).
const Map<String, String> _invalidPayloads = {
  // Yapı.
  'boş': '',
  'yalnız önek': 'gu:ticket:v1:',
  'yalnız şema': 'gu',
  'kod yok': 'gu:ticket:v1:e03',
  'kod boş': 'gu:ticket:v1:e03:',
  'etkinlik boş': 'gu:ticket:v1::$_code',
  'etkinlik parçası yok': 'gu:ticket:v1:$_code',
  'fazla parça (sonda)': 'gu:ticket:v1:e03:$_code:x',
  'fazla parça (etkinlikte :)': 'gu:ticket:v1:e:03:$_code',
  'fazla parça (başta)': 'x:gu:ticket:v1:e03:$_code',
  'ayraç yok': 'guticketv1e03$_code',
  'ayraç farklı (/)': 'gu/ticket/v1/e03/$_code',
  'ayraç farklı (;)': 'gu;ticket;v1;e03;$_code',
  'yalnız kod': _code,
  // Şema ve tür.
  'şema büyük harf': 'GU:ticket:v1:e03:$_code',
  'şema farklı': 'gk:ticket:v1:e03:$_code',
  'şema boş': ':ticket:v1:e03:$_code',
  'tür büyük harf': 'gu:TICKET:v1:e03:$_code',
  'tür farklı': 'gu:event:v1:e03:$_code',
  'tür çoğul': 'gu:tickets:v1:e03:$_code',
  // Sürüm.
  'sürüm v2': 'gu:ticket:v2:e03:$_code',
  'sürüm v10': 'gu:ticket:v10:e03:$_code',
  'sürüm V1': 'gu:ticket:V1:e03:$_code',
  'sürüm 1': 'gu:ticket:1:e03:$_code',
  'sürüm v1.0': 'gu:ticket:v1.0:e03:$_code',
  'sürüm boş': 'gu:ticket::e03:$_code',
  'sürüm yok': 'gu:ticket:e03:$_code',
  // Etkinlik ID'si.
  'etkinlikte /': 'gu:ticket:v1:events/e03:$_code',
  'etkinlik yalnız /': 'gu:ticket:v1:/:$_code',
  'etkinlikte yol kaçışı': 'gu:ticket:v1:../e03:$_code',
  // Kod.
  'kod küçük harf': 'gu:ticket:v1:e03:gu-cwv4-jmw9',
  'kod öneki küçük': 'gu:ticket:v1:e03:gu-CWV4-JMW9',
  'kodda I': 'gu:ticket:v1:e03:GU-CWVI-JMW9',
  'kodda O': 'gu:ticket:v1:e03:GU-CWVO-JMW9',
  'kodda 0': 'gu:ticket:v1:e03:GU-CWV0-JMW9',
  'kodda 1': 'gu:ticket:v1:e03:GU-CWV1-JMW9',
  'kod kısa': 'gu:ticket:v1:e03:GU-CWV4-JMW',
  'kod uzun': 'gu:ticket:v1:e03:GU-CWV4-JMW9A',
  'kod tiresiz': 'gu:ticket:v1:e03:GUCWV4JMW9',
  'kod öneksiz': 'gu:ticket:v1:e03:CWV4-JMW9',
  'kod destek numarası': 'gu:ticket:v1:e03:GU-7K3Q9X',
  'kod yer tutucu': 'gu:ticket:v1:e03:GU-XXXX-XXX1',
  // Boşluk ve görünmez karakterler (girdi kırpılmaz).
  'başta boşluk': ' gu:ticket:v1:e03:$_code',
  'sonda boşluk': 'gu:ticket:v1:e03:$_code ',
  'sonda satır sonu': 'gu:ticket:v1:e03:$_code\n',
  'sonda CRLF': 'gu:ticket:v1:e03:$_code\r\n',
  'sonda sekme': 'gu:ticket:v1:e03:$_code\t',
  'kod öncesi boşluk': 'gu:ticket:v1:e03: $_code',
  'şema sonrası boşluk': 'gu :ticket:v1:e03:$_code',
  'sıfır genişlikli boşluk': 'gu:ticket:v1:e03:$_code\u200B',
  // Başka içerikler.
  'URL': 'https://gumushane.edu.tr/ticket/e03/$_code',
  'JSON': '{"eventId":"e03","code":"$_code"}',
  'tam genişlik iki nokta': 'gu\uFF1Aticket\uFF1Av1\uFF1Ae03\uFF1A$_code',
  'iki satır': 'gu:ticket:v1:e03:$_code\ngu:ticket:v1:e04:$_code',
};

void main() {
  group('T-08 · FirestoreIds · bileşik ID üreticileri', () {
    test('membership = clubId_userId', () {
      expect(FirestoreIds.membership('c01', 'u123'), 'c01_u123');
    });

    test('rsvp = eventId_userId', () {
      expect(FirestoreIds.rsvp('e03', 'u_ayse'), 'e03_u_ayse');
    });

    test('block = blockerId_blockedId (PLAN §9.12 örneği)', () {
      expect(FirestoreIds.block('u_mehmet', 'u042'), 'u_mehmet_u042');
    });

    test('savedPost = userId_postId', () {
      expect(FirestoreIds.savedPost('u_mehmet', 'p21'), 'u_mehmet_p21');
    });

    test('report = reporterId_targetType_targetId', () {
      expect(FirestoreIds.report('u051', 'post', 'p17'), 'u051_post_p17');
      expect(FirestoreIds.report('u_ayse', 'user', 'u042'), 'u_ayse_user_u042');
    });

    test('announcementCounter = clubId_yyyyMMdd (PLAN §9.12 örneği)', () {
      expect(
        FirestoreIds.announcementCounter('c01', '20261008'),
        'c01_20261008',
      );
    });

    test('notification = type_refId_userId (PLAN §9.4 örnekleri)', () {
      expect(
        FirestoreIds.notification('event_reminder', 'e03', 'u_ayse'),
        'event_reminder_e03_u_ayse',
      );
      expect(
        FirestoreIds.notification('announcement', 'p07', 'u_ayse'),
        'announcement_p07_u_ayse',
      );
    });

    test('notification saf birleştirmedir: aynı (tür, ref, alıcı) her zaman '
        'aynı kimliği verir — tekrar deneme çift belge üretmez', () {
      String id() =>
          FirestoreIds.notification('application_approved', 'c01', 'u_ayse');

      expect(id(), id());
      expect(id(), 'application_approved_c01_u_ayse');
    });

    test('tekrarlanabilen olayda kimlik ÇAKIŞIR: refId olay başına tekil '
        'olmalı (çağıranın sorumluluğu — CD-129, W-49)', () {
      // onayla → geri al → yeniden onayla: iki ayrı olay, aynı üçlü.
      final firstApproval = FirestoreIds.notification(
        'application_approved',
        'c01',
        'u_ayse',
      );
      final secondApproval = FirestoreIds.notification(
        'application_approved',
        'c01',
        'u_ayse',
      );
      // Olayı ayırt eden parça refId'ye eklenince kimlikler ayrışır.
      final discriminated = {
        for (final occurrence in ['c01-0', 'c01-1', 'c01-2'])
          FirestoreIds.notification(
            'application_approved',
            occurrence,
            'u_ayse',
          ),
      };

      expect(secondApproval, firstApproval);
      expect(discriminated, hasLength(3));
      expect(discriminated, isNot(contains(firstApproval)));
    });

    test('kimlik tür, referans ve alıcının her birine duyarlıdır', () {
      final base = FirestoreIds.notification('role_changed', 'c01', 'u_ayse');

      expect(
        FirestoreIds.notification('removed_from_club', 'c01', 'u_ayse'),
        isNot(base),
      );
      expect(
        FirestoreIds.notification('role_changed', 'c02', 'u_ayse'),
        isNot(base),
      );
      expect(
        FirestoreIds.notification('role_changed', 'c01', 'u_mehmet'),
        isNot(base),
      );
    });

    test('PLAN §9.4 bildirim satırı tekillik koşulunu ve borcu kaydeder', () {
      final note = _idTable.rowWhereFirstCell('`notifications/{id}`').last;

      expect(note, contains('**`refId` olay başına tekil olmalı**'));
      expect(note, contains('CD-129'));
      expect(note, contains('W-49'));
    });

    test('vote = oy verenin uid değeri', () {
      expect(FirestoreIds.vote('u_ayse'), 'u_ayse');
      expect(FirestoreIds.vote('8kQ2xW1bN5cR7dT9fV3h'), '8kQ2xW1bN5cR7dT9fV3h');
    });

    test('alt çizgili ve otomatik ID parçaları olduğu gibi birleşir', () {
      const autoId = 'Zx81kQ2xW1bN5cR7dT9f';

      expect(FirestoreIds.membership('c01', 'u_p_c01'), 'c01_u_p_c01');
      expect(FirestoreIds.membership(autoId, autoId), '${autoId}_$autoId');
      expect(FirestoreIds.rsvp(autoId, 'u_p_c01'), '${autoId}_u_p_c01');
    });

    test('parça sırası anlamlıdır (yer değiştirince ID değişir)', () {
      expect(
        FirestoreIds.membership('c01', 'u1'),
        isNot(FirestoreIds.membership('u1', 'c01')),
      );
      expect(
        FirestoreIds.block('u1', 'u2'),
        isNot(FirestoreIds.block('u2', 'u1')),
      );
      expect(
        FirestoreIds.report('u1', 'post', 'p1'),
        isNot(FirestoreIds.report('p1', 'post', 'u1')),
      );
    });

    test('aynı girdi her zaman aynı ID (deterministik)', () {
      expect(
        FirestoreIds.notification('system', 'welcome', 'u1'),
        FirestoreIds.notification('system', 'welcome', 'u1'),
      );
      expect(FirestoreIds.rsvp('e1', 'u1'), FirestoreIds.rsvp('e1', 'u1'));
    });

    test('üretilen ID tek bir Firestore yol parçasıdır', () {
      final ids = [
        FirestoreIds.membership('c01', 'u_p_c01'),
        FirestoreIds.rsvp('e03', 'u_ayse'),
        FirestoreIds.block('u1', 'u2'),
        FirestoreIds.savedPost('u1', 'p1'),
        FirestoreIds.report('u1', 'comment', 'cm01'),
        FirestoreIds.announcementCounter('c01', '20261008'),
        FirestoreIds.notification('role_changed', 'c01', 'u1'),
        FirestoreIds.vote('u1'),
      ];

      for (final id in ids) {
        expect(id, isNot(contains('/')));
        expect(id, isNot(startsWith('__')));
        expect(id, isNotEmpty);
      }
    });
  });

  group('T-08 · FirestoreIds · PLAN §9.4 tablo paritesi', () {
    test('tablo başlığı', () {
      expect(_idTable.header, ['Belge', 'ID biçimi', 'Üretici / sabit', 'Not']);
    });

    test('ID biçimi sütunu üreticilerle birebir (yer tutucu yöntemi)', () {
      expect(_spans('`memberships/{id}`', 1), [
        FirestoreIds.membership(r'${clubId}', r'${userId}'),
      ]);
      expect(_spans('`rsvps/{id}`', 1), [
        FirestoreIds.rsvp(r'${eventId}', r'${userId}'),
      ]);
      expect(_spans('`notifications/{id}`', 1), [
        FirestoreIds.notification(r'${type}', r'${refId}', r'${userId}'),
      ]);
      expect(_spans('`reports/{id}`', 1), [
        FirestoreIds.report(
          r'${reporterId}',
          r'${targetType}',
          r'${targetId}',
        ),
      ]);
      expect(_spans('`blocks/{id}`', 1), [
        FirestoreIds.block(r'${blockerId}', r'${blockedId}'),
      ]);
      expect(_spans('`savedPosts/{id}`', 1), [
        FirestoreIds.savedPost(r'${userId}', r'${postId}'),
      ]);
      expect(_spans('`announcementCounters/{id}`', 1), [
        FirestoreIds.announcementCounter(r'${clubId}', r'${yyyyMMdd}'),
      ]);
    });

    test('kapak tohumu biçimleri', () {
      expect(_spans('`coverSeed` alanları', 1), [
        FirestoreIds.clubCoverSeed('{clubId}'),
        FirestoreIds.eventCoverSeed('{eventId}'),
      ]);
    });

    test('anket seçeneği aralığı o1–o4', () {
      expect(_spans('`poll.options[].id`', 1), [
        FirestoreIds.pollOption(0),
        FirestoreIds.pollOption(Limits.pollOptionsMax - 1),
      ]);
    });

    test('üretici sütunu yalnızca var olan üyeleri anar', () {
      final mentioned = {
        for (final row in _idTable.rows)
          for (final cell in row)
            for (final span in codeSpans(cell))
              if (RegExp(r'^FirestoreIds\.(\w+)').firstMatch(span)
                  case final match?)
                match.group(1)!,
      };

      expect(mentioned, {
        'membership',
        'vote',
        'rsvp',
        'notification',
        'report',
        'block',
        'savedPost',
        'supportTicketNoPattern',
        'announcementCounter',
        'ticketCodePattern',
        'ticketQrPayload',
        'clubCoverSeed',
        'eventCoverSeed',
        'pollOption',
      });
    });

    test('bilet kodu deseni', () {
      expect(
        _valueAfter(
          _spans('`rsvps.ticketCode`', 2),
          'FirestoreIds.ticketCodePattern = ',
        ),
        FirestoreIds.ticketCodePattern,
      );
    });

    test('destek numarası deseni', () {
      expect(
        _valueAfter(
          _spans('`supportTickets/{id}`', 2),
          'FirestoreIds.supportTicketNoPattern = ',
        ),
        FirestoreIds.supportTicketNoPattern,
      );
    });

    test('QR yükü ve sürüm öneki', () {
      final spans = _spans('`rsvps.ticketCode`', 3);

      expect(
        _valueAfter(spans, 'FirestoreIds.ticketQrPayload(eventId, code) = '),
        "'${FirestoreIds.ticketQrPayload(r'$eventId', r'$code')}'",
      );
      expect(
        _valueAfter(spans, 'ticketQrVersion = '),
        "'${FirestoreIds.ticketQrVersion}'",
      );
    });

    test('kaynak dosyadaki açık üyeler: 16 ad, ters çözüm metodu yok', () {
      final source = readRepoFile(
        'packages/gu_data/lib/src/constants/firestore_ids.dart',
      );
      final members = [
        for (final match in RegExp(
          r'^ {2}static (?:const |final )?(?:\(\{[^)]*\}\)\??|[\w<>?]+) (\w+)',
          multiLine: true,
        ).allMatches(source))
          if (!match.group(1)!.startsWith('_')) match.group(1)!,
      ];

      expect(members, [
        'membership',
        'rsvp',
        'block',
        'savedPost',
        'report',
        'announcementCounter',
        'notification',
        'vote',
        'clubCoverSeed',
        'eventCoverSeed',
        'pollOption',
        'ticketCodePattern',
        'supportTicketNoPattern',
        'ticketQrVersion',
        'ticketQrPayload',
        'parseTicketQr',
      ]);
      // Bileşik ID parçalanarak okunmaz (§9.4, §10.3): tek ayrıştırıcı QR.
      expect(members.where((m) => m.startsWith('parse')), ['parseTicketQr']);
      expect(members.where((m) => m.startsWith('split')), isEmpty);
    });
  });

  group('T-08 · FirestoreIds · kapak tohumu ve anket seçeneği', () {
    test('clubCoverSeed = club-{clubId}', () {
      expect(FirestoreIds.clubCoverSeed('c01'), 'club-c01');
    });

    test('eventCoverSeed = event-{eventId}', () {
      expect(FirestoreIds.eventCoverSeed('e03'), 'event-e03');
    });

    test('pollOption sıfır tabanlı dizinden o1–o4 üretir', () {
      expect(
        [for (var i = 0; i < 4; i++) FirestoreIds.pollOption(i)],
        ['o1', 'o2', 'o3', 'o4'],
      );
    });

    test('pollOption kümesi Limits.pollOptionsMax kadardır ve tekildir', () {
      final ids = {
        for (var i = 0; i < Limits.pollOptionsMax; i++)
          FirestoreIds.pollOption(i),
      };

      expect(ids, hasLength(Limits.pollOptionsMax));
    });

    for (final index in [-1, -100, Limits.pollOptionsMax, 5, 100]) {
      test('pollOption($index) aralık dışı → RangeError', () {
        expect(() => FirestoreIds.pollOption(index), throwsRangeError);
      });
    }
  });

  group('T-08 · FirestoreIds · ticketCodePattern', () {
    test('değer', () {
      expect(
        FirestoreIds.ticketCodePattern,
        r'^GU-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$',
      );
    });

    test('Rules taslağı §3.8 biçimi ile aynı (çapasız)', () {
      final unanchored = FirestoreIds.ticketCodePattern.substring(
        1,
        FirestoreIds.ticketCodePattern.length - 1,
      );

      expect(
        readRepoFile('docs/firestore-rules-spec.md'),
        contains('`ticketCode` formatı `$unanchored`'),
      );
    });

    test('PLAN §10.3 tanımı ile aynı', () {
      expect(
        readRepoFile('docs/PLAN.md'),
        contains('`ticketCodePattern = ${FirestoreIds.ticketCodePattern}`'),
      );
    });

    test('karakter sınıfı = TicketCodeGenerator.alphabet (iki grupta da)', () {
      final classes = [
        for (final match in RegExp(
          r'\[([^\]]+)\]',
        ).allMatches(FirestoreIds.ticketCodePattern))
          match.group(1)!,
      ];

      expect(classes, hasLength(2));
      for (final characterClass in classes) {
        expect(
          _expandClass(characterClass),
          TicketCodeGenerator.alphabet.split('').toSet(),
        );
      }
    });

    for (final code in [
      'GU-CWV4-JMW9',
      'GU-AAAA-AAAA',
      'GU-9999-2222',
      'GU-ZZZZ-ZZZZ',
      'GU-HJNP-2Z9A',
      'GU-7K3Q-9XAB',
    ]) {
      test('eşleşir: $code', () {
        expect(_ticketCode.hasMatch(code), isTrue);
      });
    }

    for (final MapEntry(key: reason, value: code) in const {
      'boş': '',
      'yer tutucu (X geçerli, ama 0 değil)': 'GU-XXXX-XXX0',
      'I harfi': 'GU-AAAI-AAAA',
      'O harfi': 'GU-AAAA-OAAA',
      'sıfır': 'GU-AAA0-AAAA',
      'bir': 'GU-AAAA-AAA1',
      'küçük harf': 'GU-aaaa-aaaa',
      'küçük önek': 'gu-AAAA-AAAA',
      'öneksiz': 'AAAA-AAAA',
      'başka önek': 'GK-AAAA-AAAA',
      'tek grup': 'GU-AAAAAAAA',
      'üç grup': 'GU-AAAA-AAAA-AAAA',
      'kısa ilk grup': 'GU-AAA-AAAA',
      'kısa ikinci grup': 'GU-AAAA-AAA',
      'uzun ilk grup': 'GU-AAAAA-AAAA',
      'uzun ikinci grup': 'GU-AAAA-AAAAA',
      'alt çizgi': 'GU_AAAA_AAAA',
      'boşluklu': 'GU-AAAA AAAA',
      'uzun tire (U+2013)': 'GU–AAAA–AAAA',
      'başta boşluk': ' GU-AAAA-AAAA',
      'sonda boşluk': 'GU-AAAA-AAAA ',
      'sonda satır sonu': 'GU-AAAA-AAAA\n',
      'önde ek': 'xGU-AAAA-AAAA',
      'sonda ek': 'GU-AAAA-AAAAx',
      'destek numarası': 'GU-7K3Q9X',
      'Türkçe harf': 'GU-AAAÇ-AAAA',
      'Türkçe İ': 'GU-AAAİ-AAAA',
      'tam genişlik A (U+FF21)': 'GU-AAA\uFF21-AAAA',
      'Kiril A (U+0410)': 'GU-AAA\u0410-AAAA',
    }.entries) {
      test('eşleşmez ($reason): ${Uri.encodeFull(code)}', () {
        expect(_ticketCode.hasMatch(code), isFalse);
      });
    }

    test('8 konumun her birinde yalnızca alfabe karakterleri kabul edilir '
        '(yazdırılabilir ASCII taraması)', () {
      const base = 'GU-AAAA-AAAA';
      const positions = [3, 4, 5, 6, 8, 9, 10, 11];
      var accepted = 0;
      for (final position in positions) {
        for (var unit = 0x20; unit <= 0x7E; unit++) {
          final char = String.fromCharCode(unit);
          final code = base.replaceRange(position, position + 1, char);

          expect(
            _ticketCode.hasMatch(code),
            TicketCodeGenerator.alphabet.contains(char),
            reason: 'konum $position, karakter "$char"',
          );
          if (_ticketCode.hasMatch(code)) accepted++;
        }
      }

      expect(accepted, positions.length * TicketCodeGenerator.alphabet.length);
    });

    test('demo verideki 944 bilet kodunun tamamı eşleşir ve tekildir', () {
      final codes = [
        for (final rsvp in _demo('rsvps').values) rsvp['ticketCode']! as String,
      ];

      expect(codes, hasLength(944));
      expect(codes.where((code) => !_ticketCode.hasMatch(code)), isEmpty);
      expect(codes.toSet(), hasLength(944));
    });
  });

  group('T-08 · FirestoreIds · supportTicketNoPattern', () {
    test('değer', () {
      expect(FirestoreIds.supportTicketNoPattern, r'^GU-[A-HJ-NP-Z2-9]{6}$');
    });

    test('PLAN §10.3 tanımı ile aynı', () {
      expect(
        readRepoFile('docs/PLAN.md'),
        contains(
          '`supportTicketNoPattern = ${FirestoreIds.supportTicketNoPattern}`',
        ),
      );
    });

    test('karakter sınıfı = TicketCodeGenerator.alphabet', () {
      final characterClass = RegExp(
        r'\[([^\]]+)\]',
      ).allMatches(FirestoreIds.supportTicketNoPattern).single.group(1)!;

      expect(
        _expandClass(characterClass),
        TicketCodeGenerator.alphabet.split('').toSet(),
      );
    });

    test('domain-model §2.15 örneği eşleşir', () {
      expect(
        readRepoFile('docs/domain-model.md'),
        contains('`ticketNo` (örn. `GU-7K3Q9X`'),
      );
      expect(_supportTicketNo.hasMatch('GU-7K3Q9X'), isTrue);
    });

    for (final ticketNo in [
      'GU-7K3Q9X',
      'GU-AAAAAA',
      'GU-222222',
      'GU-Z9Y8X7',
    ]) {
      test('eşleşir: $ticketNo', () {
        expect(_supportTicketNo.hasMatch(ticketNo), isTrue);
      });
    }

    for (final MapEntry(key: reason, value: ticketNo) in const {
      'boş': '',
      'kare işaretli (gösterim biçimi)': '#GU-7K3Q9X',
      'küçük harf': 'GU-7k3q9x',
      'I harfi': 'GU-7K3QIX',
      'O harfi': 'GU-7K3QOX',
      'sıfır': 'GU-7K3Q0X',
      'bir': 'GU-7K3Q1X',
      'kısa': 'GU-7K3Q9',
      'uzun': 'GU-7K3Q9XA',
      'öneksiz': '7K3Q9X',
      'bilet kodu': 'GU-CWV4-JMW9',
      'sonda satır sonu': 'GU-7K3Q9X\n',
      'başta boşluk': ' GU-7K3Q9X',
    }.entries) {
      test('eşleşmez ($reason): ${Uri.encodeFull(ticketNo)}', () {
        expect(_supportTicketNo.hasMatch(ticketNo), isFalse);
      });
    }

    test('bilet kodu ile destek numarası desenleri ayrışıktır', () {
      expect(_supportTicketNo.hasMatch('GU-CWV4-JMW9'), isFalse);
      expect(_ticketCode.hasMatch('GU-7K3Q9X'), isFalse);
    });
  });

  group('T-08 · FirestoreIds · ticketQrPayload', () {
    test('gu:ticket:v1:{eventId}:{code}', () {
      expect(
        FirestoreIds.ticketQrPayload('e03', _code),
        'gu:ticket:v1:e03:GU-CWV4-JMW9',
      );
    });

    test('sürüm öneki v1 ve yükte kullanılır', () {
      expect(FirestoreIds.ticketQrVersion, 'v1');
      expect(
        FirestoreIds.ticketQrPayload('e03', _code).split(':')[2],
        FirestoreIds.ticketQrVersion,
      );
    });

    test('D-30 ve domain-model §8 metinleriyle birebir (yer tutucu)', () {
      expect(
        readRepoFile('docs/decisions.md'),
        contains('`${FirestoreIds.ticketQrPayload('{eventId}', '{code}')}`'),
      );
      expect(
        readRepoFile('docs/domain-model.md'),
        contains(
          '`${FirestoreIds.ticketQrPayload('{eventId}', '{ticketCode}')}`',
        ),
      );
    });

    test('saf birleştirmedir: girdiyi doğrulamaz, değiştirmez', () {
      expect(
        FirestoreIds.ticketQrPayload('e03', 'geçersiz'),
        'gu:ticket:v1:e03:geçersiz',
      );
      expect(FirestoreIds.ticketQrPayload('', ''), 'gu:ticket:v1::');
    });
  });

  group('T-08 · FirestoreIds · parseTicketQr · geçerli', () {
    test('eventId ve code alanlarını döner', () {
      final parsed = FirestoreIds.parseTicketQr('gu:ticket:v1:e03:$_code');

      expect(parsed, isNotNull);
      expect(parsed!.eventId, 'e03');
      expect(parsed.code, _code);
      expect(parsed, (eventId: 'e03', code: _code));
    });

    test('ticketQrPayload çıktısını geri çözer (gidiş-dönüş)', () {
      for (final eventId in [
        'e01',
        'e22',
        'Zx81kQ2xW1bN5cR7dT9f',
        'event_with_underscore',
        'event-with-dash',
        'e.01',
        'É-etkinlik',
      ]) {
        expect(
          FirestoreIds.parseTicketQr(
            FirestoreIds.ticketQrPayload(eventId, _code),
          ),
          (eventId: eventId, code: _code),
          reason: eventId,
        );
      }
    });

    test('demo verideki 944 biletin tamamı gidiş-dönüş yapar', () {
      final rsvps = _demo('rsvps').values.toList();

      expect(rsvps, hasLength(944));
      for (final rsvp in rsvps) {
        final eventId = rsvp['eventId']! as String;
        final code = rsvp['ticketCode']! as String;

        expect(
          FirestoreIds.parseTicketQr(
            FirestoreIds.ticketQrPayload(eventId, code),
          ),
          (eventId: eventId, code: code),
        );
      }
    });

    test('alfabenin her karakteri kodda kabul edilir', () {
      for (final char in TicketCodeGenerator.alphabet.split('')) {
        final code = 'GU-$char$char$char$char-$char$char$char$char';

        expect(
          FirestoreIds.parseTicketQr('gu:ticket:v1:e03:$code'),
          (eventId: 'e03', code: code),
          reason: char,
        );
      }
    });

    test('etkinlik ID değeri olduğu gibi döner (kırpılmaz, küçültülmez)', () {
      expect(
        FirestoreIds.parseTicketQr('gu:ticket:v1:E03:$_code')!.eventId,
        'E03',
      );
    });
  });

  group('T-08 · FirestoreIds · parseTicketQr · geçersiz → null', () {
    for (final MapEntry(key: reason, value: payload)
        in _invalidPayloads.entries) {
      test('$reason: ${Uri.encodeFull(payload)}', () {
        expect(FirestoreIds.parseTicketQr(payload), isNull);
      });
    }

    test('geçerli yükün her tek karakter eksiltmesi geçersizdir ya da başka '
        'bir etkinliği gösterir', () {
      const payload = 'gu:ticket:v1:e03:$_code';
      for (var i = 0; i < payload.length; i++) {
        final mutated = payload.replaceRange(i, i + 1, '');
        final parsed = FirestoreIds.parseTicketQr(mutated);

        if (parsed != null) {
          // Yalnızca etkinlik ID'sinden karakter düşmesi biçimi bozmaz.
          expect(parsed.code, _code, reason: mutated);
          expect(parsed.eventId, isNot('e03'), reason: mutated);
          expect(i, inInclusiveRange(13, 15), reason: mutated);
        }
      }
    });

    test('bilet kodu geçersizse ticketQrPayload çıktısı da çözülmez', () {
      for (final code in ['GU-AAAA-AAA0', 'gu-aaaa-aaaa', 'GU-7K3Q9X', '']) {
        expect(
          FirestoreIds.parseTicketQr(FirestoreIds.ticketQrPayload('e03', code)),
          isNull,
          reason: code,
        );
      }
    });

    test('etkinlik ID değeri : ya da / içeriyorsa yük çözülmez', () {
      for (final eventId in ['e:03', 'events/e03', '/', ':', '']) {
        expect(
          FirestoreIds.parseTicketQr(
            FirestoreIds.ticketQrPayload(eventId, _code),
          ),
          isNull,
          reason: eventId,
        );
      }
    });
  });

  group('T-08 · FirestoreIds · demo veriyle uyum', () {
    test('515 üyelik ID değeri membership(clubId, userId) ile aynı', () {
      final memberships = _demo('memberships');

      expect(memberships, hasLength(515));
      for (final MapEntry(key: id, value: doc) in memberships.entries) {
        expect(
          FirestoreIds.membership(
            doc['clubId']! as String,
            doc['userId']! as String,
          ),
          id,
        );
      }
    });

    test('944 rsvp ID değeri rsvp(eventId, userId) ile aynı', () {
      final rsvps = _demo('rsvps');

      expect(rsvps, hasLength(944));
      for (final MapEntry(key: id, value: doc) in rsvps.entries) {
        expect(
          FirestoreIds.rsvp(
            doc['eventId']! as String,
            doc['userId']! as String,
          ),
          id,
        );
      }
    });

    test('14 kulübün coverSeed değeri clubCoverSeed(id)', () {
      final clubs = _demo('clubs');

      expect(clubs, hasLength(14));
      for (final MapEntry(key: id, value: doc) in clubs.entries) {
        expect(doc['coverSeed'], FirestoreIds.clubCoverSeed(id));
      }
    });

    test('22 etkinliğin coverSeed değeri eventCoverSeed(id)', () {
      final events = _demo('events');

      expect(events, hasLength(22));
      for (final MapEntry(key: id, value: doc) in events.entries) {
        expect(doc['coverSeed'], FirestoreIds.eventCoverSeed(id));
      }
    });

    test('anket seçenek ID değerleri pollOption(index) sırasında', () {
      final polls = [
        for (final post in _demo('posts').values)
          if (post['poll'] case final Map<String, Object?> poll) poll,
      ];

      expect(polls, hasLength(4));
      for (final poll in polls) {
        final options = (poll['options']! as List<Object?>)
            .cast<Map<String, Object?>>();

        expect(options.length, inInclusiveRange(2, Limits.pollOptionsMax));
        expect(
          [for (final option in options) option['id']],
          [for (var i = 0; i < options.length; i++) FirestoreIds.pollOption(i)],
        );
      }
    });

    test('alt çizgili kullanıcı ID değerleri bileşik ID içinde korunur '
        '(parçalayarak okuma güvenli değildir)', () {
      final ambiguous = _demo(
        'memberships',
      ).keys.where((id) => id.split('_').length > 2);

      // `c01_u_p_c01` → split('_') dört parça verir; clubId/userId yalnızca
      // belge alanlarından okunur (§9.4).
      expect(ambiguous, isNotEmpty);
      expect(ambiguous, contains('c01_u_p_c01'));
    });
  });
}
