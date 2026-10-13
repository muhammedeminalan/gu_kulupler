// T-15 · FakeActivityRepository sözleşmesi (PLAN §16.3): `entries`, kategori
// süzgeci ve sayfalama (`PageCursor.fake()`).
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';

import 'fake_activity_repository.dart';
import 'register_fakes.dart';

ActivityModel _entry(
  String id,
  ActivityKind kind,
  int minute, {
  String clubId = 'c01',
}) => ActivityModel(
  id: id,
  clubId: clubId,
  actorId: 'u1',
  kind: kind,
  createdAt: DateTime.utc(2026, 10, 13, 9, minute),
);

void main() {
  late FakeActivityRepository fake;

  setUp(() => fake = FakeActivityRepository());

  group('T-15 · FakeActivityRepository', () {
    test('ActivityRepository arayüzünü uygular; registerDefaultFakes '
        'kaydeder', () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      expect(GetIt.I<ActivityRepository>(), isA<FakeActivityRepository>());
    });

    test('yalnızca istenen kulübün kayıtları, en yeni üstte', () async {
      fake.entries.addAll([
        _entry('a1', ActivityKind.memberJoined, 1),
        _entry('a3', ActivityKind.memberLeft, 3),
        _entry('a2', ActivityKind.applicationReceived, 2),
        _entry('b1', ActivityKind.memberJoined, 9, clubId: 'c02'),
      ]);

      final page = await fake.listActivity('c01', const PageRequest());

      expect(
        [for (final entry in page.dataOrNull!.items) entry.id],
        ['a3', 'a2', 'a1'],
      );
      expect(page.dataOrNull!.hasMore, isFalse);
    });

    test('kategori süzgeci yalnızca o kategorinin türlerini getirir', () async {
      fake.entries.addAll([
        for (final (index, kind) in ActivityKind.values.indexed)
          _entry('a$index', kind, index),
      ]);

      for (final category in ActivityCategory.values) {
        final page = await fake.listActivity(
          'c01',
          const PageRequest(limit: 50),
          category: category,
        );
        expect(
          {for (final entry in page.dataOrNull!.items) entry.kind},
          category.kinds.toSet(),
          reason: category.name,
        );
      }
    });

    test('sayfalama: dolu sayfa imleç taşır, imleç sürdürür', () async {
      fake.entries.addAll([
        for (var i = 0; i < 5; i++) _entry('a$i', ActivityKind.memberJoined, i),
      ]);

      final first = (await fake.listActivity(
        'c01',
        const PageRequest(limit: 2),
      )).dataOrNull!;
      final second = (await fake.listActivity(
        'c01',
        PageRequest(limit: 2, after: first.next),
      )).dataOrNull!;

      expect([for (final entry in first.items) entry.id], ['a4', 'a3']);
      expect([for (final entry in second.items) entry.id], ['a2', 'a1']);
      expect(second.hasMore, isTrue);
    });

    test('geçersiz kimlik invalidArgument; failNext sıradaki çağrıyı '
        'düşürür', () async {
      expect(
        (await fake.listActivity('', const PageRequest())).errorOrNull,
        FirestoreError.invalidArgument,
      );
      fake.failNext(FirestoreError.permissionDenied);
      expect(
        (await fake.listActivity('c01', const PageRequest())).errorOrNull,
        FirestoreError.permissionDenied,
      );
      expect(
        (await fake.listActivity('c01', const PageRequest())).isSuccess,
        isTrue,
      );
    });
  });
}
