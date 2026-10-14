/// Bilet okutmanın sonucu (PLAN §10.4 `AttendanceRepository.scanTicket`;
/// türetilmiş, kalıcı değil).
///
/// Firestore'a **yazılmaz**: okutma ekranı (MGT-07 → SHT-24) bu değere göre
/// geri bildirim seçer.
enum ScanOutcome {
  /// Bilet geçerliydi: katılım `going → attended` oldu.
  valid,

  /// Bilet daha önce okutulmuş (katılım zaten `attended`); yazım yapılmadı.
  alreadyScanned,

  /// QR yükü çözülemedi, başka etkinliğe ait, kayıt yok / `cancelled`, ya da
  /// kod kopyalanmış (iki kayıt aynı kodu taşıyor — W-79); yazım yapılmadı.
  invalid,
}
