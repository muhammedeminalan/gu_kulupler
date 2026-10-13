// T-15 · FakeClubRepository sözleşmesi (PLAN §16.3): `clubs`,
// `isNameTakenCalls`; gerçek repository'nin sonuçlarını izler.
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';

import 'fake_club_repository.dart';
import 'register_fakes.dart';

void main() {
  late FakeClubRepository fake;

  setUp(() => fake = FakeClubRepository());

  group('T-15 · FakeClubRepository', () {
    test('ClubRepository arayüzünü uygular; registerDefaultFakes '
        'kaydeder', () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      expect(GetIt.I<ClubRepository>(), isA<FakeClubRepository>());
    });

    test('fetchActiveClubs: silinmiş gelmez, askıdaki gelir; sıra '
        'nameLower', () async {
      fake
        ..put('c02', name: 'Zeka Oyunları')
        ..put('c01', name: 'Bilişim', status: ClubStatus.suspended)
        ..put('c03', name: 'Arama Kurtarma', isDeleted: true);

      final clubs = (await fake.fetchActiveClubs()).dataOrNull!;

      expect([for (final club in clubs) club.id], ['c01', 'c02']);
      expect(clubs.first.isSuspended, isTrue);
    });

    test('getClub: olmayan ve silinmiş kulüp notFound', () async {
      fake
        ..put('c01')
        ..put('c02', isDeleted: true);

      expect((await fake.getClub('c01')).dataOrNull?.id, 'c01');
      expect((await fake.getClub('c02')).errorOrNull, FirestoreError.notFound);
      expect((await fake.getClub('c09')).errorOrNull, FirestoreError.notFound);
    });

    test('getClubs: istenen sırada, tekrarsız; olmayan ve silinmiş '
        'atlanır', () async {
      fake
        ..put('c01')
        ..put('c02', isDeleted: true)
        ..put('c03');

      final clubs = await fake.getClubs(['c03', 'c09', 'c02', 'c01', 'c03']);

      expect([for (final club in clubs.dataOrNull!) club.id], ['c03', 'c01']);
    });

    test('isNameTaken: silinmiş kulübün adı da dolu; çağrı '
        '`isNameTakenCalls`e yazılır', () async {
      fake.put('c01', name: 'Satranç Kulübü', isDeleted: true);

      expect((await fake.isNameTaken('satranç kulübü')).dataOrNull, isTrue);
      expect((await fake.isNameTaken('münazara')).dataOrNull, isFalse);
      expect(fake.isNameTakenCalls, ['satranç kulübü', 'münazara']);
    });

    test('geçersiz kimlik / ad invalidArgument; failNext sıradaki çağrıyı '
        'düşürür (tek seferlik)', () async {
      fake.put('c01');

      expect(
        (await fake.getClub('c/1')).errorOrNull,
        FirestoreError.invalidArgument,
      );
      expect(
        (await fake.getClubs(['c01', ''])).errorOrNull,
        FirestoreError.invalidArgument,
      );
      expect(
        (await fake.isNameTaken('')).errorOrNull,
        FirestoreError.invalidArgument,
      );
      fake.failNext(FirestoreError.unavailable);
      expect(
        (await fake.fetchActiveClubs()).errorOrNull,
        FirestoreError.unavailable,
      );
      expect((await fake.fetchActiveClubs()).isSuccess, isTrue);
      expect(fake.callsTo('fetchActiveClubs'), hasLength(2));
    });
  });
}
