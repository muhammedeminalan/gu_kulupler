// `RecipientResolver` fake'i (PLAN §16.3, §10.5): alıcı kümeleri test
// tarafından kurulur; sorgu yoktur. Uygulama tarafında yalnızca DLG-22 "{n}"
// tahmini okunur (T-34, CD-38).
//
//   final recipients = GetIt.I<RecipientResolver>() as FakeRecipientResolver;
//   recipients.eventNewIds = ['u01', 'u02', 'u03'];
//   expect(await viewModel.estimateRecipients(), 3);
//   recipients.failNext(FirestoreError.unavailable); // tek seferlik hata
import 'package:gu_data/gu_data.dart';

import 'fake_base.dart';

final class FakeRecipientResolver extends FakeBase
    implements RecipientResolver {
  /// [managersOf] sonucu (kulüp kimliğine göre).
  final Map<String, List<String>> managers = <String, List<String>>{};

  /// [membersOf] sonucu (kulüp kimliğine göre; `excludeUserId` süzülür).
  final Map<String, List<String>> members = <String, List<String>>{};

  /// [rsvpUsersOf] sonucu (etkinlik kimliğine göre).
  final Map<String, List<String>> rsvpUsers = <String, List<String>>{};

  /// [eventNew] / [estimateEventNew] kümesi (üyeler ∪ ilgi eşleşmeli —
  /// CD-38); `event.createdBy` süzülür.
  List<String> eventNewIds = const <String>[];

  @override
  Future<FirestoreResult<List<String>>> managersOf(String clubId) async {
    record('managersOf', [clubId]);
    return _result(() => [...?managers[clubId]]);
  }

  @override
  Future<FirestoreResult<List<String>>> membersOf(
    String clubId, {
    String? excludeUserId,
  }) async {
    record('membersOf', [clubId, excludeUserId]);
    return _result(
      () => [
        for (final id in members[clubId] ?? const <String>[])
          if (id != excludeUserId) id,
      ],
    );
  }

  @override
  Future<FirestoreResult<List<String>>> rsvpUsersOf(
    String eventId,
    String clubId,
    Set<RsvpStatus> statuses,
  ) async {
    record('rsvpUsersOf', [eventId, clubId, statuses]);
    return _result(() => [...?rsvpUsers[eventId]]);
  }

  @override
  Future<FirestoreResult<RecipientSet>> eventNew(
    EventModel event,
    ClubModel club,
  ) async {
    record('eventNew', [event.clubId, club.id]);
    return _result(() => RecipientSet(ids: _eventNewOf(event)));
  }

  @override
  Future<FirestoreResult<int>> estimateEventNew(
    EventModel event,
    ClubModel club,
  ) async {
    record('estimateEventNew', [event.clubId, event.visibility, club.id]);
    return _result(() => _eventNewOf(event).length);
  }

  List<String> _eventNewOf(EventModel event) => [
    for (final id in {...eventNewIds})
      if (id != event.createdBy) id,
  ];

  FirestoreResult<T> _result<T>(T Function() data) {
    if (takeFailure() case final error?) {
      return FirebaseFailure(
        error is FirestoreError ? error : FirestoreError.unknown,
      );
    }
    return FirebaseSuccess(data());
  }
}
