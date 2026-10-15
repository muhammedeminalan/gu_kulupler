/// Ürün akışı süreleri (iş kuralı; görsel süreler `GuMotion`'dadır).
abstract final class AppDurations {
  /// Bildirimden hedefe gidildikten sonra sheet açılmadan önceki bekleme
  /// (SHT-19 / SHT-26; CD-58, PLAN §15.8).
  static const Duration postNavigationSheetDelay = Duration(milliseconds: 250);

  /// SHT-24 "Geçerli bilet" sonucunun kendiliğinden kapanma süresi; tarama
  /// sonra sürer (prototip `sheets.js:114` `setTimeout(close, 2000)`; T-35,
  /// PLAN §9.8).
  static const Duration qrSuccessAutoClose = Duration(seconds: 2);

  /// MGT-07: aynı QR içeriğinin art arda okunmasının yok sayıldığı süre (son
  /// okumadan ya da SHT-24 kapanıp tarama sürdüğü andan itibaren; bilet
  /// kamerada kalınca yeniden "Zaten okutulmuş" açılmasın). Prototipte
  /// karşılığı yok (kamera simüle); SHT-24 oto-kapanma süresine eşit (T-35).
  static const Duration scanRepeatCooldown = Duration(seconds: 2);

  /// MGT-09: başvuru durumu değiştiğinde TST-21'den sonra TST-54'ün
  /// gösterilme gecikmesi (prototip `screens-manage.js:176`
  /// `setTimeout(() => app.toast('TST-54', …), 1200)`; aynı anda tek toast;
  /// T-36).
  static const Duration applicationsToastDelay = Duration(milliseconds: 1200);
}
