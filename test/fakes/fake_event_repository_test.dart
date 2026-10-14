// T-22 · FakeEventRepository sözleşmesi (PLAN §16.3): `events`,
// `membersUpcomingQueries`, `created`, `patches`; gerçek repository + Security
// Rules sonuçlarını izler (docs/plans/T-22.md §6.2, §6.6, §6.8).
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';

import '../fixtures/demo_data.dart';
import '../fixtures/event_model_fixtures.dart';
import '../helpers/fake_app_clock.dart';
import 'fake_event_repository.dart';
import 'fake_rsvp_repository.dart';
import 'register_fakes.dart';

const String _board = 'u_p_c01';

void main() {
  late FakeAppClock clock;
  late FakeEventRepository fake;

  final draft = EventDraft(
    title: 'Flutter atölyesi',
    type: EventType.training,
    startsAt: DateTime.utc(2026, 10, 20, 15),
    endsAt: DateTime.utc(2026, 10, 20, 17),
    capacity: 2,
    coverPalette: ClubPalette.red,
    coverPattern: ClubPattern.dots,
  );

  setUp(() {
    // Demo verinin "bugün"ü: e01 / e03 yaklaşan, e19 geçmiş.
    clock = FakeAppClock(DemoDataFixture.today);
    fake = FakeEventRepository(clock);
    EventModelFixtures.all().forEach(fake.put);
  });

  FirestoreRuleCode? codeOf(FirestoreResult<Object?> result) =>
      switch (result) {
        FirebaseFailure(:final FirestoreFailureDetail detail) => detail.code,
        _ => null,
      };

  group('T-22 · FakeEventRepository', () {
    test('EventRepository arayüzünü uygular; registerDefaultFakes katılım '
        'fake’iyle aynı etkinlik kümesini paylaştırır', () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();

      final events = GetIt.I<EventRepository>();
      final rsvps = GetIt.I<RsvpRepository>() as FakeRsvpRepository;
      expect(events, isA<FakeEventRepository>());
      expect(rsvps.events, same(events));
    });

    test(
      'durum makinesi: taslak → yayın → (K-F) taslağa çekme → iptal; '
      'aykırı geçiş failedPrecondition, geçmiş başlangıç eventEnded',
      () async {
        final created = (await fake.createDraft(
          draft,
          clubId: 'c01',
          createdBy: _board,
        )).dataOrNull!;
        expect(fake.created.single, created);
        expect(
          (created.status, created.coverSeed),
          (
            EventStatus.draft,
            'event-${created.id}',
          ),
        );

        expect(
          (await fake.publish(created.id, actorId: _board)).isSuccess,
          isTrue,
        );
        expect(fake.events[created.id]!.publishedAt, clock.nowUtc());
        expect(
          (await fake.publish(created.id, actorId: _board)).errorOrNull,
          FirestoreError.failedPrecondition,
        );
        // Kayıtlı varken taslağa çekilemez (bekleme listesi engel değil).
        fake.bumpCounters(created.id, going: 1, waitlist: 1);
        expect(
          codeOf(await fake.unpublish(created.id)),
          FirestoreRuleCode.eventHasRegistrations,
        );
        fake.bumpCounters(created.id, going: -1);
        expect((await fake.unpublish(created.id)).isSuccess, isTrue);
        expect(fake.events[created.id]!.publishedAt, isNotNull);
        await fake.publish(created.id, actorId: _board);
        expect(
          (await fake.cancel(
            created.id,
            reason: '  Salon tadilatta. ',
            actorId: _board,
          )).isSuccess,
          isTrue,
        );
        final cancelled = fake.events[created.id]!;
        expect(
          (cancelled.status, cancelled.cancelReason, cancelled.waitlistCount),
          (
            EventStatus.cancelled,
            'Salon tadilatta.',
            1,
          ),
        );
        expect(
          (await fake.update(
            created.id,
            const EventEditPatch(title: 'Yeni'),
          )).errorOrNull,
          FirestoreError.failedPrecondition,
        );

        final past = EventDraft(
          title: 'Geçmiş',
          type: EventType.social,
          startsAt: clock.nowUtc().subtract(const Duration(hours: 1)),
          endsAt: clock.nowUtc().add(const Duration(hours: 1)),
          coverPalette: ClubPalette.slate,
          coverPattern: ClubPattern.lines,
        );
        expect(
          codeOf(
            await fake.create(
              past,
              clubId: 'c01',
              createdBy: _board,
              status: EventStatus.published,
            ),
          ),
          FirestoreRuleCode.eventEnded,
        );
        expect(
          (await fake.create(
            draft,
            clubId: 'c01',
            createdBy: _board,
            status: EventStatus.cancelled,
          )).errorOrNull,
          FirestoreError.invalidArgument,
        );
      },
    );

    test('update: yamayı yazar ve kaydeder; boşaltma bayrağı alanı null yapar; '
        'kontenjan kayıtlının altına inemez; olmayan → permissionDenied, '
        'silinmiş → notFound', () async {
      final e01 = EventModelFixtures.e01;
      final patch = EventEditPatch(
        title: 'Yapay Zekâ (2. oturum)',
        capacity: e01.goingCount,
        clearPlaceId: true,
        placeText: 'Kütüphane önü',
      );

      expect((await fake.update('e01', patch)).isSuccess, isTrue);
      final updated = fake.events['e01']!;
      expect(
        (updated.title, updated.capacity, updated.placeId, updated.placeText),
        ('Yapay Zekâ (2. oturum)', e01.goingCount, null, 'Kütüphane önü'),
      );
      expect(fake.patches.single, (eventId: 'e01', patch: patch));
      expect(
        codeOf(
          await fake.update(
            'e01',
            EventEditPatch(capacity: e01.goingCount - 1),
          ),
        ),
        FirestoreRuleCode.capacityFull,
      );
      expect(
        (await fake.update(
          'e01',
          const EventEditPatch(
            coverPath: 'events/e02/20261014T090000Z_0000000000000001.jpg',
          ),
        )).errorOrNull,
        FirestoreError.invalidArgument,
      );
      expect(
        (await fake.update(
          'yok',
          const EventEditPatch(title: 'x'),
        )).errorOrNull,
        FirestoreError.permissionDenied,
      );
      expect(fake.patches, hasLength(1));
    });

    test('update: yayındaki bitmiş etkinliğin zamanı değişemez (CD-144 — '
        'yoklama penceresi yeniden açılamaz) → eventEnded; zaman dışı içerik '
        'düzenlenir', () async {
      final e19 = EventModelFixtures.e19;
      expect(e19.status, EventStatus.published);
      expect(e19.isPast(clock), isTrue);

      expect(
        codeOf(
          await fake.update(
            'e19',
            EventEditPatch(endsAt: clock.nowUtc().add(const Duration(days: 1))),
          ),
        ),
        FirestoreRuleCode.eventEnded,
      );
      expect(
        (await fake.update(
          'e19',
          EventEditPatch(title: 'Yeni başlık', endsAt: e19.endsAt),
        )).isSuccess,
        isTrue,
      );
      expect(fake.events['e19']!.endsAt, e19.endsAt);
    });

    test('yalnızca taslak soft delete edilir ve geri alınır; iptal edilmiş '
        'etkinlikte kayıt aç / kapa reddedilir (kör yazım)', () async {
      expect(
        (await fake.softDeleteEvent('e01', actorId: _board)).errorOrNull,
        FirestoreError.failedPrecondition,
      );
      expect(
        (await fake.softDeleteEvent('e22', actorId: 'u_burak')).isSuccess,
        isTrue,
      );
      expect(fake.events['e22']!.deletedBy, 'u_burak');
      expect((await fake.getEvent('e22')).errorOrNull, FirestoreError.notFound);
      expect((await fake.restoreEvent('e22')).isSuccess, isTrue);
      expect(fake.events['e22']!.isDeleted, isFalse);
      expect(
        (await fake.restoreEvent('e22')).errorOrNull,
        FirestoreError.permissionDenied,
      );

      expect(
        (await fake.setRegistrationOpen('e21', false)).errorOrNull,
        FirestoreError.permissionDenied,
      );
      expect((await fake.setRegistrationOpen('e01', false)).isSuccess, isTrue);
      expect(fake.events['e01']!.registrationOpen, isFalse);
    });

    test('duplicate: yeni taslak, tarih +7 gün, başlık + ek (80 sınırı); kapak '
        've sayaçlar kopyalanmaz', () async {
      fake.put(
        EventModelFixtures.e03.copyWith(
          coverPath: 'events/e03/20261014T090000Z_0000000000000001.jpg',
        ),
      );

      final copy = (await fake.duplicate(
        'e03',
        createdBy: 'u_burak',
        copyTitleSuffix: ' (kopya)',
      )).dataOrNull!;

      final source = EventModelFixtures.e03;
      expect(copy.title, '${source.title} (kopya)');
      expect(copy.startsAt, source.startsAt.add(Limits.eventCopyShift));
      expect(
        (copy.status, copy.coverPath, copy.goingCount, copy.waitlistCount),
        (EventStatus.draft, null, 0, 0),
      );
      expect(copy.capacity, source.capacity);
      expect(fake.created.single, copy);
    });

    test('uploadCover: etkinliğin klasörüne yükler ve coverPath yazar; Storage '
        'hatası yüklemez; Firestore hatası dosyayı yetim bırakır', () async {
      final bytes = Uint8List.fromList(const [0xff, 0xd8, 0xff]);

      final path = (await fake.uploadCover(
        'e01',
        bytes,
        contentType: 'image/jpeg',
        clubId: 'c01',
        uploaderId: _board,
      )).dataOrNull!;

      expect(StoragePaths.isEventCover(path, 'e01'), isTrue);
      expect(fake.events['e01']!.coverPath, path);
      expect(fake.coverUploads.single.uploaderId, _board);

      fake.failNext(StorageError.unauthorized);
      final denied = await fake.uploadCover(
        'e01',
        bytes,
        contentType: 'image/jpeg',
        clubId: 'c01',
        uploaderId: _board,
      );
      expect(
        denied.errorOrNull,
        const MediaUploadError(StorageError.unauthorized),
      );
      expect(fake.coverUploads, hasLength(1));

      final orphan = await fake.uploadCover(
        'e21',
        bytes,
        contentType: 'image/png',
        clubId: 'c07',
        uploaderId: 'u_p_c07',
      );
      expect(
        orphan.errorOrNull,
        const MediaDocumentError(FirestoreError.permissionDenied),
      );
      expect(fake.coverUploads, hasLength(2));
      expect(fake.events['e21']!.coverPath, isNull);
      expect(
        (await fake.uploadCover(
          'e01',
          bytes,
          contentType: 'image/gif',
          clubId: 'c01',
          uploaderId: _board,
        )).errorOrNull,
        const MediaUploadError(StorageError.invalidType),
      );
    });

    test(
      'liste sorguları sözleşme süzgeçleriyle: herkese açık yaklaşan '
      '(en yakın üstte), üyelere özel (kulüp başına sorgu kaydı), kulüp '
      'etkinlikleri üç kipte; getEvents girdi sırası, olmayan atlanır',
      () async {
        final now = clock.nowUtc();
        final public = (await fake.listPublicUpcoming(
          fromUtc: now,
        )).dataOrNull!;
        expect(public, isNotEmpty);
        expect(
          public.every(
            (event) =>
                event.visibility == EventVisibility.public &&
                event.status != EventStatus.draft &&
                !event.startsAt.isBefore(now),
          ),
          isTrue,
        );
        for (var i = 1; i < public.length; i++) {
          expect(public[i - 1].startsAt.isAfter(public[i].startsAt), isFalse);
        }

        final members = (await fake.listMembersUpcoming(
          'c01',
          fromUtc: now,
        )).dataOrNull!;
        expect(members.map((event) => event.id), contains('e02'));
        expect(fake.membersUpcomingQueries, ['c01']);

        Future<List<String>> club({
          bool includeDrafts = false,
          bool publicOnly = false,
        }) async => [
          for (final event in (await fake.listClubEvents(
            'c03',
            const PageRequest(),
            includeDrafts: includeDrafts,
            publicOnly: publicOnly,
          )).dataOrNull!.items)
            event.id,
        ];
        expect(await club(includeDrafts: true), contains('e22'));
        expect(await club(), isNot(contains('e22')));
        expect(await club(publicOnly: true), isNot(contains('e16')));
        expect(
          (await fake.listClubEvents(
            'c03',
            const PageRequest(),
            includeDrafts: true,
            publicOnly: true,
          )).errorOrNull,
          FirestoreError.invalidArgument,
        );

        final fetched = await fake.getEvents(['e03', 'yok', 'e01', 'e03']);
        expect(fetched.dataOrNull!.map((event) => event.id), ['e03', 'e01']);
      },
    );

    test('failNext tek seferliktir; geçersiz kimlik invalidArgument', () async {
      fake.failNext(FirestoreError.unavailable);

      expect(
        (await fake.getEvent('e01')).errorOrNull,
        FirestoreError.unavailable,
      );
      expect((await fake.getEvent('e01')).isSuccess, isTrue);
      expect(
        (await fake.getEvent('e/1')).errorOrNull,
        FirestoreError.invalidArgument,
      );
      expect(fake.callsTo('getEvent'), hasLength(3));
    });
  });
}
