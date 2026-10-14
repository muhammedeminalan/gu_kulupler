import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-16'da seçilen eylem — sayfanın `pop` değeri.
enum PhotoSourceChoice {
  /// "Kamera" (`SHT-16.camera`): çağıran kamera iznini (DLG-04) sorar ve
  /// çekimi başlatır.
  camera('camera'),

  /// "Galeri" (`SHT-16.gallery`): çağıran ön açıklamayı (DLG-05) gösterir ve
  /// sistem seçicisini açar (CD-16).
  gallery('gallery'),

  /// "Fotoğrafı kaldır" (`SHT-16.remove`): çağıran mevcut görseli kaldırır.
  remove('remove');

  const PhotoSourceChoice(this.action);

  /// Aksiyon adı (`SHT-16.<action>`).
  final String action;
}

/// SHT-16 "Fotoğraf kaynağı" — kamera / galeri / kaldır menüsü (prototip
/// `SHEETS['SHT-16']`, `sheets.js:78–82`). AUT-05, PRF-02, FED-03, MGT-09,
/// SET-05 açar.
///
/// * Çerçeve menü biçimindedir (`menu`, `flush`); satırlar `GuTile` + 22 dp
///   ikon: "Kamera" (`camera`), "Galeri" (`images`) ve yalnızca [hasPhoto]
///   iken "Fotoğrafı kaldır" (`trash-2`, yıkıcı).
/// * Dokunma sayfayı seçimle kapatır (`pop(PhotoSourceChoice)`); X / scrim /
///   sürükleme / geri → `null`. İzin dialogları, seçici, yükleme ve TST-57
///   çağıranın (ViewModel) işidir — sayfa yalnızca kaynağı sorar.
/// * Prototipteki örnek görsel ızgarası (`DEMO_IMAGES`, `SHT-16.image.*`,
///   `SHT-16.add`) mock'tur; gerçek uygulamada yerini sistem galeri seçicisi
///   alır (CD-16) ve çizilmez.
/// * Anahtarlar `SHT-16.camera`, `SHT-16.gallery`, `SHT-16.remove`,
///   `SHT-16.close` (+ `SHT-16.scrim`, `FeedbackService`).
///
/// ```dart
/// final choice = await feedback.showSheet<PhotoSourceChoice>(
///   SheetId.sht16,
///   builder: (_) => const PhotoSourceSheet(),
/// );
/// ```
///
/// Design: SHT-16
class PhotoSourceSheet extends StatelessWidget {
  /// Fotoğraf kaynağı; [hasPhoto] `true` ise "Fotoğrafı kaldır" da çizilir.
  const PhotoSourceSheet({
    this.hasPhoto = false,
    this.maxImages = 1,
    super.key,
  }) : assert(maxImages >= 1, 'maxImages en az 1 olmalı.');

  /// Kaldırılabilecek bir görsel var mı (prototip `props.hasPhoto`).
  final bool hasPhoto;

  /// Galeriden seçilebilecek en çok görsel (prototip `props.max`). Profil
  /// fotoğrafında hep 1'dir; FED-03 kalan görsel hakkını verir (sınır
  /// dolmuşsa sayfa açılmaz, TST-X5 gösterilir). Seçici her açılışta tek
  /// görsel verir (CD-143).
  final int maxImages;

  /// [choice] satırının anahtarı (`SHT-16.<action>`).
  static Key keyOf(PhotoSourceChoice choice) =>
      FeedbackKeys.of(SheetId.sht16.designId, choice.action);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.gu.colors;

    Widget row(
      PhotoSourceChoice choice, {
      required GuIcons icon,
      required String label,
      bool danger = false,
    }) => GuTile(
      key: keyOf(choice),
      title: label,
      danger: danger,
      leading: GuIcon(
        icon,
        size: GuSizes.icon22,
        color: danger ? colors.stateDanger : colors.textHeading,
      ),
      onTap: () => Navigator.of(context).pop(choice),
    );

    return GuSheetFrame(
      title: l10n.sht16Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: FeedbackKeys.of(SheetId.sht16.designId, 'close'),
      menu: true,
      flush: true,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(
            PhotoSourceChoice.camera,
            icon: GuIcons.camera,
            label: l10n.sht16Camera,
          ),
          row(
            PhotoSourceChoice.gallery,
            icon: GuIcons.images,
            label: l10n.sht16Gallery,
          ),
          if (hasPhoto)
            row(
              PhotoSourceChoice.remove,
              icon: GuIcons.trash2,
              label: l10n.sht16Remove,
              danger: true,
            ),
        ],
      ),
    );
  }
}
