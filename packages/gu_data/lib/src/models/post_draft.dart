import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:gu_data/src/models/enums/post_type.dart';
import 'package:gu_data/src/models/post_image_model.dart';

/// Henüz yayınlanmamış gönderi (PLAN §10.4 `PostRepository.create`).
///
/// Yalnızca yazarın girdiği alanları taşır; kimlik, yazar, kulüp, sayaçlar ve
/// zaman alanları yayın anında repository tarafından kurulur. Tür kuralları
/// (`FieldValidators.postText / postTitle / postPoll / pushSent`):
/// duyuruda [title] zorunludur, diğer türlerde `null`; [poll] yalnızca
/// ankette doludur (soru [text] alanındadır); [pushSent] yalnızca duyuruda
/// anlam taşır.
final class PostDraft extends Equatable {
  /// [type] türünde gönderi taslağı.
  const PostDraft({
    required this.type,
    required this.text,
    this.title,
    this.images = const [],
    this.poll,
    this.pushSent = false,
  });

  /// Gönderi türü.
  final PostType type;

  /// Duyuru başlığı (1 – `Limits.postTitleMax`); diğer türlerde `null`.
  final String? title;

  /// Gönderi metni (1 – `Limits.postTextMax`); ankette soru.
  final String text;

  /// Önceden yüklenmiş görseller (≤ `Limits.postImagesMax`); her yol
  /// `StoragePaths.postImage(postId, file)` biçimindedir (CD-39).
  final List<PostImageModel> images;

  /// Anket; yalnızca `type == PostType.poll` iken dolu.
  final PollDraft? poll;

  /// Duyuru bildirimle mi yayınlansın? Günlük duyuru hakkından düşer
  /// (domain-model §7). Duyuru dışındaki türlerde yok sayılır (`false`
  /// yazılır).
  final bool pushSent;

  @override
  List<Object?> get props => [type, title, text, images, poll, pushSent];
}

/// Henüz yayınlanmamış anket (PLAN §10.4 `PostDraft.poll`).
///
/// Seçenek kimlikleri (`o1`–`o4`, `FirestoreIds.pollOption`) ve bitiş anı
/// (`nowUtc + durationDays`) yayın anında repository tarafından üretilir.
final class PollDraft extends Equatable {
  /// [options] metinleriyle, [durationDays] gün açık kalacak anket.
  const PollDraft({
    required this.options,
    required this.durationDays,
    this.showResultsAfterVote = true,
  });

  /// Seçenek metinleri, gösterim sırasıyla (`Limits.pollOptionsMin` –
  /// `Limits.pollOptionsMax` adet; her biri 1 – `Limits.pollOptionTextMax`).
  final List<String> options;

  /// Anketin açık kalacağı gün sayısı (`Limits.pollDurationsDays`).
  final int durationDays;

  /// Sonuçlar yalnızca oy verdikten (ya da anket kapandıktan) sonra mı
  /// görünsün?
  final bool showResultsAfterVote;

  @override
  List<Object?> get props => [options, durationDays, showResultsAfterVote];
}

/// Yayınlanmış gönderide yazarın değiştirebildiği alanların yaması (PLAN
/// §10.4 `PostRepository.update`; rules-spec §3.5 U).
///
/// Yalnızca **verilen** alanlar yazılır; verilmeyen alan belgede olduğu gibi
/// kalır. Tür, anket (seçenekler, bitiş), bildirim bayrağı, sabitleme ve
/// sayaçlar bu yamayla **değiştirilemez** (tipte yoktur; Rules da reddeder).
/// [title] yalnızca duyuruda verilir ve boşaltılamaz.
final class PostEditPatch extends Equatable {
  /// Verilen alanları taşıyan yama.
  const PostEditPatch({this.text, this.title, this.images});

  /// Yeni metin (1 – `Limits.postTextMax`).
  final String? text;

  /// Yeni duyuru başlığı (1 – `Limits.postTitleMax`); yalnızca duyuruda.
  final String? title;

  /// Yeni görsel listesi (≤ `Limits.postImagesMax`; yollar gönderinin kendi
  /// klasöründe — CD-39). Boş liste görselleri kaldırır.
  final List<PostImageModel>? images;

  /// Yama hiçbir alan taşımıyor mu?
  bool get isEmpty => text == null && title == null && images == null;

  @override
  List<Object?> get props => [text, title, images];
}

/// Yüklenmeyi bekleyen gönderi görseli (`PostRepository.uploadImages`
/// girdisi; T-21, CD-39).
///
/// [bytes] **yeniden kodlanmış** görseldir (uygulamanın görsel seçicisinin
/// çıktısı — EXIF ayıklanmış, CD-135); özgün kamera / galeri dosyası buraya
/// verilmez. [width] ve [height] yeniden kodlanmış görselin piksel boyutudur
/// ve yüklenen görselin modeline (`PostImageModel.w / h`) aynen yazılır.
///
/// Eşitlik kimlikledir (megabaytlarca bayt karşılaştırılmaz).
final class PostImageUpload {
  /// [contentType] türünde, [width] × [height] piksel görsel.
  const PostImageUpload({
    required this.bytes,
    required this.contentType,
    required this.width,
    required this.height,
  });

  /// Yeniden kodlanmış görselin baytları (boş değil,
  /// `Limits.imageMaxBytes` sınırının altında).
  final Uint8List bytes;

  /// İçerik türü (`StoragePaths.extensionByContentType` anahtarı).
  final String contentType;

  /// Genişlik, piksel (≥ 1).
  final int width;

  /// Yükseklik, piksel (≥ 1).
  final int height;

  @override
  String toString() =>
      'PostImageUpload($contentType, $width×$height, ${bytes.length} bayt)';
}
