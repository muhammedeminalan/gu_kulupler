// T-08 · Anonymization: silinmiş kullanıcı adı literal'i, anonimleştirme
// yükleri (users, private/account, private/contact, applicant) ve belge
// paritesi (PLAN §9.5, §10.4; Rules §3.1 / M14; domain-model §11).
//
// Bu dosyada FakeFirebaseFirestore KURULMAZ (bkz. base_fields_test.dart);
// yüklerin belgeye yazımı `anonymization_write_test.dart` içinde sınanır.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/repo_sources.dart';

final Matcher _isServerTimestamp = equals(FieldValue.serverTimestamp());

/// PLAN'daki `anahtar:değer, anahtar:değer` yazımını (ör.
/// `name:'x', bio:'', interests:[], year:null`) map'e çevirir.
///
/// Değerler: tek tırnaklı dizgi → [String], `[]` → boş liste, `null` → `null`.
/// Başka bir yazım [FormatException] fırlatır (sessizce atlanmaz).
Map<String, Object?> _planPairs(String text) => {
  for (final pair in text.split(', '))
    pair.substring(0, pair.indexOf(':')).trim(): _planValue(
      pair.substring(pair.indexOf(':') + 1).trim(),
    ),
};

Object? _planValue(String text) {
  if (text == 'null') return null;
  if (text == '[]') return <Object?>[];
  if (text.length >= 2 && text.startsWith("'") && text.endsWith("'")) {
    return text.substring(1, text.length - 1);
  }
  throw FormatException('PLAN değeri tanınmadı: $text');
}

/// `docs/PLAN.md` içinde [prefix] ile başlayan tek satır.
String _planLine(String prefix) => readRepoFile(
  'docs/PLAN.md',
).split('\n').singleWhere((line) => line.startsWith(prefix));

/// PLAN §10.4 `AccountDeletionRepository.markDeleted` satırı (adım 1).
String _markDeletedRow() => _planLine(
  '| 1 | `Future<FirestoreResult<void>> markDeleted(String uid)`',
);

/// PLAN §10.4 `MembershipRepository.anonymizeChunk` satırı.
String _anonymizeChunkRow() => _planLine('| `anonymizeChunk` (T-29) |');

/// `FirestoreFields` içindeki tüm sabit değerleri (kaynaktan okunur).
Set<String> _fieldValues() => {
  for (final match
      in RegExp(
        r"static const String \w+ = '([^']+)';",
      ).allMatches(
        readRepoFile(
          'packages/gu_data/lib/src/constants/firestore_fields.dart',
        ),
      ))
    match.group(1)!,
};

void main() {
  group('T-08 · Anonymization · deletedUserName', () {
    test("değer 'Silinmiş kullanıcı'", () {
      expect(Anonymization.deletedUserName, 'Silinmiş kullanıcı');
    });

    test('bileşik (NFC) kod noktalarıyla yazılmıştır — Rules literal eşitliği '
        'bayt düzeyindedir', () {
      // S i l i n m i ş(U+015F) ␠ k u l l a n ı(U+0131) c ı(U+0131)
      expect(Anonymization.deletedUserName.runes.toList(), [
        0x53, 0x69, 0x6C, 0x69, 0x6E, 0x6D, 0x69, 0x15F, //
        0x20, //
        0x6B, 0x75, 0x6C, 0x6C, 0x61, 0x6E, 0x131, 0x63, 0x131,
      ]);
      expect(
        Anonymization.deletedUserName.runes.where(
          (rune) => rune >= 0x300 && rune <= 0x36F,
        ),
        isEmpty,
        reason: 'birleştirici işaret (NFD) içermemeli',
      );
    });

    test('kenar boşluğu yok, tek kelime arası boşluk', () {
      expect(
        Anonymization.deletedUserName,
        Anonymization.deletedUserName.trim(),
      );
      expect(Anonymization.deletedUserName.split(' '), hasLength(2));
    });

    test('ad uzunluk sınırları içinde (Rules name.size() in 2..60)', () {
      expect(
        Anonymization.deletedUserName.length,
        inInclusiveRange(Limits.nameMin, Limits.nameMax),
      );
    });
  });

  group('T-08 · Anonymization · belge paritesi', () {
    test('Rules §3.1 hesap silme dalındaki literal ile aynı', () {
      expect(
        readRepoFile('docs/firestore-rules-spec.md'),
        contains("name=='${Anonymization.deletedUserName}'"),
      );
    });

    test('PLAN M14 başvuran anlık görüntüsü literal ile aynı', () {
      expect(
        readRepoFile('docs/PLAN.md'),
        contains("`applicant.name == '${Anonymization.deletedUserName}'`"),
      );
    });

    test('domain-model §11 adım 3 literal ile aynı', () {
      expect(
        readRepoFile('docs/domain-model.md'),
        contains('`name="${Anonymization.deletedUserName}"`'),
      );
    });

    test('PLAN §9.1 sabit tanımı ile aynı', () {
      expect(
        readRepoFile('docs/PLAN.md'),
        contains("`deletedUserName = '${Anonymization.deletedUserName}'`"),
      );
    });
  });

  group('T-08 · Anonymization.userPayload', () {
    test('on iki anahtar, sırayla: kişisel alanlar + soft delete alanları', () {
      expect(Anonymization.userPayload('u_ayse').keys.toList(), [
        'name',
        'nameLower',
        'bio',
        'interests',
        'avatarPath',
        'department',
        'year',
        'status',
        'isDeleted',
        'deletedAt',
        'deletedBy',
        'updatedAt',
      ]);
    });

    test('name silinmiş kullanıcı adıdır', () {
      expect(
        Anonymization.userPayload('u_ayse')['name'],
        Anonymization.deletedUserName,
      );
    });

    test('nameLower adın küçük harfli kopyasıdır (yerel ayardan bağımsız)', () {
      final nameLower = Anonymization.userPayload('u_ayse')['nameLower'];

      expect(nameLower, 'silinmiş kullanıcı');
      expect(nameLower, Anonymization.deletedUserName.toLowerCase());
      // Türkçe kuralın ayrıştığı tek harfler I ve İ'dir; adda ikisi de yok,
      // bu yüzden ASCII küçültme ile Türkçe küçültme aynı sonucu verir.
      expect(Anonymization.deletedUserName, isNot(contains('I')));
      expect(Anonymization.deletedUserName, isNot(contains('İ')));
      expect(
        (nameLower! as String).length,
        inInclusiveRange(Limits.nameMin, Limits.nameMax),
      );
    });

    test("bio boş dizgi, interests boş liste (Rules: bio=='' && "
        'interests==[])', () {
      final payload = Anonymization.userPayload('u_ayse');

      expect(payload['bio'], '');
      expect(payload['interests'], isA<List<String>>());
      expect(payload['interests'], isEmpty);
    });

    test('avatarPath, department ve year açıkça null yazılır (anahtar yükte '
        'var)', () {
      final payload = Anonymization.userPayload('u_ayse');

      for (final key in ['avatarPath', 'department', 'year']) {
        expect(payload.containsKey(key), isTrue, reason: key);
        expect(payload[key], isNull, reason: key);
      }
    });

    test("status 'deleted'", () {
      expect(Anonymization.userPayload('u_ayse')['status'], 'deleted');
    });

    test(
      'soft delete alanları SoftDelete.payload(actorId: uid) ile aynıdır',
      () {
        final payload = Anonymization.userPayload('u_p_c01');
        final softDelete = SoftDelete.payload(actorId: 'u_p_c01');

        expect(payload.keys.toSet(), containsAll(SoftDelete.affectedKeys));
        for (final key in SoftDelete.affectedKeys) {
          expect(payload[key], softDelete[key], reason: key);
        }
        expect(payload['isDeleted'], isTrue);
      },
    );

    test('silen kişi hesabın sahibidir: deletedBy == uid', () {
      expect(Anonymization.userPayload('u_ayse')['deletedBy'], 'u_ayse');
      expect(Anonymization.userPayload('u_p_c01')['deletedBy'], 'u_p_c01');
    });

    test('deletedAt ve updatedAt sunucu zaman damgası nöbetçisidir; başka '
        'alan nöbetçi taşımaz', () {
      final payload = Anonymization.userPayload('u_ayse');

      expect(payload['deletedAt'], _isServerTimestamp);
      expect(payload['updatedAt'], _isServerTimestamp);
      expect(
        {
          for (final entry in payload.entries)
            if (entry.value is FieldValue) entry.key,
        },
        {'deletedAt', 'updatedAt'},
      );
    });

    test('avatarSeed, staff, profileComplete, suspendReason ve createdAt '
        'alanlarına dokunmaz', () {
      final payload = Anonymization.userPayload('u_ayse');

      for (final key in [
        'avatarSeed',
        'staff',
        'profileComplete',
        'suspendReason',
        'createdAt',
        'createdBy',
      ]) {
        expect(payload.containsKey(key), isFalse, reason: key);
      }
    });

    test('e-posta taşımaz (users belgesinde e-posta yok, D-29)', () {
      final payload = Anonymization.userPayload('u_ayse');

      expect(payload.containsKey('email'), isFalse);
      expect(payload.containsKey('emailLower'), isFalse);
    });

    test('boş uid reddedilir', () {
      expect(
        () => Anonymization.userPayload(''),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'actorId')),
      );
    });

    test('uid yalnızca deletedBy alanına yazılır', () {
      final payload = Anonymization.userPayload('u_özel_kimlik');

      expect(
        {
          for (final entry in payload.entries)
            if (entry.value == 'u_özel_kimlik') entry.key,
        },
        {'deletedBy'},
      );
    });

    test('her çağrı yeni bir map ve yeni bir liste döner', () {
      final first = Anonymization.userPayload('u1');
      final second = Anonymization.userPayload('u2');

      expect(identical(first, second), isFalse);
      expect(identical(first['interests'], second['interests']), isFalse);
      first['name'] = 'değişti';
      (first['interests']! as List<String>).add('i01');
      expect(second['name'], Anonymization.deletedUserName);
      expect(second['interests'], isEmpty);
      expect(Anonymization.userPayload('u1')['interests'], isEmpty);
    });

    test('PLAN §10.4 markDeleted satırındaki users yükü ile birebir', () {
      final span = codeSpans(
        _markDeletedRow(),
      ).singleWhere((code) => code.startsWith("name:'"));
      final payload = Anonymization.userPayload('u_ayse');
      final personal = {
        for (final entry in payload.entries)
          if (!SoftDelete.affectedKeys.contains(entry.key))
            entry.key: entry.value,
      };

      expect(personal, _planPairs(span));
      expect(personal.keys.toList(), _planPairs(span).keys.toList());
      expect(
        _markDeletedRow(),
        contains('` + `SoftDelete.payload(actorId: uid)`)'),
      );
    });

    test('Rules §3.1 hesap silme dalının koşullarını sağlar', () {
      final payload = Anonymization.userPayload('u_ayse');
      final rules = readRepoFile('docs/firestore-rules-spec.md');

      expect(
        rules,
        contains(
          "request.resource.data.status=='${payload['status']}' && "
          "name=='${payload['name']}' && bio=='${payload['bio']}' && "
          'interests==[]',
        ),
      );
    });

    test('domain-model §11 adım 3 alan listesi ile aynı', () {
      final step = readRepoFile('docs/domain-model.md')
          .split('\n')
          .singleWhere(
            (line) => line.startsWith('3. **Tek batch/işlem dizisi'),
          );

      expect(
        step,
        contains(
          '`users/{uid}`: `name="Silinmiş kullanıcı"`, `bio=\'\'`, '
          '`interests=[]`, `avatarPath=null`, `department/year=null`, '
          "`status='deleted'`, soft-delete alanları",
        ),
      );
    });
  });

  group('T-08 · Anonymization.accountPayload', () {
    test('üç anahtar, sırayla: email, emailLower, fcmTokens', () {
      expect(Anonymization.accountPayload().keys.toList(), [
        'email',
        'emailLower',
        'fcmTokens',
      ]);
    });

    test('e-posta alanları boş dizgi, fcmTokens boş liste', () {
      final payload = Anonymization.accountPayload();

      expect(payload['email'], '');
      expect(payload['emailLower'], '');
      expect(payload['fcmTokens'], isA<List<Object?>>());
      expect(payload['fcmTokens'], isEmpty);
    });

    test('soft delete alanı ya da nöbetçi değer taşımaz', () {
      final payload = Anonymization.accountPayload();

      expect(
        payload.keys.toSet().intersection(SoftDelete.affectedKeys),
        isEmpty,
      );
      expect(payload.values, everyElement(isNot(isA<FieldValue>())));
    });

    test('her çağrı yeni bir map ve yeni bir liste döner', () {
      final first = Anonymization.accountPayload();
      final second = Anonymization.accountPayload();

      expect(identical(first, second), isFalse);
      expect(identical(first['fcmTokens'], second['fcmTokens']), isFalse);
      (first['fcmTokens']! as List<Object?>).add('jeton');
      first['email'] = 'a@gumushane.edu.tr';
      expect(second['fcmTokens'], isEmpty);
      expect(second['email'], '');
    });

    test('PLAN §10.4 markDeleted satırındaki private/account yükü ile '
        'birebir', () {
      final span = codeSpans(
        _markDeletedRow(),
      ).singleWhere((code) => code.startsWith("email:'"));

      expect(Anonymization.accountPayload(), _planPairs(span));
      expect(
        _markDeletedRow(),
        contains('`users/{uid}/private/account` update (`$span`)'),
      );
    });

    test('domain-model §11 adım 3 ile aynı', () {
      expect(
        readRepoFile('docs/domain-model.md'),
        contains("`private/account`: `email/emailLower=''`, `fcmTokens=[]`"),
      );
    });
  });

  group('T-08 · Anonymization.contactPayload', () {
    test('iki anahtar, sırayla: email, emailLower', () {
      expect(Anonymization.contactPayload().keys.toList(), [
        'email',
        'emailLower',
      ]);
    });

    test('iki alan da boş dizgi', () {
      expect(Anonymization.contactPayload(), {'email': '', 'emailLower': ''});
    });

    test('accountPayload ile aynı e-posta değerleri; fcmTokens yok', () {
      final account = Anonymization.accountPayload();
      final contact = Anonymization.contactPayload();

      expect(contact['email'], account['email']);
      expect(contact['emailLower'], account['emailLower']);
      expect(contact.containsKey('fcmTokens'), isFalse);
    });

    test('her çağrı yeni bir map döner', () {
      final first = Anonymization.contactPayload();
      final second = Anonymization.contactPayload();

      expect(identical(first, second), isFalse);
      first['email'] = 'a@gumushane.edu.tr';
      expect(second['email'], '');
    });

    test('PLAN §10.4 anonymizeChunk satırındaki private/contact yükü ile '
        'birebir', () {
      final span = codeSpans(
        _anonymizeChunkRow(),
      ).singleWhere((code) => code.startsWith("email:'"));

      expect(Anonymization.contactPayload(), _planPairs(span));
      expect(_anonymizeChunkRow(), contains('`private/contact` `$span`'));
    });

    test(
      "Rules §3.4 private/contact güncelleme koşulunu sağlar (email=='')",
      () {
        expect(
          readRepoFile('docs/firestore-rules-spec.md'),
          contains(
            '**U:** yalnızca anonimleştirme '
            "(`email=='${Anonymization.contactPayload()['email']}'`)",
          ),
        );
      },
    );
  });

  group('T-08 · Anonymization.applicantPayload', () {
    Map<String, Object?> applicant() =>
        Anonymization.applicantPayload()['applicant']! as Map<String, Object?>;

    test('tek anahtar: applicant (alan bütünüyle değiştirilir)', () {
      expect(Anonymization.applicantPayload().keys.toList(), ['applicant']);
      expect(
        Anonymization.applicantPayload()['applicant'],
        isA<Map<String, Object?>>(),
      );
    });

    test('anlık görüntü: dört anahtar, sırayla', () {
      expect(applicant().keys.toList(), [
        'name',
        'department',
        'year',
        'avatarSeed',
      ]);
    });

    test('name silinmiş kullanıcı adıdır (Rules M14)', () {
      expect(applicant()['name'], Anonymization.deletedUserName);
    });

    test('department ve year açıkça null yazılır (Rules M14)', () {
      for (final key in ['department', 'year']) {
        expect(applicant().containsKey(key), isTrue, reason: key);
        expect(applicant()[key], isNull, reason: key);
      }
    });

    test("avatarSeed 'deleted' — boş değildir (model alanı zorunlu)", () {
      expect(applicant()['avatarSeed'], 'deleted');
      expect(applicant()['avatarSeed'], isNot(isEmpty));
    });

    test('anlık görüntü anahtarları FirestoreFields noktalı yollarıyla '
        'örtüşür', () {
      expect(
        {for (final key in applicant().keys) 'applicant.$key'},
        {
          FirestoreFields.applicantName,
          FirestoreFields.applicantDepartment,
          FirestoreFields.applicantYear,
          FirestoreFields.applicantAvatarSeed,
        },
      );
    });

    test(
      'e-posta, durum ve sayaç taşımaz (çağıran aynı güncellemede ekler)',
      () {
        final payload = Anonymization.applicantPayload();

        for (final key in ['status', 'memberCount', 'email', 'emailLower']) {
          expect(payload.containsKey(key), isFalse, reason: key);
          expect(applicant().containsKey(key), isFalse, reason: key);
        }
        expect(payload.values, everyElement(isNot(isA<FieldValue>())));
        expect(applicant().values, everyElement(isNot(isA<FieldValue>())));
      },
    );

    test('her çağrı yeni bir map ve yeni bir anlık görüntü döner', () {
      final first = Anonymization.applicantPayload();
      final second = Anonymization.applicantPayload();

      expect(identical(first, second), isFalse);
      expect(identical(first['applicant'], second['applicant']), isFalse);
      (first['applicant']! as Map<String, Object?>)['name'] = 'değişti';
      expect(
        (second['applicant']! as Map<String, Object?>)['name'],
        Anonymization.deletedUserName,
      );
    });

    test(
      'PLAN §10.4 anonymizeChunk satırındaki applicant yükü ile birebir',
      () {
        final span = codeSpans(
          _anonymizeChunkRow(),
        ).singleWhere((code) => code.startsWith('applicant: {'));
        final inner = span.substring(
          'applicant: {'.length,
          span.length - '}'.length,
        );

        expect(applicant(), _planPairs(inner));
        expect(applicant().keys.toList(), _planPairs(inner).keys.toList());
      },
    );

    test('PLAN §9.6.4 model notu aynı yükü tanımlar: anlık görüntü bütünüyle '
        "değişir, avatarSeed 'deleted' (CD-129 — §10.4 ile çelişki kapalı)", () {
      final note = _planLine(
        '`MembershipApplicantModel` (`models/membership_applicant_model.dart`)',
      );

      expect(note, contains('anlık görüntü **bütünüyle** değiştirilir'));
      expect(note, contains('`name = Anonymization.deletedUserName`'));
      expect(note, contains('`department = year = null`'));
      expect(
        note,
        contains("`avatarSeed = '${applicant()['avatarSeed']}'`"),
      );
      // Eski, §10.4 ile çelişen cümle geri gelmemeli.
      expect(note, isNot(contains('`avatarSeed` kalır')));
      expect(note, contains('CD-129'));
    });

    test('users.avatarSeed ile applicant.avatarSeed kuralı bilinçli olarak '
        'farklıdır: kullanıcı belgesinde tohuma dokunulmaz, anlık görüntüde '
        'sabitlenir', () {
      final user = Anonymization.userPayload('u_ayse');
      final step = readRepoFile('docs/domain-model.md')
          .split('\n')
          .singleWhere(
            (line) => line.startsWith('3. **Tek batch/işlem dizisi'),
          );

      // Kullanıcı belgesi: tohum yükte yok (domain-model §11 alan listesi ve
      // PLAN §10.4 markDeleted satırı da anmaz).
      expect(user.containsKey('avatarSeed'), isFalse);
      expect(step, isNot(contains('avatarSeed')));
      expect(_markDeletedRow(), isNot(contains('avatarSeed')));
      // Başvuran anlık görüntüsü: boşaltılır, zorunlu alan sabit değer alır.
      expect(applicant()['avatarSeed'], 'deleted');
      expect(step, contains('`applicant` snapshot boşaltılır'));
      expect(
        _planLine(
          '`MembershipApplicantModel` '
          '(`models/membership_applicant_model.dart`)',
        ),
        contains("`users.avatarSeed`'e ise dokunulmaz"),
      );
    });

    test('PLAN M14 Rules koşullarını sağlar', () {
      final plan = readRepoFile('docs/PLAN.md');

      expect(
        plan,
        contains(
          "`applicant.name == '${applicant()['name']}'`, "
          '`applicant.department == null`, `applicant.year == null`',
        ),
      );
    });
  });

  group('T-08 · Anonymization · yükler arası sözleşme', () {
    final payloads = <String, Map<String, Object?>>{
      'userPayload': Anonymization.userPayload('u_ayse'),
      'accountPayload': Anonymization.accountPayload(),
      'contactPayload': Anonymization.contactPayload(),
      'applicantPayload': Anonymization.applicantPayload(),
    };

    test('her üst düzey anahtar bir FirestoreFields sabitidir (noktalı yol '
        'değil)', () {
      final fields = _fieldValues();

      for (final MapEntry(key: name, value: payload) in payloads.entries) {
        for (final key in payload.keys) {
          expect(fields, contains(key), reason: '$name.$key');
          expect(key, isNot(contains('.')), reason: '$name.$key');
        }
      }
    });

    test('hiçbir yük istemci saati (DateTime / Timestamp) taşımaz', () {
      for (final MapEntry(key: name, value: payload) in payloads.entries) {
        expect(
          payload.values,
          everyElement(isNot(anyOf(isA<DateTime>(), isA<Timestamp>()))),
          reason: name,
        );
      }
    });

    test('kişisel veri kalmaz: dizgi değerler yalnızca sabit literal ya da '
        'uid', () {
      const allowed = {
        'Silinmiş kullanıcı',
        'silinmiş kullanıcı',
        '',
        'deleted',
      };
      final strings = <String>[
        for (final payload in payloads.values)
          for (final value in payload.values)
            if (value is String)
              value
            else if (value is Map<String, Object?>)
              ...value.values.whereType<String>(),
      ];

      expect(
        strings.where((value) => value != 'u_ayse'),
        everyElement(isIn(allowed)),
      );
    });

    test('kaynak: FieldValue ve harf dönüşümü yok; soft delete alanları '
        'SoftDelete üzerinden', () {
      final source = readRepoFile(
        'packages/gu_data/lib/src/constants/anonymization.dart',
      );
      final imports = [
        for (final line in source.split('\n'))
          if (line.startsWith('import ')) line,
      ];

      expect(imports, [
        "import 'package:gu_data/src/constants/firestore_fields.dart';",
        "import 'package:gu_data/src/core/soft_delete.dart';",
      ]);
      expect(source, isNot(contains('FieldValue')));
      expect(source, isNot(contains('toLowerCase')));
      expect(source, contains('...SoftDelete.payload(actorId: uid)'));
    });

    test('açık üyeler: deletedUserName + dört yük (PLAN §9.5)', () {
      final source = readRepoFile(
        'packages/gu_data/lib/src/constants/anonymization.dart',
      );
      final members = [
        for (final match in RegExp(
          r'^  static (?:const )?[\w<>, ?]+ (\w+)(?: =|\()',
          multiLine: true,
        ).allMatches(source))
          if (!match.group(1)!.startsWith('_')) match.group(1)!,
      ];

      expect(members, [
        'deletedUserName',
        'userPayload',
        'accountPayload',
        'contactPayload',
        'applicantPayload',
      ]);
      final section = _planLine('- `Anonymization.deletedUserName = ');
      expect(
        codeSpans(section).where((code) => code.startsWith('Anonymization.')),
        [
          "Anonymization.deletedUserName = 'Silinmiş kullanıcı'",
          'Anonymization.userPayload(uid)',
          'Anonymization.accountPayload()',
          'Anonymization.contactPayload()',
          'Anonymization.applicantPayload()',
        ],
      );
    });
  });
}
