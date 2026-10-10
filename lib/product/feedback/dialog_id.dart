/// Dialog kimlikleri — `registry.json#dialogs` (32).
///
/// Her üyenin üstündeki `/// Design: DLG-nn` izi `tool/check_design_coverage.js`
/// KAT01–KAT04 ile doğrulanır. Açılış tek girişten:
/// `FeedbackService.showDialog(DialogId.dlgNN, …)` (CLAUDE.md §7).
enum DialogId {
  /// Design: DLG-01 — Hesabın askıya alındı
  dlg01,

  /// Design: DLG-02 — Çok fazla deneme
  dlg02,

  /// Design: DLG-03 — Bildirimleri açalım mı?
  dlg03,

  /// Design: DLG-04 — Kamera erişimi
  dlg04,

  /// Design: DLG-05 — Fotoğraflarına erişim
  dlg05,

  /// Design: DLG-06 — Çıkış yapılsın mı?
  dlg06,

  /// Design: DLG-07 — İsteği iptal et?
  dlg07,

  /// Design: DLG-08 — Kulüpten ayrıl?
  dlg08,

  /// Design: DLG-09 — Ayrılamazsın
  dlg09,

  /// Design: DLG-10 — Gönderi silinsin mi?
  dlg10,

  /// Design: DLG-11 — Yorum silinsin mi?
  dlg11,

  /// Design: DLG-12 — Şikayetin alındı
  dlg12,

  /// Design: DLG-13 — {name} engellensin mi?
  dlg13,

  /// Design: DLG-14 — Katılımdan vazgeç?
  dlg14,

  /// Design: DLG-15 — Kontenjan doldu
  dlg15,

  /// Design: DLG-16 — Etkinlik iptal edildi
  dlg16,

  /// Design: DLG-17 — Toplu işlem onayı
  dlg17,

  /// Design: DLG-18 — Başvuru zaten sonuçlandırıldı
  dlg18,

  /// Design: DLG-19 — {name} çıkarılsın mı?
  dlg19,

  /// Design: DLG-20 — Rol değişsin mi?
  dlg20,

  /// Design: DLG-21 — Başkanlığı devret?
  dlg21,

  /// Design: DLG-22 — Etkinlik yayınlansın mı?
  dlg22,

  /// Design: DLG-23 — Etkinlik iptal edilsin mi?
  dlg23,

  /// Design: DLG-24 — Bugünkü duyuru hakkın doldu
  dlg24,

  /// Design: DLG-25 — Değişiklikler kaydedilmedi
  dlg25,

  /// Design: DLG-26 — Güncelleme gerekli
  dlg26,

  /// Design: DLG-27 — Oturumun sona erdi
  dlg27,

  /// Design: DLG-28 — {club} askıya alınsın mı?
  dlg28,

  /// Design: DLG-29 — İçerik kaldırılsın mı?
  dlg29,

  /// Design: DLG-30 — {name} askıya alınsın mı?
  dlg30,

  /// Design: DLG-31 — Taslak silinsin mi?
  dlg31,

  /// Design: DLG-32 — Uygulamadan ayrılıyorsun
  dlg32;

  /// Tasarım kimliği (`DLG-nn`; `design/extracted/registry.json`).
  String get designId => 'DLG-${name.substring(3)}';
}
