/// AUT-06 yasal metin sekmeleri — `/legal/:tip` yol parametresinin değerleri
/// (navigation.md §2.1; aksiyonlar `AUT-06.tab.<name>`).
///
/// Sıra ekrandaki sekme sırasıdır (`screens-auth.js:156`). Üye adı yoldaki
/// değerdir (`LegalTab.kvkk.name` → `/legal/kvkk`); geçersiz değer rotaya
/// ulaşmadan SYS-04'e yönlenir (`RouteParamGuard`, R12).
///
/// Rota sınıfıyla birlikte `routes/auth_routes.dart` üzerinden de dışa
/// aktarılır: yasal metni açan her feature (giriş, kayıt, katılım başvurusu,
/// hakkında) tek import ile `LegalRoute(tip: LegalTab.kvkk)` yazar.
enum LegalTab {
  /// KVKK aydınlatma metni.
  kvkk,

  /// Gizlilik politikası.
  gizlilik,

  /// Kullanım koşulları.
  kosullar,
}

/// AUT-06'yı açan ekran — `/legal/:tip?from=` sorgu parametresinin değerleri
/// (prototip `app.nav.push('AUT-06', { tab, from: 'register' })`,
/// `screens-auth.js:101`).
///
/// Yalnızca kayıt formu bildirilir: oradan açılan yasal metnin altında
/// "Okudum, anladım" çubuğu çıkar (`AUT-06.accept`, `screens-auth.js:159`).
enum LegalOrigin {
  /// AUT-02 kayıt formunun onay cümlesindeki bağlantılar.
  register,
}
