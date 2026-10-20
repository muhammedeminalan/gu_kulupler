import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gu_data/src/constants/firestore_collections.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/firestore_ids.dart';
import 'package:gu_data/src/core/app_clock.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/models/comment_model.dart';
import 'package:gu_data/src/notifications/notification_dispatcher.dart';
import 'package:gu_data/src/repositories/comment_repository.dart';
import 'package:gu_data/src/repositories/query_x.dart';
import 'package:gu_data/src/repositories/repository_helpers.dart';
import 'package:gu_data/src/services/firestore_service.dart';
import 'package:gu_data/src/services/firestore_types.dart';
import 'package:gu_data/src/utils/field_validators.dart';

/// [CommentRepository] uygulaması: `comments/{commentId}` (PLAN §10.4).
///
/// Yorumun yazımı, kaldırılması ve geri yüklenmesi **tek batch**'tir: yorum
/// belgesi ile gönderinin `commentCount` deltası ve `lastCommentRef`
/// işaretçisi birlikte işlenir (ya hepsi ya hiçbiri). Üç yazım da **kördür**
/// — önce okuma yapılmaz; gönderinin silinmiş / gizlenmiş olması, yorumun
/// zaten kaldırılmış olması ve çağıranın yetkisi (yazar, kulüp yönetimi,
/// süper admin) Security Rules'ta denetlenir, repository aktöre göre dallanmaz.
final class FirebaseCommentRepository implements CommentRepository {
  /// [_firestore] servisi üzerinden okur ve yazar; [add] sonucundaki yaklaşık
  /// zaman alanlarını [_clock] saatinden alır. [_notifications] verilirse yeni
  /// yorum gönderi sahibine ve o gönderide yorum yapanlara bildirilir
  /// (`comment_new`, H-25; en iyi çaba — yorumun sonucunu etkilemez).
  FirebaseCommentRepository(
    this._firestore,
    this._clock, [
    this._notifications,
  ]);

  final FirestoreService _firestore;
  final AppClock _clock;
  final NotificationDispatcher? _notifications;

  /// Yeni yorum bildiriminde okunan en çok önceki yorum (alıcı adayı).
  static const int _commentersScanMax = 200;

  /// `commentCount` deltası: yorum yazıldı ya da geri yüklendi.
  static const int _added = 1;

  /// `commentCount` deltası: yorum kaldırıldı.
  static const int _removed = -1;

  @override
  Future<FirestoreResult<CommentModel>> add({
    required String postId,
    required String clubId,
    required String authorId,
    required String text,
  }) async {
    final rejected =
        RepositoryHelpers.rejectInvalidIds<CommentModel>({
          'postId': postId,
          'clubId': clubId,
          'authorId': authorId,
        }) ??
        RepositoryHelpers.rejectInvalidFields<CommentModel>({
          FirestoreFields.text: FieldValidators.comment(text),
        });
    if (rejected != null) return rejected;

    // Model varsayılanları: `isHidden: false`. `null` alanların (`hiddenBy`,
    // `hiddenAt`) anahtarı yazılmaz (W-51).
    final comment = CommentModel(
      postId: postId,
      clubId: clubId,
      authorId: authorId,
      text: text,
    );
    final commentId = _firestore.newId(FirestoreCollections.comments);
    final now = _clock.nowUtc();
    final written = await _firestore.commitBatch((batch) {
      batch
        ..set(_commentRef(commentId), {
          ...comment.toJson(),
          ...BaseFieldsPayload.create(),
        })
        ..update(_postRef(postId), _counterPayload(commentId, _added));
    });
    if (written.isSuccess && _notifications != null) {
      unawaited(
        _notifyCommentNew(
          postId: postId,
          clubId: clubId,
          commentId: commentId,
          authorId: authorId,
        ),
      );
    }
    return written.map(
      (_) => comment.copyWith(id: commentId, createdAt: now, updatedAt: now),
    );
  }

  /// `comment_new` alıcıları: gönderi sahibi + bu gönderide yorum yapanlar
  /// (yorumcu hariç). Okuma ya da yazım hatası günlüğe bile çıkmaz; yorum
  /// zaten yazılmıştır.
  Future<void> _notifyCommentNew({
    required String postId,
    required String clubId,
    required String commentId,
    required String authorId,
  }) async {
    final notifications = _notifications;
    if (notifications == null) return;
    final recipients = <String>{};
    final post = await _firestore.getDoc(_postRef(postId));
    if (post.dataOrNull?.data[FirestoreFields.authorId]
        case final String postAuthor) {
      recipients.add(postAuthor);
    }
    final others = await _firestore.getList(
      _firestore
          .collection(FirestoreCollections.comments)
          .where(FirestoreFields.postId, isEqualTo: postId)
          .where(FirestoreFields.clubId, isEqualTo: clubId)
          .notDeleted()
          .where(FirestoreFields.isHidden, isEqualTo: false)
          .orderBy(FirestoreFields.createdAt, descending: true)
          .limit(_commentersScanMax),
    );
    for (final doc in others.dataOrNull ?? const <FirestoreDoc>[]) {
      if (doc.data[FirestoreFields.authorId] case final String commenter) {
        recipients.add(commenter);
      }
    }
    recipients.remove(authorId);
    if (recipients.isEmpty) return;
    await notifications.notifyCommentNew(
      postId: postId,
      clubId: clubId,
      commentId: commentId,
      recipients: recipients.toList(),
    );
  }

  @override
  Future<FirestoreResult<void>> softDeleteComment(
    String commentId, {
    required String postId,
    required String actorId,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({
          'commentId': commentId,
          'postId': postId,
          'actorId': actorId,
        })
        case final rejected?) {
      return rejected;
    }
    return _firestore.commitBatch((batch) {
      // Batch kipindeki yazımın hatası batch'i geçersiz kılar (sayaç tek
      // başına işlenmez); sonucu burada beklenmez.
      unawaited(
        _firestore.softDelete(
          _commentRef(commentId),
          actorId: actorId,
          batch: batch,
        ),
      );
      batch.update(_postRef(postId), _counterPayload(commentId, _removed));
    });
  }

  @override
  Future<FirestoreResult<void>> restoreComment(
    String commentId, {
    required String postId,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({
          'commentId': commentId,
          'postId': postId,
        })
        case final rejected?) {
      return rejected;
    }
    return _firestore.commitBatch((batch) {
      unawaited(_firestore.restore(_commentRef(commentId), batch: batch));
      batch.update(_postRef(postId), _counterPayload(commentId, _added));
    });
  }

  @override
  Stream<FirestoreResult<List<CommentModel>>> watchComments(
    String postId, {
    required String clubId,
  }) {
    if (RepositoryHelpers.rejectInvalidIds<List<CommentModel>>({
          'postId': postId,
          'clubId': clubId,
        })
        case final rejected?) {
      return Stream.value(rejected);
    }
    // Sorgu sözleşmesi (rules-spec §6, FED-02): gönderi + kulüp + silinmemiş
    // + gizli değil, eskiden yeniye. Engellenen yazarlar burada süzülmez.
    return _firestore
        .watchList(
          _firestore
              .collection(FirestoreCollections.comments)
              .where(FirestoreFields.postId, isEqualTo: postId)
              .where(FirestoreFields.clubId, isEqualTo: clubId)
              .notDeleted()
              .where(FirestoreFields.isHidden, isEqualTo: false)
              .orderBy(FirestoreFields.createdAt),
        )
        .map((event) => RepositoryHelpers.parseAll(event, _commentOf));
  }

  @override
  Future<FirestoreResult<CommentModel>> getComment(String commentId) async {
    if (RepositoryHelpers.rejectInvalidIds<CommentModel>({
          'commentId': commentId,
        })
        case final rejected?) {
      return rejected;
    }
    final ref = _commentRef(commentId);
    // Silinmiş belge `parseOrNull` içinde "bulunamadı" olur; gizlenmiş yorum
    // (Rules okumaya izin verdiyse) döner.
    return switch (RepositoryHelpers.parseOrNull(
      await _firestore.getDoc(ref),
      _commentOf,
    )) {
      FirebaseSuccess(data: final comment?) => FirebaseSuccess(comment),
      FirebaseSuccess() => FirebaseFailure(
        FirestoreError.notFound,
        message: '${ref.path}: yok',
      ),
      FirebaseFailure(:final error, :final message, :final detail) =>
        FirebaseFailure(error, message: message, detail: detail),
    };
  }

  @override
  Future<FirestoreResult<void>> hide(
    String commentId, {
    required String actorId,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({
          'commentId': commentId,
          'actorId': actorId,
        })
        case final rejected?) {
      return rejected;
    }
    // Sayaç ve işaretçi değişmez: `commentCount` silinmemiş yorumları sayar.
    return _firestore.update(_commentRef(commentId), _hidePayload(actorId));
  }

  /// [hide]'ın batch karşılığı (T-37, şikayet çözümü "kaldırıldı" —
  /// `AdminRepository.resolveReports`): [commentId] yorumunun gizleme
  /// yazımını (`isHidden: true`, `hiddenBy: actorId`, `hiddenAt` +
  /// `updatedAt` sunucu zamanı) [batch]'e **eşzamanlı** ekler; commit ve ağ
  /// çağrısı yoktur. Arayüzde değildir (SDK tipi `WriteBatch` arayüze
  /// sızmaz); yalnızca `gu_data` içindeki çözüm sınıfı çağırır.
  ///
  /// Kimlikleri çağıran önceden doğrular; geçersiz [commentId]
  /// `ArgumentError` fırlatır ve `commitBatch` batch'i düşürür.
  /// `commentCount` ve `lastCommentRef` değişmez; Rules (`isHideToggle`)
  /// yorum zaten gizliyse yazımı reddeder — çağıran önce okur.
  void addHideToBatch(
    WriteBatch batch,
    String commentId, {
    required String actorId,
  }) => batch.update(_commentRef(commentId), {
    ..._hidePayload(actorId),
    ...BaseFieldsPayload.update(),
  });

  /// Gizleme yazımının alanları ([hide] ve [addHideToBatch] ortak yükü).
  Json _hidePayload(String actorId) => {
    FirestoreFields.isHidden: true,
    FirestoreFields.hiddenBy: actorId,
    FirestoreFields.hiddenAt: _firestore.serverTimestamp(),
  };

  /// Gönderinin sayaç yazımı: `commentCount` [delta] kadar değişir,
  /// `lastCommentRef` sayacı değiştiren [commentId] yorumunu gösterir
  /// (Security Rules yorumun geçişini bu işaretçiyle eşler — CD-41).
  static Json _counterPayload(String commentId, int delta) => {
    FirestoreFields.commentCount: FieldValue.increment(delta),
    FirestoreFields.lastCommentRef: FirestoreIds.commentRef(commentId),
    ...BaseFieldsPayload.update(),
  };

  static CommentModel _commentOf(FirestoreDoc doc) =>
      CommentModel.fromJson(doc.data, id: doc.id);

  DocumentReference<Json> _commentRef(String commentId) =>
      _firestore.doc(FirestoreCollections.comments, commentId);

  DocumentReference<Json> _postRef(String postId) =>
      _firestore.doc(FirestoreCollections.posts, postId);
}
