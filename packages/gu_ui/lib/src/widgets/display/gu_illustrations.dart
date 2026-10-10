/// İllüstrasyon kaydı — `assets/illustrations/<fileName>.svg` (PLAN §7.11).
///
/// 12 çizim; sıra `design/extracted/registry.json#illustrations` ile aynıdır
/// (prototip `art.js:72 ILLUSTRATIONS`). Ad kuralı kebab → camelCase.
/// Renkler varlıkta sabittir: taban `#62748E`, vurgu `#D00A2D`, `#fff`;
/// koyu temada yeniden renklendirme yoktur (K-20).
enum GuIllustrations {
  onbDiscover('onb-discover'),
  onbJoin('onb-join'),
  onbFollow('onb-follow'),
  emptyClubs('empty-clubs'),
  emptyEvents('empty-events'),
  emptyNotifications('empty-notifications'),
  emptyPosts('empty-posts'),
  emptyApplications('empty-applications'),
  error('error'),
  offline('offline'),
  emailVerify('email-verify'),
  locked('locked');

  const GuIllustrations(this.fileName);

  /// `assets/illustrations` altındaki dosya adı (uzantısız, kebab-case).
  final String fileName;

  /// Kök uygulamanın varlık anahtarı (`assets/illustrations/<fileName>.svg`).
  String get assetPath => 'assets/illustrations/$fileName.svg';
}
