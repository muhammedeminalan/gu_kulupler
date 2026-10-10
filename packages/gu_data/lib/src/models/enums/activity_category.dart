import 'package:gu_data/src/models/enums/activity_kind.dart';

/// Etkinlik günlüğü kategorisi — MGT-10 süzgeçleri (PLAN §9.7; türetilmiş).
///
/// Firestore'a **yazılmaz**: `ActivityKind.category` ile türden türetilir.
/// Eşleme `design/extracted/registry.json#actCat` ile birebirdir; üye adları
/// registry'deki kategori kodlarıdır.
enum ActivityCategory {
  /// Üyelik (başvuru, katılma, ayrılma, çıkarma, rol).
  membership,

  /// Etkinlik (yayın, iptal).
  event,

  /// İçerik (gönderi, duyuru, anket).
  content,

  /// Kulüp ayarları.
  settings;

  /// Bu kategorideki günlük türleri, [ActivityKind] bildirim sırasıyla.
  ///
  /// `ActivityKind.category` eşlemesinin tersidir (ayrı tablo tutulmaz);
  /// kategori süzgeçli günlük sorgusunun `kind whereIn` kümesidir
  /// (PLAN §10.4 `listActivity`). `ActivityKind.unknown` hiçbir kümede yoktur.
  List<ActivityKind> get kinds => [
    for (final kind in ActivityKind.values)
      if (kind.category == this) kind,
  ];
}
