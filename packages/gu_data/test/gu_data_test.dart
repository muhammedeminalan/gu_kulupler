// T-08 · gu_data barrel: `lib/src` altındaki her dosya tek, alfabetik bir
// `export` ile dışa açılır; barrel Firebase SDK tipi taşımaz (B08); paket
// dışı ve testler `src/` yolunu içe aktarmaz. Ayrıca çekirdek parçaların
// barrel üzerinden birlikte çalıştığı uçtan uca sözleşmeler (saat → sayaç
// kimliği, kod üretici → QR, rol kodu → erişim kipi, sayfalama).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import 'fakes/fake_app_clock.dart';
import 'fakes/fake_ticket_code_generator.dart';
import 'helpers/repo_sources.dart';

const String _packageRoot = 'packages/gu_data';

/// [relativeDir] altındaki `.dart` dosyaları, depo köküne göreli yollarıyla.
List<String> _dartFiles(String relativeDir) {
  final dir = Directory('$repoRoot/$relativeDir');
  if (!dir.existsSync()) return const [];
  return [
    for (final entity in dir.listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.dart'))
        entity.path.substring(repoRoot.length + 1),
  ]..sort();
}

/// Barrel dosyasının yönerge satırları (yorum ve boş satır hariç).
List<String> _barrelDirectives() => [
  for (final line in readRepoFile(
    '$_packageRoot/lib/gu_data.dart',
  ).split('\n'))
    if (line.trim().isNotEmpty && !line.trimLeft().startsWith('//')) line,
];

/// Barrel'daki `export '…';` hedefleri, yazıldıkları sırayla.
List<String> _barrelExports() => [
  for (final line in _barrelDirectives())
    if (line.startsWith('export ')) line.split("'")[1],
];

void main() {
  group('T-08 · gu_data barrel · export listesi', () {
    test('lib/src altındaki her kaynak dosya dışa aktarılır (eksik ve fazla '
        'yok)', () {
      final sources = [
        for (final path in _dartFiles('$_packageRoot/lib/src'))
          if (!path.endsWith('.g.dart'))
            path.substring('$_packageRoot/lib/'.length),
      ];

      expect(sources, isNotEmpty);
      expect(_barrelExports().toSet(), sources.toSet());
    });

    test('her dosya tam bir kez dışa aktarılır', () {
      final exports = _barrelExports();

      expect(exports.toSet(), hasLength(exports.length));
    });

    test('alfabetik sıradadır', () {
      final exports = _barrelExports();

      expect(exports, [...exports]..sort());
    });

    test('yalnızca library + export yönergeleri içerir; show / hide ve '
        'import yok', () {
      final directives = _barrelDirectives();

      expect(directives.first, 'library;');
      expect(
        directives.skip(1),
        everyElement(matches(RegExp(r"^export 'src/[a-z0-9_/]+\.dart';$"))),
      );
    });

    test('Firebase SDK paketini dışa aktarmaz (B08)', () {
      final barrel = readRepoFile('$_packageRoot/lib/gu_data.dart');

      expect(barrel, isNot(contains('package:cloud_firestore')));
      expect(barrel, isNot(contains('package:firebase_')));
    });

    test('üretilen dosya (*.g.dart) dışa aktarılmaz', () {
      expect(_barrelExports(), everyElement(isNot(endsWith('.g.dart'))));
    });

    test('dışa aktarılan her dosya vardır', () {
      for (final export in _barrelExports()) {
        expect(
          File('$repoRoot/$_packageRoot/lib/$export').existsSync(),
          isTrue,
          reason: export,
        );
      }
    });
  });

  group('T-08 · gu_data barrel · src yolu kullanımı', () {
    test('paket testleri src yolunu içe aktarmaz (barrel yeterli)', () {
      final offenders = [
        for (final path in _dartFiles('$_packageRoot/test'))
          for (final line in readRepoFile(path).split('\n'))
            if (line.startsWith("import 'package:gu_data/src/")) '$path: $line',
      ];

      expect(offenders, isEmpty);
    });

    test('uygulama ve kök testleri src yolunu içe aktarmaz', () {
      final offenders = [
        for (final dir in ['lib', 'test', 'integration_test'])
          for (final path in _dartFiles(dir))
            for (final line in readRepoFile(path).split('\n'))
              if (line.startsWith("import 'package:gu_data/src/"))
                '$path: $line',
      ];

      expect(_dartFiles('lib'), isNotEmpty);
      expect(offenders, isEmpty);
    });

    test(
      'lib/src dosyaları kendi barrel dosyasını içe aktarmaz (döngü yok)',
      () {
        final offenders = [
          for (final path in _dartFiles('$_packageRoot/lib/src'))
            if (readRepoFile(path).contains('package:gu_data/gu_data.dart'))
              path,
        ];

        expect(offenders, isEmpty);
      },
    );

    test('lib/src dosyaları Flutter arayüz kitaplığı içe aktarmaz (B03)', () {
      final offenders = [
        for (final path in _dartFiles('$_packageRoot/lib/src'))
          for (final line in readRepoFile(path).split('\n'))
            if (RegExp(
              r"^import 'package:flutter/(material|widgets|cupertino|rendering|painting)\.dart'",
            ).hasMatch(line))
              '$path: $line',
      ];

      expect(offenders, isEmpty);
    });
  });

  group('T-08 · gu_data barrel · her dosyadan bir ad erişilebilir', () {
    test('sabitler', () {
      expect(Anonymization.deletedUserName, isNotEmpty);
      expect(EmailDomainPolicy.allowedDomains, hasLength(2));
      expect(FirestoreCollections.users, 'users');
      expect(FirestoreFields.isDeleted, 'isDeleted');
      expect(FirestoreIds.membership('c01', 'u1'), 'c01_u1');
      expect(Limits.pageSize, 20);
      expect(RoleCodes.president, 'president');
      expect(MembershipStatusCodes.active, 'active');
      expect(StaticTables.categories, hasLength(8));
    });

    test('çekirdek', () {
      expect(const SystemAppClock(), isA<AppClock>());
      expect(AuthError.values, hasLength(16));
      expect(BaseFieldsPayload.update().keys, [FirestoreFields.updatedAt]);
      expect(
        const ConflictException(FirestoreRuleCode.capacityFull),
        isA<Exception>(),
      );
      expect(const FirebaseSuccess<int, FirestoreError>(1).isSuccess, isTrue);
      expect(FirestoreError.values, hasLength(16));
      expect(FirestoreRuleCode.values, hasLength(12));
      expect(
        const FirestoreFailureDetail(FirestoreRuleCode.capacityFull).code,
        FirestoreRuleCode.capacityFull,
      );
      expect(const PageRequest().after, isA<PageCursor?>());
      expect(const PageResult<int>(items: [1]).hasMore, isFalse);
      expect(RolePolicy.can(ClubPermission.viewPublic, null), isTrue);
      expect(ClubAccess.values, hasLength(7));
      expect(SoftDelete.affectedKeys, hasLength(4));
      expect(StorageError.values, hasLength(10));
    });

    test('modeller', () {
      expect(ClubRole.values, hasLength(4));
      expect(
        const CategoryModel(id: 'k01', icon: 'cpu'),
        StaticTables.categories.first,
      );
      expect(
        const DepartmentModel(id: 'd01', facultyId: 'f1'),
        StaticTables.departments.first,
      );
      expect(StaticTables.eventTypes.first, EventType.training);
      expect(StaticTables.years.first, YearLevel.prep);
      expect(const FacultyModel(id: 'f1'), StaticTables.faculties.first);
      expect(
        const InterestModel(id: 'i01', categoryId: 'k01'),
        StaticTables.interests.first,
      );
      expect(const PlaceModel(id: 'pl01'), StaticTables.places.first);
    });

    test('araçlar', () {
      expect(
        EmailDomainValidator.isAllowedDomain('a@gumushane.edu.tr'),
        isTrue,
      );
      expect(const TimestampConverter().fromJson(null), isNull);
      expect(
        const RequiredTimestampConverter().fromJson('2026-10-08T12:00:00Z'),
        DateTime.utc(2026, 10, 8, 12),
      );
      expect(TicketCodeGenerator.alphabet, hasLength(32));
      expect(SecureTicketCodeGenerator(), isA<TicketCodeGenerator>());
    });
  });

  group('T-08 · gu_data barrel · const kurucular çalışma zamanında', () {
    // DI kaydı gibi const olmayan bağlamlarda da kurulabilmeli; const
    // değerlendirme çalışma zamanında kurucuyu hiç çağırmaz.
    test('SystemAppClock', () {
      const create = SystemAppClock.new;
      final clock = create();

      expect(clock, isA<AppClock>());
      expect(clock.nowUtc().isUtc, isTrue);
      expect(
        clock.istanbulDayKey(DateTime.utc(2026, 10, 8, 21)),
        const SystemAppClock().istanbulDayKey(DateTime.utc(2026, 10, 8, 21)),
      );
    });

    test('TimestampConverter ve RequiredTimestampConverter', () {
      const createNullable = TimestampConverter.new;
      const createRequired = RequiredTimestampConverter.new;
      final instant = DateTime.utc(2026, 10, 8, 20, 15, 1);

      expect(createNullable().fromJson(null), isNull);
      expect(
        createNullable().fromJson(createNullable().toJson(instant)),
        instant,
      );
      expect(
        createRequired().fromJson(createRequired().toJson(instant)),
        instant,
      );
    });
  });

  group('T-08 · gu_data · parçalar arası sözleşme', () {
    test('duyuru sayacı kimliği: AppClock Istanbul günü + FirestoreIds', () {
      final clock = FakeAppClock(DateTime.utc(2026, 10, 8, 20, 59, 59));

      expect(
        FirestoreIds.announcementCounter(
          'c01',
          clock.istanbulDayKey(clock.nowUtc()),
        ),
        'c01_20261008',
      );

      clock.advance(const Duration(seconds: 1));
      expect(
        FirestoreIds.announcementCounter(
          'c01',
          clock.istanbulDayKey(clock.nowUtc()),
        ),
        'c01_20261009',
        reason: 'Istanbul gece yarısı = UTC 21:00 (Limits.istanbulUtcOffset)',
      );
    });

    test('sayaç belge kimliği ile day alanı aynı günü gösterir ve '
        'Limits.isoDayPattern ile uyumludur', () {
      const clock = SystemAppClock();

      for (final instant in [
        DateTime.utc(2026, 10, 8, 20, 59, 59, 999),
        DateTime.utc(2026, 10, 8, 21),
        DateTime.utc(2026, 12, 31, 21),
        DateTime.utc(2028, 2, 28, 21),
      ]) {
        final day = clock.istanbulDay(instant);
        final id = FirestoreIds.announcementCounter(
          'c01',
          clock.istanbulDayKey(instant),
        );

        expect(RegExp(Limits.isoDayPattern).hasMatch(day), isTrue);
        expect(id, 'c01_${day.replaceAll('-', '')}');
        expect(
          clock
              .istanbulStartOfDay(instant)
              .add(Limits.istanbulUtcOffset)
              .toIso8601String(),
          startsWith(day),
        );
      }
    });

    test('Limits.foundedMax saatten okunur (AppClock ↔ Limits)', () {
      final clock = FakeAppClock(DateTime.utc(2026, 12, 31, 23, 59, 59));
      expect(Limits.foundedMax(clock), 2026);

      clock.advance(const Duration(seconds: 1));
      expect(Limits.foundedMax(clock), 2027);
      expect(Limits.foundedMin, lessThan(Limits.foundedMax(clock)));
    });

    test('üretilen bilet kodu QR yükünde gidiş-dönüş yapar (gerçek ve sahte '
        'üretici)', () {
      final generators = <TicketCodeGenerator>[
        SecureTicketCodeGenerator(),
        FakeTicketCodeGenerator(),
      ];

      for (final generator in generators) {
        for (var i = 0; i < 50; i++) {
          final code = generator.ticketCode();
          final parsed = FirestoreIds.parseTicketQr(
            FirestoreIds.ticketQrPayload('e03', code),
          );

          expect(parsed, (eventId: 'e03', code: code));
          expect(RegExp(FirestoreIds.ticketCodePattern).hasMatch(code), isTrue);
        }
      }
    });

    test(
      'destek numarası bilet kodu yerine geçmez (QR ayrıştırıcı reddeder)',
      () {
        final generators = <TicketCodeGenerator>[
          SecureTicketCodeGenerator(),
          FakeTicketCodeGenerator(),
        ];

        for (final generator in generators) {
          final ticketNo = generator.supportTicketNo();

          expect(
            RegExp(FirestoreIds.supportTicketNoPattern).hasMatch(ticketNo),
            isTrue,
          );
          expect(
            FirestoreIds.parseTicketQr(
              FirestoreIds.ticketQrPayload('e03', ticketNo),
            ),
            isNull,
          );
        }
      },
    );

    test('üyelik belgesi dizgileri → rol → erişim kipi → izin', () {
      ClubAccess access(String status, String role) => RolePolicy.accessOf(
        isSuper: false,
        status: MembershipStatus.fromJson(status),
        role: ClubRole.fromJson(role),
      );

      expect(
        access(MembershipStatusCodes.active, RoleCodes.member),
        ClubAccess.member,
      );
      expect(
        access(MembershipStatusCodes.active, RoleCodes.board),
        ClubAccess.manager,
      );
      expect(
        access(MembershipStatusCodes.active, RoleCodes.president),
        ClubAccess.manager,
      );
      expect(
        access(MembershipStatusCodes.active, RoleCodes.advisor),
        ClubAccess.advisor,
      );
      expect(
        access(MembershipStatusCodes.pending, RoleCodes.member),
        ClubAccess.pending,
      );
      expect(
        access(MembershipStatusCodes.removed, RoleCodes.board),
        ClubAccess.visitor,
      );
      expect(
        RolePolicy.can(
          ClubPermission.createPost,
          ClubRole.fromJson(RoleCodes.board),
        ),
        isTrue,
      );
      expect(
        RolePolicy.can(
          ClubPermission.createPost,
          ClubRole.fromJson(RoleCodes.member),
        ),
        isFalse,
      );
    });

    test(
      'süper admin kodu kulüp rolü değildir; yetkisi isSuper ile verilir',
      () {
        expect(
          () => ClubRole.fromJson(RoleCodes.superadmin),
          throwsArgumentError,
        );
        expect(
          ClubRole.values.map((role) => role.json),
          isNot(contains(RoleCodes.superadmin)),
        );
        expect(RolePolicy.accessOf(isSuper: true), ClubAccess.superAdmin);
        expect(
          RolePolicy.can(ClubPermission.createClub, null, isSuper: true),
          isTrue,
        );
        expect(RolePolicy.can(ClubPermission.createClub, null), isFalse);
      },
    );

    test('kayıt e-postası: biçim + izinli alan adı birlikte aranır', () {
      bool accepted(String email) =>
          EmailDomainValidator.isWellFormed(email) &&
          EmailDomainValidator.isAllowedDomain(email);

      for (final domain in EmailDomainPolicy.allowedDomains) {
        expect(accepted('ayse.yilmaz@$domain'), isTrue, reason: domain);
        expect(accepted('@$domain'), isFalse, reason: domain);
        expect(accepted('a@b@$domain'), isFalse, reason: domain);
        expect(accepted('a@x.$domain'), isFalse, reason: domain);
      }
      expect(accepted('ayse@gmail.com'), isFalse);
    });

    test('silme yükleri yalnızca FirestoreFields ortak alanlarına dokunur', () {
      const base = {
        FirestoreFields.createdAt,
        FirestoreFields.updatedAt,
        FirestoreFields.createdBy,
        FirestoreFields.isDeleted,
        FirestoreFields.deletedAt,
        FirestoreFields.deletedBy,
      };

      expect(base, containsAll(SoftDelete.affectedKeys));
      expect(base, containsAll(SoftDelete.payload(actorId: 'u1').keys));
      expect(base, containsAll(SoftDelete.restorePayload().keys));
      expect(
        BaseFieldsPayload.create(createdBy: 'u1').keys.toSet(),
        base,
      );
    });

    test('iş kuralı reddi sonuç tipiyle taşınır (ConflictException → '
        'FirestoreResult)', () {
      final retryAfter = DateTime.utc(2026, 10, 15, 12);
      final thrown = ConflictException(
        FirestoreRuleCode.retryCooldown,
        detail: FirestoreFailureDetail(
          FirestoreRuleCode.retryCooldown,
          retryAfter: retryAfter,
        ),
      );
      final FirestoreResult<void> result = FirebaseFailure(
        FirestoreError.ruleViolation,
        detail: thrown.detail,
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull, FirestoreError.ruleViolation);
      final detail = switch (result) {
        FirebaseFailure(:final FirestoreFailureDetail detail) => detail,
        _ => null,
      };
      expect(detail?.code, thrown.code);
      expect(detail?.retryAfter, retryAfter);
    });

    test('sayfalama: varsayılan istek Limits.pageSize; imleçsiz sonuç son '
        'sayfadır', () {
      const request = PageRequest();
      final page = PageResult<String>(
        items: List.generate(request.limit - 1, (index) => 'p$index'),
      );

      expect(request.limit, Limits.pageSize);
      expect(request.after, isNull);
      expect(page.items.length, lessThan(request.limit));
      expect(page.hasMore, isFalse);
    });

    test('anket seçenek kimlikleri Limits.pollOptionsMax ile sınırlıdır', () {
      expect(
        [
          for (var i = 0; i < Limits.pollOptionsMax; i++)
            FirestoreIds.pollOption(i),
        ],
        ['o1', 'o2', 'o3', 'o4'],
      );
      expect(
        () => FirestoreIds.pollOption(Limits.pollOptionsMax),
        throwsRangeError,
      );
    });

    test('ilgi alanı sınırı statik tabloya sığar', () {
      expect(
        Limits.interestsMax,
        lessThanOrEqualTo(StaticTables.interests.length),
      );
      expect(Limits.interestsMin, greaterThan(0));
      expect(
        StaticTables.interests.map((interest) => interest.categoryId).toSet(),
        everyElement(isIn(StaticTables.categoryIds)),
      );
    });
  });
}
