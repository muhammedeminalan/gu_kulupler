import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/widget/post/image_grid.dart';
import 'package:gu_kulupler/product/widget/post/image_viewer.dart';

/// "Görsel" — gönderi görsellerinin tam ekran görüntüleyicisi (prototip
/// `SHEETS['SHT-34']`, `sheets.js:155–162`). FED-01 ve FED-02 `ImageGrid`
/// hücresinden açılır; gövde `ImageViewer`'dır.
///
/// * [images] gönderinin görselleri, [initialIndex] dokunulan hücre, [club]
///   yer tutucu deseninin kaynağı.
/// * "Paylaş" [onShare]'dir (çağıran `PostActionsMixin.sharePost` → SHT-15).
///   X, aşağı sürükleme ve geri sayfayı kapatır (`pop`); sonuç değeri yoktur.
/// * Tam ekrandır: overlay içeriği sınırsız yükseklikte ölçüldüğü için
///   yüksekliği ekrandan alır; scrim görünmez (`SHT-34.scrim` boş banttır).
///   `GuSheetFrame` kullanmaz (css:409 `.viewer`).
/// * Anahtarlar `SHT-34.close`, `SHT-34.share`, `SHT-34.swipe`,
///   `SHT-34.zoom.<index>`.
///
/// ```dart
/// await feedback.showSheet<void>(
///   SheetId.sht34,
///   builder: (_) => ImageViewerSheet(
///     images: post.images,
///     initialIndex: index,
///     club: club,
///     onShare: () => viewModel.sharePost(post.id),
///   ),
/// );
/// ```
///
/// Design: SHT-34
class ImageViewerSheet extends StatelessWidget {
  /// [images] görsellerini [initialIndex] sayfasından açar.
  const ImageViewerSheet({
    required this.images,
    this.initialIndex = 0,
    this.club,
    this.onShare,
    this.imageOf,
    super.key,
  });

  /// Gösterilen görseller.
  final List<PostImageModel> images;

  /// İlk açılan sayfa (0'dan).
  final int initialIndex;

  /// Yer tutucu deseninin paleti / deseni.
  final ClubModel? club;

  /// Paylaş → SHT-15.
  final VoidCallback? onShare;

  /// Görsel çözücü; `null` → sayfalar yer tutucu (K-18).
  final PostImageResolver? imageOf;

  /// Kapat düğmesinin anahtarı (`SHT-34.close`).
  static final Key closeKey = FeedbackKeys.of(SheetId.sht34.designId, 'close');

  /// Paylaş düğmesinin anahtarı (`SHT-34.share`).
  static final Key shareKey = FeedbackKeys.of(SheetId.sht34.designId, 'share');

  /// Sayfalayıcının anahtarı (`SHT-34.swipe`).
  static final Key swipeKey = FeedbackKeys.of(SheetId.sht34.designId, 'swipe');

  /// [index] sayfasının anahtarı (`SHT-34.zoom.<index>`).
  static Key zoomKey(int index) =>
      FeedbackKeys.of(SheetId.sht34.designId, 'zoom.$index');

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height,
    child: ImageViewer(
      images: images,
      initialIndex: initialIndex,
      club: club,
      onClose: () => Navigator.of(context).pop(),
      onShare: onShare,
      closeKey: closeKey,
      shareKey: shareKey,
      swipeKey: swipeKey,
      zoomKey: zoomKey,
      imageOf: imageOf,
    ),
  );
}
