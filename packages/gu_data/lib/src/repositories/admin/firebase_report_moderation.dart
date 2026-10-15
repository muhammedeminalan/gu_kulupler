import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gu_data/src/constants/firestore_collections.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/firestore_ids.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/page_request.dart';
import 'package:gu_data/src/core/page_result.dart';
import 'package:gu_data/src/models/enums/report_action.dart';
import 'package:gu_data/src/models/enums/report_status.dart';
import 'package:gu_data/src/models/enums/report_target_type.dart';
import 'package:gu_data/src/models/report_model.dart';
import 'package:gu_data/src/notifications/notification_dispatcher.dart';
import 'package:gu_data/src/repositories/firebase_comment_repository.dart';
import 'package:gu_data/src/repositories/firebase_post_repository.dart';
import 'package:gu_data/src/repositories/report_repository.dart';
import 'package:gu_data/src/repositories/repository_helpers.dart';
import 'package:gu_data/src/services/auth_service.dart';
import 'package:gu_data/src/services/firestore_service.dart';
import 'package:gu_data/src/services/firestore_types.dart';

/// Aynı hedefin şikayet grubu: hedef ve grubun o anki **açık** şikayetleri.
typedef _ReportGroup = ({
  ReportTargetType type,
  String targetId,
  List<ReportModel> open,
});

/// `AdminRepository`'nin şikayet üyeleri (ADM-04, SHT-26, DLG-29 / 30;
/// `docs/plans/T-37.md` §4 a.6, a.8): listeler ve grup çözümü.
///
/// `FirebaseAdminRepository` bu sınıfa tek satırla devreder; imzalar
/// `AdminRepository` ile aynıdır. **Grup** aynı `(targetType, targetId)`
/// hedefinin şikayetleridir (CD-33: 6 neden × 5 hedef); grup anahtarı
/// `FirestoreIds.reportGroupKey`. Bileşik şikayet kimliği parçalanmaz: hedef
/// her zaman belge alanlarından (`targetType`, `targetId`) okunur.
///
/// Çözüm **tek batch**'tir (ya hepsi ya hiçbiri): her açık şikayet
/// `resolved`, `action == removed` ise hedef gönderi / yorum gizlenir
/// (`FirebasePostRepository.addHideToBatch` /
/// `FirebaseCommentRepository.addHideToBatch` — sayaç değişmez) ve her
/// şikayetçiye bir `report_resolved` bildirimi
/// (`NotificationDispatcher.notifyReportResolved`, kritik — W-84) aynı
/// batch'e eklenir. Yazım sayısı `Limits.batchMaxWrites`'ı aşarsa grup
/// parçalanır; gizleme ilk parçadadır. Yarım kalan çözüm yeniden çağrıyla
/// tamamlanır (yalnızca hâlâ açık olanlar okunur).
///
/// Yetki Rules'tadır (`isSuper()` — custom claim, D-28); sınıf claim'i
/// denetlemez. Belge silme yoktur (D-10).
final class FirebaseReportModeration {
  /// `firestore` ile okur ve yazar; oturumdaki aktörü `auth`'tan alır,
  /// gizlemeyi `posts` / `comments` batch üyelerine, bildirimi `dispatcher`'a
  /// bırakır.
  FirebaseReportModeration({
    required this._firestore,
    required this._auth,
    required this._posts,
    required this._comments,
    required this._dispatcher,
  });

  final FirestoreService _firestore;
  final AuthService _auth;
  final FirebasePostRepository _posts;
  final FirebaseCommentRepository _comments;
  final NotificationDispatcher _dispatcher;

  /// Bir şikayetin batch'teki en çok yazımı: şikayet + şikayetçi bildirimi.
  static const int _writesPerReport = 2;

  /// Gizleme yazımı (ilk parçada, yalnızca `removed`).
  static const int _hideWrites = 1;

  /// `AdminRepository.listOpenReports`: açık şikayetlerden bir sayfa, en
  /// yeni üstte (CD-37).
  Future<FirestoreResult<PageResult<ReportModel>>> listOpenReports(
    PageRequest page,
  ) => listReports(ReportStatus.open, page);

  /// `AdminRepository.listReports`: [status] durumundaki şikayetlerden bir
  /// sayfa (`createdAt` azalan; indeks `reports (status, createdAt↓)`).
  Future<FirestoreResult<PageResult<ReportModel>>> listReports(
    ReportStatus status,
    PageRequest page,
  ) async => RepositoryHelpers.parsePage(
    await _firestore.getPage(
      _reports
          .where(FirestoreFields.status, isEqualTo: status.json)
          .orderBy(FirestoreFields.createdAt, descending: true),
      page,
    ),
    _reportOf,
  );

  /// `AdminRepository.listReportsForTarget`: [type] / [targetId] hedefinin
  /// açık şikayetlerinin tamamı (indeks `reports (targetType, targetId,
  /// status)`). Geçersiz [targetId] ağ çağrısı yapılmadan
  /// [FirestoreError.invalidArgument].
  Future<FirestoreResult<List<ReportModel>>> listReportsForTarget({
    required ReportTargetType type,
    required String targetId,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<List<ReportModel>>({
          'targetId': targetId,
        })
        case final rejected?) {
      return rejected;
    }
    return RepositoryHelpers.parseAll(
      await _firestore.getList(
        _reports
            .where(FirestoreFields.targetType, isEqualTo: type.json)
            .where(FirestoreFields.targetId, isEqualTo: targetId)
            .where(FirestoreFields.status, isEqualTo: ReportStatus.open.json),
      ),
      _reportOf,
    );
  }

  /// `AdminRepository.resolveReports`: aynı hedefin açık şikayet grubunu
  /// [action] ile çözer.
  ///
  /// - [target] verilirse grup hedefin **o anki tüm** açık şikayetleridir
  ///   (yeniden okunur); [reportIds] içindeki açık olmayan kimlikler okunur
  ///   ve başka hedefe aitse [FirestoreError.invalidArgument], belgesi yoksa
  ///   [FirestoreError.notFound].
  /// - [target] yoksa [reportIds] tek tek okunur; hepsi aynı hedefte olmalı
  ///   (değilse [FirestoreError.invalidArgument]), açık olmayanlar atlanır.
  ///
  /// Açık şikayet kalmadıysa yazmadan [FirestoreError.conflict]. `removed`
  /// yalnızca `post` / `comment` hedefinde geçerlidir (başkası
  /// [FirestoreError.invalidArgument]); hedef belge okunur, yoksa
  /// [FirestoreError.notFound], zaten gizliyse gizleme yazılmaz (Rules
  /// `isHideToggle` ikinci gizlemeyi reddeder). `suspended` askıyı yazmaz
  /// (çağıran önce `suspendUser` / `suspendClub`), `dismissed` yalnızca
  /// şikayetleri kapatır.
  ///
  /// Oturum yoksa [FirestoreError.unauthenticated]; [actorId] oturumdaki
  /// kullanıcı değilse [FirestoreError.invalidArgument] (Rules
  /// `resolvedBy == uid()`). Geçersiz kimlik ağ çağrısı yapılmadan
  /// [FirestoreError.invalidArgument]. Bir parça başarısız olursa hatası
  /// döner; önceki parçalar kesinleşmiştir.
  Future<FirestoreResult<void>> resolveReports({
    required List<String> reportIds,
    required ReportAction action,
    required String actorId,
    ReportTarget? target,
  }) async {
    final rejected = RepositoryHelpers.rejectInvalidIds<void>({
      'actorId': actorId,
      if (target != null) 'target.id': target.id,
      for (final (index, id) in reportIds.indexed) 'reportIds[$index]': id,
    });
    if (rejected != null) return rejected;
    if (reportIds.isEmpty && target == null) {
      return RepositoryHelpers.invalidArgument('reportIds boş, hedef yok');
    }
    if (target != null && !_canResolve(action, target.type)) {
      return _removedOnlyContent(target.type);
    }
    final session = _auth.currentUser;
    if (session == null) {
      return const FirebaseFailure(
        FirestoreError.unauthenticated,
        message: 'resolveReports: oturum yok',
      );
    }
    if (session.uid != actorId) {
      return RepositoryHelpers.invalidArgument(
        'resolveReports: actorId oturumdaki kullanıcı değil',
      );
    }

    final read = target == null
        ? await _groupOfIds(reportIds)
        : await _groupOfTarget(target.type, target.id, reportIds);
    final _ReportGroup group;
    switch (read) {
      case FirebaseFailure(:final error, :final message, :final detail):
        return FirebaseFailure(error, message: message, detail: detail);
      case FirebaseSuccess(:final data):
        group = data;
    }
    if (group.open.isEmpty) {
      return const FirebaseFailure(
        FirestoreError.conflict,
        message: 'resolveReports: açık şikayet yok',
      );
    }
    if (!_canResolve(action, group.type)) {
      return _removedOnlyContent(group.type);
    }

    var hide = false;
    if (action == ReportAction.removed) {
      switch (await _needsHide(group.type, group.targetId)) {
        case FirebaseFailure(:final error, :final message, :final detail):
          return FirebaseFailure(error, message: message, detail: detail);
        case FirebaseSuccess(:final data):
          hide = data;
      }
    }
    return _commit(group, action: action, actorId: actorId, hide: hide);
  }

  /// [group]'u parça parça (her biri tek batch) çözer; ilk parça [hide]
  /// gizlemesini taşır. Şikayetçi başına tek bildirim: aynı şikayetçi
  /// sonraki parçada yeniden bildirilmez.
  Future<FirestoreResult<void>> _commit(
    _ReportGroup group, {
    required ReportAction action,
    required String actorId,
    required bool hide,
  }) async {
    final groupKey = FirestoreIds.reportGroupKey(
      group.type.json,
      group.targetId,
    );
    final notified = <String>{};
    final chunks = _chunks(
      group.open,
      firstCapacity: Limits.batchMaxWrites - (hide ? _hideWrites : 0),
    );
    for (final (index, chunk) in chunks.indexed) {
      final reporters = [
        for (final report in chunk)
          if (notified.add(report.reporterId)) report.reporterId,
      ];
      final written = await _firestore.commitBatch((batch) {
        if (index == 0 && hide) {
          _addHide(batch, group.type, group.targetId, actorId: actorId);
        }
        for (final report in chunk) {
          batch.update(
            _reportRef(report.id),
            _resolvedPayload(action, actorId),
          );
        }
        if (reporters.isNotEmpty) {
          // Kritik üye eşzamanlıdır; geçersiz girdi çağrı anında fırlar ve
          // batch'in hiçbir yazımı uygulanmaz (sonuç beklenmez).
          unawaited(
            _dispatcher.notifyReportResolved(
              reportGroupKey: groupKey,
              reporterIds: reporters,
              batch: batch,
            ),
          );
        }
      });
      if (written case FirebaseFailure()) return written;
    }
    return const FirebaseSuccess(null);
  }

  /// Hedefi verilmiş grup: hedefin açık şikayetleri yeniden okunur;
  /// [reportIds] içindeki açık olmayan kimliklerin hedefe ait olduğu belge
  /// alanlarıyla doğrulanır.
  Future<FirestoreResult<_ReportGroup>> _groupOfTarget(
    ReportTargetType type,
    String targetId,
    List<String> reportIds,
  ) async {
    final List<ReportModel> open;
    switch (await listReportsForTarget(type: type, targetId: targetId)) {
      case FirebaseFailure(:final error, :final message, :final detail):
        return FirebaseFailure(error, message: message, detail: detail);
      case FirebaseSuccess(:final data):
        open = data;
    }
    final openIds = {for (final report in open) report.id};
    final unknown = reportIds.toSet().difference(openIds).toList();
    switch (await _readReports(unknown)) {
      case FirebaseFailure(:final error, :final message, :final detail):
        return FirebaseFailure(error, message: message, detail: detail);
      case FirebaseSuccess(data: final others):
        if (others.any((r) => r.targetType != type || r.targetId != targetId)) {
          return RepositoryHelpers.invalidArgument(
            'resolveReports: şikayet hedefe ait değil',
          );
        }
    }
    return FirebaseSuccess((type: type, targetId: targetId, open: open));
  }

  /// Hedefsiz grup: [reportIds] okunur, hepsi aynı hedefte olmalıdır;
  /// açık olmayanlar atlanır.
  Future<FirestoreResult<_ReportGroup>> _groupOfIds(
    List<String> reportIds,
  ) async {
    final List<ReportModel> reports;
    switch (await _readReports(reportIds.toSet().toList())) {
      case FirebaseFailure(:final error, :final message, :final detail):
        return FirebaseFailure(error, message: message, detail: detail);
      case FirebaseSuccess(:final data):
        reports = data;
    }
    final first = reports.first;
    if (reports.any(
      (r) => r.targetType != first.targetType || r.targetId != first.targetId,
    )) {
      return RepositoryHelpers.invalidArgument(
        'resolveReports: şikayetler aynı hedefte değil',
      );
    }
    return FirebaseSuccess((
      type: first.targetType,
      targetId: first.targetId,
      open: [
        for (final report in reports)
          if (report.status == ReportStatus.open) report,
      ],
    ));
  }

  /// [ids] şikayetlerini paralel okur (sonuç [ids] sırasında); biri yoksa
  /// [FirestoreError.notFound], biri ayrıştırılamazsa [FirestoreError.parse].
  Future<FirestoreResult<List<ReportModel>>> _readReports(
    List<String> ids,
  ) async {
    final reads = await Future.wait([
      for (final id in ids) _firestore.getDoc(_reportRef(id)),
    ]);
    final reports = <ReportModel>[];
    for (final (index, read) in reads.indexed) {
      switch (RepositoryHelpers.parseOrNull(read, _reportOf)) {
        case FirebaseFailure(:final error, :final message, :final detail):
          return FirebaseFailure(error, message: message, detail: detail);
        case FirebaseSuccess(data: null):
          return FirebaseFailure(
            FirestoreError.notFound,
            message: 'resolveReports: şikayet yok (${ids[index]})',
          );
        case FirebaseSuccess(data: final report?):
          reports.add(report);
      }
    }
    return FirebaseSuccess(reports);
  }

  /// `removed` için hedef gönderi / yorum okunur: yoksa
  /// [FirestoreError.notFound]; zaten gizliyse `false` (gizleme yazılmaz).
  Future<FirestoreResult<bool>> _needsHide(
    ReportTargetType type,
    String targetId,
  ) async {
    final read = await _firestore.getDoc(_contentRef(type, targetId));
    return switch (read) {
      FirebaseFailure(:final error, :final message, :final detail) =>
        FirebaseFailure(error, message: message, detail: detail),
      FirebaseSuccess(data: null) => FirebaseFailure(
        FirestoreError.notFound,
        message: 'resolveReports: hedef içerik yok ($targetId)',
      ),
      FirebaseSuccess(data: final doc?) => FirebaseSuccess(
        doc.data[FirestoreFields.isHidden] != true,
      ),
    };
  }

  /// Gizleme yazımını hedefin repository'sine bırakır (yalnızca `post` /
  /// `comment` — [_canResolve] önceden denetler).
  void _addHide(
    WriteBatch batch,
    ReportTargetType type,
    String targetId, {
    required String actorId,
  }) => type == ReportTargetType.post
      ? _posts.addHideToBatch(batch, targetId, actorId: actorId)
      : _comments.addHideToBatch(batch, targetId, actorId: actorId);

  /// Şikayetin çözüm yazımı (Rules `touches([status, action, resolvedAt,
  /// resolvedBy])` + `updatedAt`).
  Json _resolvedPayload(ReportAction action, String actorId) => {
    FirestoreFields.status: ReportStatus.resolved.json,
    FirestoreFields.action: action.json,
    FirestoreFields.resolvedAt: _firestore.serverTimestamp(),
    FirestoreFields.resolvedBy: actorId,
    ...BaseFieldsPayload.update(),
  };

  /// [reports]'u batch sınırına göre böler; ilk parça [firstCapacity]
  /// yazımla sınırlıdır (gizleme payı düşülmüş).
  static List<List<ReportModel>> _chunks(
    List<ReportModel> reports, {
    required int firstCapacity,
  }) {
    final chunks = <List<ReportModel>>[];
    var size = firstCapacity ~/ _writesPerReport;
    var start = 0;
    while (start < reports.length) {
      final end = math.min(start + size, reports.length);
      chunks.add(reports.sublist(start, end));
      start = end;
      size = Limits.batchMaxWrites ~/ _writesPerReport;
    }
    return chunks;
  }

  /// `removed` yalnızca içerik hedefinde (gönderi / yorum) uygulanır.
  static bool _canResolve(ReportAction action, ReportTargetType type) =>
      action != ReportAction.removed ||
      type == ReportTargetType.post ||
      type == ReportTargetType.comment;

  static FirestoreResult<void> _removedOnlyContent(ReportTargetType type) =>
      RepositoryHelpers.invalidArgument(
        'resolveReports: removed yalnızca post / comment hedefinde '
        '(${type.json})',
      );

  static ReportModel _reportOf(FirestoreDoc doc) =>
      ReportModel.fromJson(doc.data, id: doc.id);

  Query<Json> get _reports =>
      _firestore.collection(FirestoreCollections.reports);

  DocumentReference<Json> _reportRef(String reportId) =>
      _firestore.doc(FirestoreCollections.reports, reportId);

  DocumentReference<Json> _contentRef(ReportTargetType type, String id) =>
      _firestore.doc(
        type == ReportTargetType.post
            ? FirestoreCollections.posts
            : FirestoreCollections.comments,
        id,
      );
}
