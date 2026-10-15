import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';

/// SHT-26 hedef önizlemesi (prototip `preview()`, `sheets.js:124`): grubun
/// hedef belgesi — türüne göre en çok biri dolu — ve gönderi / yorum
/// yazarı.
///
/// Hepsi `null` → hedef yok / silinmiş ("Bu içerik kaldırılmış",
/// [isMissing]). Okuma `AdminReportsViewModel.openGroup`'tadır (T-40).
final class ReportTargetPreview extends Equatable {
  /// Hedef önizlemesi.
  const ReportTargetPreview({
    this.post,
    this.comment,
    this.user,
    this.club,
    this.event,
    this.author,
  });

  /// Gönderi hedefi.
  final PostModel? post;

  /// Yorum hedefi.
  final CommentModel? comment;

  /// Kullanıcı hedefi.
  final UserModel? user;

  /// Kulüp hedefi; gönderi hedefinde gönderinin kulübü (`PostCard`
  /// başlığı — hedef türü [post] ile belirlenir).
  final ClubModel? club;

  /// Etkinlik hedefi.
  final EventModel? event;

  /// Gönderi / yorum yazarı (yorum önizlemesi; yoksa `null`).
  final UserModel? author;

  /// Hedef belge okunamadı / silinmiş.
  bool get isMissing =>
      post == null &&
      comment == null &&
      user == null &&
      club == null &&
      event == null;

  /// "Kullanıcıyı askıya al" (DLG-30) hedefi: gönderi / yorum yazarı ya da
  /// kullanıcı hedefi; yoksa `null` (prototip `authorId`).
  String? get suspendableUserId =>
      post?.authorId ?? comment?.authorId ?? user?.uid;

  @override
  List<Object?> get props => [post, comment, user, club, event, author];
}
