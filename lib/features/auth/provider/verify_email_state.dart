import 'package:equatable/equatable.dart';

/// `VerifyEmailViewModel.checkVerified` sonucu. Yönlendirme router'dadır;
/// view bu değere göre gezinmez.
enum VerifyOutcome {
  /// E-posta doğrulanmış: oturum yeniden çözüldü, router yönlendirir
  /// (AUT-05 ya da uygulama kabuğu).
  verified,

  /// E-posta hâlâ doğrulanmamış (TST-02).
  unverified,

  /// Denetlenemedi: çevrimdışı, ağ, süren denetim, oturum çözülemedi, diğer.
  failed,
}

/// AUT-03 "E-postanı doğrula" ekranının durumu (PLAN §12.5).
final class VerifyEmailState extends Equatable {
  /// Varsayılan: adres bilinmiyor, bekleme yok.
  const VerifyEmailState({
    this.email = '',
    this.isChecking = false,
    this.isResending = false,
    this.resendAvailableAt,
    this.lastCheckWasUnverified = false,
    this.isVerified = false,
    this.isError = false,
  });

  /// Doğrulama bağlantısının gönderildiği adres (`AuthUserInfo.email`).
  final String email;

  /// "Doğruladım" denetimi sürüyor mu (düğme meşgul)?
  final bool isChecking;

  /// Doğrulama e-postası yeniden gönderiliyor mu (düğme meşgul)?
  final bool isResending;

  /// "Tekrar gönder"in yeniden açılacağı an (UTC); bekleme yoksa `null`
  /// (`Limits.verificationResendCooldown`). Geri sayım view'da `GuCountdown`
  /// ile saatten türetilir.
  final DateTime? resendAvailableAt;

  /// Son "Doğruladım" denetimi "henüz doğrulanmamış" ile mi bitti (TST-02)?
  final bool lastCheckWasUnverified;

  /// E-posta doğrulandı mı? `true` iken ekran başarı görünümündedir
  /// (onay işareti + "E-postan doğrulandı", düğmeler yok; prototip `f.done`).
  final bool isVerified;

  /// Son işlem (denetim / yeniden gönderme / oturum çözümü) beklenmeyen bir
  /// hatayla mı bitti? Ekran içi hata satırını açar; ağ hatası TST-24'tür.
  final bool isError;

  /// [now] anında "Tekrar gönder" için kalan bekleme; bekleme yoksa ya da
  /// dolduysa [Duration.zero] (hiçbir zaman eksi olmaz).
  Duration remainingResend(DateTime now) {
    final remaining = resendAvailableAt?.difference(now) ?? Duration.zero;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  List<Object?> get props => [
    email,
    isChecking,
    isResending,
    resendAvailableAt,
    lastCheckWasUnverified,
    isVerified,
    isError,
  ];

  /// Verilen alanları değiştirilmiş kopya. [clearResendAvailableAt] bekleme
  /// anını `null` yapar (değerine üstün gelir).
  VerifyEmailState copyWith({
    String? email,
    bool? isChecking,
    bool? isResending,
    DateTime? resendAvailableAt,
    bool clearResendAvailableAt = false,
    bool? lastCheckWasUnverified,
    bool? isVerified,
    bool? isError,
  }) => VerifyEmailState(
    email: email ?? this.email,
    isChecking: isChecking ?? this.isChecking,
    isResending: isResending ?? this.isResending,
    resendAvailableAt: clearResendAvailableAt
        ? null
        : resendAvailableAt ?? this.resendAvailableAt,
    lastCheckWasUnverified:
        lastCheckWasUnverified ?? this.lastCheckWasUnverified,
    isVerified: isVerified ?? this.isVerified,
    isError: isError ?? this.isError,
  );
}
