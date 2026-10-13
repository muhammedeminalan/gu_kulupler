import 'package:cloud_firestore/cloud_firestore.dart' show WriteBatch;
import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';

/// [FakeNotificationDispatcher]'a yapılmış tek çağrının kaydı (PLAN §16.3).
final class DispatchCall extends Equatable {
  /// [kind] çağrılan `notifyX` üyesinin adıdır; [args] alıcı ve batch
  /// dışındaki argümanlar, [recipients] çağrının bildirdiği alıcılardır
  /// (alıcıları dağıtıcının çözdüğü çağrılarda boş).
  const DispatchCall({
    required this.kind,
    this.args = const {},
    this.recipients = const [],
  });

  /// Çağrılan üyenin adı (`notifyApplicationReceived` …).
  final String kind;

  /// Adlandırılmış argümanlar (`recipients` / `batch` hariç).
  final Map<String, Object?> args;

  /// Çağrının hedeflediği kullanıcılar.
  final List<String> recipients;

  @override
  List<Object?> get props => [kind, args, recipients];

  @override
  bool? get stringify => true;
}

/// Çağrıları kaydeden, hiçbir belge yazmayan [NotificationDispatcher]
/// (PLAN §10.5, §16.3). Repository testleri hangi `notifyX` üyesinin hangi
/// argümanlarla çağrıldığını [calls] üzerinden doğrular.
final class FakeNotificationDispatcher implements NotificationDispatcher {
  /// Yapılan çağrılar, çağrı sırasıyla.
  final List<DispatchCall> calls = [];

  /// `batch` alan çağrılara verilen batch'ler, çağrı sırasıyla (batch'e
  /// hiçbir şey eklenmez).
  final List<WriteBatch> batches = [];

  /// Doluysa bir sonraki fan-out (`batch` almayan) çağrısı bu hatayla biter
  /// ve alan yeniden `null` olur.
  FirestoreError? failNextFanOut;

  @override
  Future<FirestoreResult<DispatchReport>> notifyApplicationReceived({
    required String clubId,
    required String applicantId,
  }) => _fanOut('notifyApplicationReceived', {
    'clubId': clubId,
    'applicantId': applicantId,
  }, const []);

  @override
  Future<FirestoreResult<DispatchReport>> notifyApplicationDecided({
    required String clubId,
    required String applicantId,
    required bool approved,
    required WriteBatch batch,
  }) => _inBatch(
    'notifyApplicationDecided',
    {'clubId': clubId, 'applicantId': applicantId, 'approved': approved},
    [applicantId],
    batch,
  );

  @override
  Future<FirestoreResult<DispatchReport>> notifyRemoved({
    required String clubId,
    required String userId,
    required WriteBatch batch,
  }) => _inBatch(
    'notifyRemoved',
    {'clubId': clubId, 'userId': userId},
    [userId],
    batch,
  );

  @override
  Future<FirestoreResult<DispatchReport>> notifyRoleChanged({
    required String clubId,
    required String userId,
    required ClubRole role,
    required WriteBatch batch,
  }) => _inBatch(
    'notifyRoleChanged',
    {'clubId': clubId, 'userId': userId, 'role': role},
    [userId],
    batch,
  );

  @override
  Future<FirestoreResult<DispatchReport>> notifyAnnouncement({
    required String postId,
    required String clubId,
    required List<String> recipients,
  }) => _fanOut('notifyAnnouncement', {
    'postId': postId,
    'clubId': clubId,
  }, recipients);

  @override
  Future<FirestoreResult<DispatchReport>> notifyEventNew({
    required String eventId,
    required String clubId,
    required List<String> recipients,
  }) => _fanOut('notifyEventNew', {
    'eventId': eventId,
    'clubId': clubId,
  }, recipients);

  @override
  Future<FirestoreResult<DispatchReport>> notifyEventCancelled({
    required String eventId,
    required String clubId,
    required List<String> recipients,
  }) => _fanOut('notifyEventCancelled', {
    'eventId': eventId,
    'clubId': clubId,
  }, recipients);

  @override
  Future<FirestoreResult<DispatchReport>> notifyWaitlistPromoted({
    required String eventId,
    required String clubId,
    required String userId,
    required WriteBatch batch,
  }) => _inBatch(
    'notifyWaitlistPromoted',
    {'eventId': eventId, 'clubId': clubId, 'userId': userId},
    [userId],
    batch,
  );

  @override
  Future<FirestoreResult<DispatchReport>> notifyReportResolved({
    required String reportGroupKey,
    required List<String> reporterIds,
    required WriteBatch batch,
  }) => _inBatch(
    'notifyReportResolved',
    {'reportGroupKey': reportGroupKey},
    reporterIds,
    batch,
  );

  @override
  Future<FirestoreResult<DispatchReport>> notifyNewReport({
    required String reportId,
  }) => _fanOut('notifyNewReport', {'reportId': reportId}, const []);

  @override
  Future<FirestoreResult<DispatchReport>> notifySystem({
    required List<String> userIds,
    required String textKey,
  }) => _fanOut('notifySystem', {'textKey': textKey}, userIds);

  Future<FirestoreResult<DispatchReport>> _inBatch(
    String kind,
    Map<String, Object?> args,
    List<String> recipients,
    WriteBatch batch,
  ) {
    batches.add(batch);
    return _record(kind, args, recipients);
  }

  Future<FirestoreResult<DispatchReport>> _fanOut(
    String kind,
    Map<String, Object?> args,
    List<String> recipients,
  ) {
    final error = failNextFanOut;
    if (error == null) return _record(kind, args, recipients);
    failNextFanOut = null;
    calls.add(DispatchCall(kind: kind, args: args, recipients: recipients));
    return Future.value(FirebaseFailure(error));
  }

  Future<FirestoreResult<DispatchReport>> _record(
    String kind,
    Map<String, Object?> args,
    List<String> recipients,
  ) {
    calls.add(DispatchCall(kind: kind, args: args, recipients: recipients));
    return Future.value(
      FirebaseSuccess(
        DispatchReport(
          requested: recipients.length,
          written: recipients.length,
          failedChunks: 0,
        ),
      ),
    );
  }
}
