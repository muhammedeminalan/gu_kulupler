/// Alt sayfa kimlikleri — `registry.json#sheets` (34).
///
/// Her üyenin üstündeki `/// Design: SHT-nn` izi `tool/check_design_coverage.js`
/// KAT01–KAT04 ile doğrulanır. Açılış tek girişten:
/// `FeedbackService.showSheet(SheetId.shtNN, builder: …)` (CLAUDE.md §7).
enum SheetId {
  /// Design: SHT-01 — Dil
  sht01,

  /// Design: SHT-02 — Bölüm seç
  sht02,

  /// Design: SHT-03 — Sınıf seç
  sht03,

  /// Design: SHT-04 — Filtre ve sıralama
  sht04,

  /// Design: SHT-05 — Katılma başvurusu
  sht05,

  /// Design: SHT-06 — Kulüp menüsü
  sht06,

  /// Design: SHT-07 — Kulüp bildirimleri
  sht07,

  /// Design: SHT-08 — Gönderi
  sht08,

  /// Design: SHT-09 — Yorumlar
  sht09,

  /// Design: SHT-10 — Şikayet nedeni
  sht10,

  /// Design: SHT-11 — Etkinlik filtresi
  sht11,

  /// Design: SHT-12 — Katılım onayı
  sht12,

  /// Design: SHT-13 — Hatırlatıcı
  sht13,

  /// Design: SHT-14 — Takvime ekle
  sht14,

  /// Design: SHT-15 — Paylaş
  sht15,

  /// Design: SHT-16 — Fotoğraf kaynağı
  sht16,

  /// Design: SHT-17 — Tema
  sht17,

  /// Design: SHT-18 — Yönetilen kulüp seç
  sht18,

  /// Design: SHT-19 — Başvuru detayı
  sht19,

  /// Design: SHT-20 — Red nedeni
  sht20,

  /// Design: SHT-21 — Üye işlemleri
  sht21,

  /// Design: SHT-22 — Rol seç
  sht22,

  /// Design: SHT-23 — Etkinlik menüsü
  sht23,

  /// Design: SHT-24 — Tarama sonucu
  sht24,

  /// Design: SHT-25 — Başkan ata
  sht25,

  /// Design: SHT-26 — Şikayet detayı
  sht26,

  /// Design: SHT-27 — Kullanıcı
  sht27,

  /// Design: SHT-28 — Tarih seç
  sht28,

  /// Design: SHT-29 — Saat seç
  sht29,

  /// Design: SHT-30 — Mekân seç
  sht30,

  /// Design: SHT-31 — Kapak seç
  sht31,

  /// Design: SHT-32 — Şifre değiştir
  sht32,

  /// Design: SHT-33 — Kategori seç
  sht33,

  /// Design: SHT-34 — Görsel
  sht34;

  /// Tasarım kimliği (`SHT-nn`; `design/extracted/registry.json`).
  String get designId => 'SHT-${name.substring(3)}';
}
