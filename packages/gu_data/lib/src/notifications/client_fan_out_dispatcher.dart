import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart'
    show FirebaseException, Transaction, WriteBatch;
import 'package:gu_data/src/constants/firestore_ids.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/models/enums/club_role.dart';
import 'package:gu_data/src/models/enums/notification_type.dart';
import 'package:gu_data/src/models/notification_draft.dart';
import 'package:gu_data/src/models/notification_refs_model.dart';
import 'package:gu_data/src/notifications/notification_dispatcher.dart';
import 'package:gu_data/src/notifications/notification_writer.dart';
import 'package:gu_data/src/notifications/recipient_resolver.dart';
import 'package:gu_data/src/repositories/repository_helpers.dart';
import 'package:gu_data/src/utils/retry_policy.dart';

/// Eksik kalan bir dağıtımı uygulama katmanına bildirir (PLAN §10.5:
/// `failedChunks > 0` → `AppLogger.warn` + Crashlytics `nonFatal`).
///
/// `gu_data` günlük yazmaz (Q-05); kompozisyon kökü bu dinleyiciyi
/// `AppLogger`'a bağlar. [result] yalnızca sayıları ve hata türünü taşır
/// (alıcı kimliği yok).
typedef DispatchIssueListener =
    void Function(
      NotificationType type,
      FirestoreResult<DispatchReport> result,
    );

/// İstemcinin bildirimleri kendisinin yazdığı [NotificationDispatcher]
/// (Mod C — Q-02; PLAN §10.5, §15.3; `docs/plans/T-25.md` §6).
///
/// **Değiştirilebilirlik (CD-147):** çağıran repository'ler yalnızca
/// [NotificationDispatcher] arayüzünü bilir. Mod F'de bu sınıfın yerine
/// kompozisyon kökünde `ServerSideDispatcher` takılır; belge şeması
/// (`NotificationWriter` dartdoc'u) sunucu tetikleyicisinin yazacağı şemayla
/// aynıdır, istemciye özgü alan taşımaz.
///
/// - **Kritik üyeler** (`batch` alanlar): türün tek alıcılı belgesini
///   [NotificationWriter.addToBatch] ile çağıranın batch'ine **eşzamanlı**
///   ekler; commit ve ağ çağrısı yoktur. Geçersiz kimlikte batch'e hiçbir
///   şey eklenmez ve `invalid-argument` kodlu [FirebaseException] çağrı
///   anında fırlatılır: `commitBatch` gövdesi bunu yakalar, batch'in hiçbir
///   yazımı uygulanmaz (asıl yazım bildirimsiz kesinleşmez).
/// - **Fan-out üyeleri:** alıcılar tekilleştirilir, geçersiz kimlikler
///   atlanır (`requested`'e sayılır, `written`'e sayılmaz) ve
///   [Limits.notificationFanOutChunkSize] boyutlu parçalar sırayla
///   [NotificationWriter.createMany] ile yazılır. Parça [RetryPolicy] ile
///   yeniden denenir (yalnızca `aborted` / `unavailable`); kalıcı hata
///   [DispatchReport.failedChunks] olur ve sonuç yine [FirebaseSuccess]'tir.
///   - Yeniden denemede gelen `permissionDenied` "önceki deneme sunucuda
///     kesinleşmiş" sayılır (aynı kimliklere ikinci `set` = update → ret):
///     parça yazılmış kabul edilir, sonraki parçalar sürer.
///   - Rules'u tüm parçalarda aynı olan türlerde (`announcement`,
///     `event_new`, `event_cancelled`) `permissionDenied` önce parçayı
///     **yarılar** (canlıda erişim önbelleği / ifade sınırı ölçülmedi —
///     rules-spec §5): küçülen boy sonraki parçalarda da kullanılır. Tek
///     belgelik parça da reddedilirse ret bütçeden değil kuraldandır ve
///     kalan parçalar denenmeden başarısız sayılır.
///   - `application_received` alıcı başına ayrı batch'tir (Rules alıcının
///     yönetici üyeliğini okur — parça boyu 1); bir alıcının reddi
///     diğerlerini durdurmaz.
/// - **Kimlik (W-49, CD-148):** her `notifyX` çağrısı tek olaydır ve bir
///   olay anahtarı alır; olayın tüm alıcıları, parçaları ve yeniden
///   denemeleri onu paylaşır. Tek seferlik olaylarda anahtar olayın kimliğidir
///   (duyuru → `postId`, iptal → `eventId`, başvuru →
///   [FirestoreIds.applicationEventKey]); diğerlerinde
///   [NotificationWriter.newEventKey] çağrı başına **bir kez** üretilir.
/// - **Tercih ve sessiz saat uygulanmaz:** belge her alıcıya yazılır,
///   okuyan taraf süzer (`NotificationPreferenceFilter`).
/// - Fan-out üyeleri fırlatmaz: beklenmeyen istisna [FirestoreError.unknown]
///   olur. Başarısızlık ya da eksik yazım [DispatchIssueListener]'a da
///   iletilir.
final class ClientFanOutDispatcher implements NotificationDispatcher {
  /// Belgeleri `writer` ile yazar, `application_received` alıcılarını
  /// `recipients` ile çözer, parçaları `retry` ile yeniden dener; eksik
  /// kalan dağıtımı `onIssue` dinleyicisine bildirir.
  const ClientFanOutDispatcher({
    required this._writer,
    required this._recipients,
    this._retry = const RetryPolicy(),
    this._onIssue,
  });

  final NotificationWriter _writer;
  final RecipientResolver _recipients;
  final RetryPolicy _retry;
  final DispatchIssueListener? _onIssue;

  /// `application_received` parça boyu: Rules her belgede alıcının üyeliğini
  /// okur, yol alıcıya göre değişir (`docs/plans/T-25.md` §6 d).
  static const int _perRecipientChunk = 1;

  /// İstemcide üretilmeyen bildirimin (`new_report` — CD-37) alıcı sayısı.
  static const int _unresolved = 0;

  /// Yarılamanın tabanı: tek belgelik parça.
  static const int _minChunk = 1;

  /// Parça yarılama böleni.
  static const int _halves = 2;

  /// Geçersiz kritik bildirim girdisinin SDK kodu (`commitBatch` bunu
  /// [FirestoreError.invalidArgument]'a eşler).
  static const String _invalidArgumentCode = 'invalid-argument';

  /// Fırlatılan doğrulama hatasının eklenti adı (SDK hatalarıyla aynı).
  static const String _plugin = 'cloud_firestore';

  /// Tüm parçalar için aynı sonucu veren (yeniden denemesi anlamsız) hatalar.
  static const Set<FirestoreError> _deterministic = {
    FirestoreError.permissionDenied,
    FirestoreError.unauthenticated,
    FirestoreError.invalidArgument,
  };

  @override
  Future<FirestoreResult<DispatchReport>> notifyApplicationReceived({
    required String clubId,
    required String applicantId,
    required int sequence,
  }) => _guard(NotificationType.applicationReceived, () async {
    if (RepositoryHelpers.rejectInvalidIds<DispatchReport>({
          'clubId': clubId,
          'applicantId': applicantId,
        })
        case final rejected?) {
      return rejected;
    }
    if (sequence < 0) {
      return RepositoryHelpers.invalidArgument('geçersiz sıra: $sequence');
    }
    final managers = await _recipients.managersOf(clubId);
    switch (managers) {
      case FirebaseFailure(:final error, :final message, :final detail):
        return FirebaseFailure(error, message: message, detail: detail);
      case FirebaseSuccess(data: final ids):
        return FirebaseSuccess(
          await _fanOut(
            NotificationDraft(
              type: NotificationType.applicationReceived,
              refs: NotificationRefsModel(
                clubId: clubId,
                applicantId: applicantId,
              ),
              eventKey: FirestoreIds.applicationEventKey(
                clubId,
                applicantId,
                sequence,
              ),
            ),
            ids.where((id) => id != applicantId),
            chunkSize: _perRecipientChunk,
            uniformRules: false,
          ),
        );
    }
  });

  @override
  Future<FirestoreResult<DispatchReport>> notifyApplicationDecided({
    required String clubId,
    required String applicantId,
    required bool approved,
    required WriteBatch batch,
  }) {
    final type = approved
        ? NotificationType.applicationApproved
        : NotificationType.applicationRejected;
    return _inBatch(
      batch,
      type,
      NotificationRefsModel(clubId: clubId),
      refIds: {'clubId': clubId},
      recipientIds: [applicantId],
    );
  }

  @override
  Future<FirestoreResult<DispatchReport>> notifyRemoved({
    required String clubId,
    required String userId,
    required WriteBatch batch,
  }) => _inBatch(
    batch,
    NotificationType.removedFromClub,
    NotificationRefsModel(clubId: clubId),
    refIds: {'clubId': clubId},
    recipientIds: [userId],
  );

  @override
  Future<FirestoreResult<DispatchReport>> notifyRoleChanged({
    required String clubId,
    required String userId,
    required ClubRole role,
    required WriteBatch batch,
  }) => _inBatch(
    batch,
    NotificationType.roleChanged,
    NotificationRefsModel(clubId: clubId, role: role),
    refIds: {'clubId': clubId},
    recipientIds: [userId],
  );

  @override
  Future<FirestoreResult<DispatchReport>>
  notifyApplicationDecidedInTransaction({
    required String clubId,
    required String applicantId,
    required bool approved,
    required Transaction transaction,
  }) => _inTransaction(
    transaction,
    approved
        ? NotificationType.applicationApproved
        : NotificationType.applicationRejected,
    NotificationRefsModel(clubId: clubId),
    refIds: {'clubId': clubId},
    recipientIds: [applicantId],
  );

  @override
  Future<FirestoreResult<DispatchReport>> notifyRemovedInTransaction({
    required String clubId,
    required String userId,
    required Transaction transaction,
  }) => _inTransaction(
    transaction,
    NotificationType.removedFromClub,
    NotificationRefsModel(clubId: clubId),
    refIds: {'clubId': clubId},
    recipientIds: [userId],
  );

  @override
  Future<FirestoreResult<DispatchReport>> notifyRoleChangedInTransaction({
    required String clubId,
    required String userId,
    required ClubRole role,
    required Transaction transaction,
  }) => _inTransaction(
    transaction,
    NotificationType.roleChanged,
    NotificationRefsModel(clubId: clubId, role: role),
    refIds: {'clubId': clubId},
    recipientIds: [userId],
  );

  @override
  Future<FirestoreResult<DispatchReport>> notifyAnnouncement({
    required String postId,
    required String clubId,
    required List<String> recipients,
  }) => _guardedFanOut(
    NotificationType.announcement,
    NotificationRefsModel(clubId: clubId, postId: postId),
    refIds: {'clubId': clubId, 'postId': postId},
    recipientIds: recipients,
    eventKey: postId,
  );

  @override
  Future<FirestoreResult<DispatchReport>> notifyEventNew({
    required String eventId,
    required String clubId,
    required List<String> recipients,
  }) => _guardedFanOut(
    NotificationType.eventNew,
    NotificationRefsModel(clubId: clubId, eventId: eventId),
    refIds: {'clubId': clubId, 'eventId': eventId},
    recipientIds: recipients,
  );

  @override
  Future<FirestoreResult<DispatchReport>> notifyEventCancelled({
    required String eventId,
    required String clubId,
    required List<String> recipients,
  }) => _guardedFanOut(
    NotificationType.eventCancelled,
    NotificationRefsModel(clubId: clubId, eventId: eventId),
    refIds: {'clubId': clubId, 'eventId': eventId},
    recipientIds: recipients,
    eventKey: eventId,
  );

  @override
  Future<FirestoreResult<DispatchReport>> notifyWaitlistPromoted({
    required String eventId,
    required String clubId,
    required String userId,
    required WriteBatch batch,
  }) => _inBatch(
    batch,
    NotificationType.waitlistPromoted,
    NotificationRefsModel(clubId: clubId, eventId: eventId),
    refIds: {'clubId': clubId, 'eventId': eventId},
    recipientIds: [userId],
  );

  @override
  Future<FirestoreResult<DispatchReport>> notifyWaitlistPromotedInTransaction({
    required String eventId,
    required String clubId,
    required String userId,
    required Transaction transaction,
  }) => _inTransaction(
    transaction,
    NotificationType.waitlistPromoted,
    NotificationRefsModel(clubId: clubId, eventId: eventId),
    refIds: {'clubId': clubId, 'eventId': eventId},
    recipientIds: [userId],
  );

  @override
  Future<FirestoreResult<DispatchReport>> notifyReportResolved({
    required String reportGroupKey,
    required List<String> reporterIds,
    required WriteBatch batch,
  }) => _inBatch(
    batch,
    NotificationType.reportResolved,
    NotificationRefsModel(reportId: reportGroupKey),
    refIds: {'reportGroupKey': reportGroupKey},
    recipientIds: reporterIds,
  );

  /// İstemcide üretilmez (süper admin kümesi bilinemez — CD-37); Mod F'de
  /// (T-42, CD-165) `functions/` içindeki `notifyNewReport` tetikleyicisi
  /// şikayet belgesinden üretir.
  @override
  Future<FirestoreResult<DispatchReport>> notifyNewReport({
    required String reportId,
  }) => Future.value(_notWritten(_unresolved));

  /// İstemcide yazılmaz: `system` belgesini Mod C'de yalnızca yönetim
  /// betiği (Admin SDK) yazar, Rules istemciye kapalıdır.
  @override
  Future<FirestoreResult<DispatchReport>> notifySystem({
    required List<String> userIds,
    required String textKey,
  }) => Future.value(_notWritten(userIds.toSet().length));

  /// [type] türünde, [refs] referanslı taslak; olay anahtarı [eventKey]
  /// (tek seferlik olay) ya da bu çağrıya ait yeni rastgele anahtar.
  NotificationDraft _draft(
    NotificationType type,
    NotificationRefsModel refs, {
    String? eventKey,
  }) => NotificationDraft(
    type: type,
    refs: refs,
    eventKey: eventKey ?? _writer.newEventKey(),
  );

  /// Kritik üye: [recipientIds] alıcılarının her birine (tekil) [type]
  /// belgesini [batch]'e **eşzamanlı** ekler.
  ///
  /// [refIds] ya da bir alıcı kimliği geçersizse (ya da yazıcı taslağı
  /// reddederse) batch'e hiçbir şey eklenmeden `invalid-argument` kodlu
  /// [FirebaseException] fırlatılır ve [_onIssue]'ya iletilir: dönen sonucu
  /// bekleyemeyen `commitBatch` gövdesi batch'i bu istisnayla düşürür.
  Future<FirestoreResult<DispatchReport>> _inBatch(
    WriteBatch batch,
    NotificationType type,
    NotificationRefsModel refs, {
    required Map<String, String> refIds,
    required List<String> recipientIds,
  }) => _critical(
    (draft, recipientId) =>
        _writer.addToBatch(batch, draft, recipientId: recipientId),
    type,
    refs,
    refIds: refIds,
    recipientIds: recipientIds,
  );

  /// [_inBatch]'in transaction karşılığı: belgeler [transaction]'a eklenir.
  Future<FirestoreResult<DispatchReport>> _inTransaction(
    Transaction transaction,
    NotificationType type,
    NotificationRefsModel refs, {
    required Map<String, String> refIds,
    required List<String> recipientIds,
  }) => _critical(
    (draft, recipientId) => _writer.addToTransaction(
      transaction,
      draft,
      recipientId: recipientId,
    ),
    type,
    refs,
    refIds: refIds,
    recipientIds: recipientIds,
  );

  /// Kritik üyelerin ortak gövdesi: doğrulama, tek olay anahtarı ve her
  /// alıcı için [add] (batch ya da transaction'a ekleme).
  Future<FirestoreResult<DispatchReport>> _critical(
    void Function(NotificationDraft draft, String recipientId) add,
    NotificationType type,
    NotificationRefsModel refs, {
    required Map<String, String> refIds,
    required List<String> recipientIds,
  }) {
    final unique = recipientIds.toSet().toList();
    final rejected =
        RepositoryHelpers.rejectInvalidIds<DispatchReport>(refIds) ??
        RepositoryHelpers.rejectInvalidIds<DispatchReport>({
          for (final (index, id) in unique.indexed) 'recipientIds[$index]': id,
        });
    try {
      if (rejected case FirebaseFailure(:final message)) {
        throw FirebaseException(
          plugin: _plugin,
          code: _invalidArgumentCode,
          message: message,
        );
      }
      final draft = _draft(type, refs);
      for (final recipientId in unique) {
        add(draft, recipientId);
      }
    } on FirebaseException catch (error) {
      _onIssue?.call(
        type,
        FirebaseFailure(
          FirestoreError.fromCode(error.code),
          message: error.message,
        ),
      );
      rethrow;
    }
    return Future.value(
      FirebaseSuccess(
        DispatchReport(
          requested: unique.length,
          written: unique.length,
          failedChunks: 0,
        ),
      ),
    );
  }

  /// Alıcıları çağıranın verdiği, Rules'u tüm parçalarda aynı fan-out üyesi;
  /// [eventKey] verilmezse çağrıya yeni rastgele anahtar üretilir.
  Future<FirestoreResult<DispatchReport>> _guardedFanOut(
    NotificationType type,
    NotificationRefsModel refs, {
    required Map<String, String> refIds,
    required List<String> recipientIds,
    String? eventKey,
  }) => _guard(type, () async {
    if (RepositoryHelpers.rejectInvalidIds<DispatchReport>(refIds)
        case final rejected?) {
      return rejected;
    }
    return FirebaseSuccess(
      await _fanOut(
        _draft(type, refs, eventKey: eventKey),
        recipientIds,
        chunkSize: Limits.notificationFanOutChunkSize,
        uniformRules: true,
      ),
    );
  });

  /// [draft] bildirimini [recipientIds] alıcılarına en çok [chunkSize]
  /// boyutlu parçalarla, sırayla yazar.
  ///
  /// [uniformRules] `true` ise Rules her parçada aynı yolları okur:
  /// `permissionDenied` alan çok belgeli parça yarılanır ve aynı yerden
  /// küçük boyla devam edilir; tek belgelik parçanın [_deterministic] hatası
  /// kalan parçaları denemeden başarısız sayar.
  Future<DispatchReport> _fanOut(
    NotificationDraft draft,
    Iterable<String> recipientIds, {
    required int chunkSize,
    required bool uniformRules,
  }) async {
    final unique = recipientIds.toSet().toList();
    final valid = unique.where(RepositoryHelpers.isValidId).toList();
    var size = chunkSize;
    var offset = 0;
    var written = 0;
    var failedChunks = 0;
    while (offset < valid.length) {
      final end = math.min(offset + size, valid.length);
      final chunk = valid.sublist(offset, end);
      switch (await _writeChunk(draft, chunk)) {
        case FirebaseSuccess(:final data):
          written += data;
          offset = end;
        case FirebaseFailure(error: FirestoreError.permissionDenied)
            when uniformRules && chunk.length > _minChunk:
          // İstek sınırı (erişim çağrısı / ifade) aşılmış olabilir: yarıla.
          size = (chunk.length + _halves - 1) ~/ _halves;
        case FirebaseFailure(:final error):
          failedChunks++;
          offset = end;
          if (uniformRules && _deterministic.contains(error)) {
            failedChunks += ((valid.length - offset) / size).ceil();
            offset = valid.length;
          }
      }
    }
    return DispatchReport(
      requested: unique.length,
      written: written,
      failedChunks: failedChunks,
    );
  }

  /// Tek parça yazımı [_retry] ile; yazıcının istisnası parçanın hatası olur.
  ///
  /// İlk denemeden sonra gelen `permissionDenied`, önceki denemenin geçici
  /// hatayla dönüp sunucuda kesinleştiği anlamına gelir (aynı kimliklere
  /// ikinci `set` = update → ret): parça yazılmış sayılır.
  Future<FirestoreResult<int>> _writeChunk(
    NotificationDraft draft,
    List<String> chunk,
  ) {
    var attempts = 0;
    return _retry.run(() async {
      attempts++;
      final FirestoreResult<int> result;
      try {
        result = await _writer.createMany(draft, chunk);
      } on Object catch (error) {
        return FirebaseFailure(FirestoreError.unknown, message: '$error');
      }
      final ambiguous =
          attempts > 1 && result.errorOrNull == FirestoreError.permissionDenied;
      if (ambiguous) return FirebaseSuccess(chunk.length);
      return result;
    });
  }

  /// [body] sonucunu döndürür; istisnayı [FirestoreError.unknown]'a çevirir,
  /// başarısızlığı ya da eksik yazımı [_onIssue]'ya iletir.
  Future<FirestoreResult<DispatchReport>> _guard(
    NotificationType type,
    Future<FirestoreResult<DispatchReport>> Function() body,
  ) async {
    FirestoreResult<DispatchReport> result;
    try {
      result = await body();
    } on Object catch (error) {
      result = FirebaseFailure(FirestoreError.unknown, message: '$error');
    }
    final incomplete = switch (result) {
      FirebaseFailure() => true,
      FirebaseSuccess(data: final report) =>
        report.failedChunks > 0 || report.written < report.requested,
    };
    if (incomplete) _onIssue?.call(type, result);
    return result;
  }

  /// [requested] alıcının hiçbirine istemcide yazılmadığını bildiren başarı.
  static FirestoreResult<DispatchReport> _notWritten(int requested) =>
      FirebaseSuccess(
        DispatchReport(requested: requested, written: 0, failedChunks: 0),
      );
}
