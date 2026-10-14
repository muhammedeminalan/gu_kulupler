// T-34 · FakeRecipientResolver sözleşmesi (PLAN §16.3, §10.5).
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';

import '../fixtures/club_model_fixtures.dart';
import '../fixtures/event_model_fixtures.dart';
import 'fake_base.dart';
import 'fake_recipient_resolver.dart';
import 'register_fakes.dart';

void main() {
  group('T-34 · FakeRecipientResolver', () {
    test(
      'RecipientResolver arayüzünü uygular; registerDefaultFakes kaydeder',
      () {
        addTearDown(GetIt.I.reset);
        registerDefaultFakes();
        expect(GetIt.I<RecipientResolver>(), isA<FakeRecipientResolver>());
      },
    );

    test('eventNew / estimateEventNew: küme tekil, yayıncı hariç', () async {
      final event = EventModelFixtures.e01;
      final club = ClubModelFixtures.byId(event.clubId);
      final fake = FakeRecipientResolver()
        ..eventNewIds = [
          'u90',
          'u91',
          'u91',
          ?event.createdBy,
        ];

      expect(
        (await fake.eventNew(event, club)).dataOrNull?.ids,
        ['u90', 'u91'],
      );
      expect((await fake.estimateEventNew(event, club)).dataOrNull, 2);
      expect(fake.callsTo('estimateEventNew'), [
        FakeCall('estimateEventNew', [event.clubId, event.visibility, club.id]),
      ]);
    });

    test('membersOf excludeUserId süzer; failNext tek seferlik hata', () async {
      final fake = FakeRecipientResolver()..members['c01'] = ['u01', 'u02'];

      expect(
        (await fake.membersOf('c01', excludeUserId: 'u01')).dataOrNull,
        ['u02'],
      );
      fake.failNext(FirestoreError.unavailable);
      final failed = await fake.managersOf('c01');
      expect(failed.errorOrNull, FirestoreError.unavailable);
      expect((await fake.managersOf('c01')).dataOrNull, isEmpty);
      expect(
        (await fake.rsvpUsersOf('e01', 'c01', {RsvpStatus.going})).dataOrNull,
        isEmpty,
      );
    });
  });
}
