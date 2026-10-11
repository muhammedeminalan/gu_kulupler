import 'package:gu_data/src/core/auth_error.dart';
import 'package:gu_data/src/core/auth_failure_detail.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/services/auth_service.dart';

/// Kimlik işlemlerinin alan dili (PLAN §10.4; Q-04, D-27, D-28).
///
/// `AuthService`'in üstüne uygulama kurallarını koyar: e-posta alan adı
/// kısıtı (D-27), şifre politikası, hatalı giriş kilidi (`LoginThrottle`),
/// doğrulama e-postası bekleme süresi ve süper admin claim'i. ViewModel
/// kimlik için yalnızca bu arayüzü kullanır. Sonuç döndüren hiçbir metot
/// istisna fırlatmaz.
///
/// E-posta girdileri baştaki/sondaki boşluktan arındırılarak işlenir.
/// Hesap silme burada **yoktur** (D-10, Q-11): `AccountDeletionRepository`.
abstract interface class AuthRepository {
  /// Oturum açılış/kapanışlarını yayınlar (dinleyene önce güncel durum
  /// gelir). Tek dinleyicisi `SessionViewModel`'dir.
  Stream<AuthUserInfo?> watchAuthState();

  /// Oturumdaki kullanıcı; oturum yoksa `null`.
  AuthUserInfo? get currentUser;

  /// Oturumu geçersiz kılan hatalar ([AuthError.sessionExpired],
  /// [AuthError.userDisabled]); `AuthService.tokenErrors` köprüsüdür
  /// (DLG-27, DLG-01). Yayın akışıdır.
  Stream<AuthError> get tokenErrors;

  /// Yeni hesap açar ve doğrulama e-postasını gönderir; oturum açılmış
  /// (doğrulanmamış) olarak döner.
  ///
  /// SDK'ya gidilmeden reddedilenler: biçimi bozuk adres →
  /// [AuthError.invalidEmail]; alan adı izinli listede değil →
  /// [AuthError.domainNotAllowed]; şifre politikaya (`Limits.passwordPattern`)
  /// uymuyor → [AuthError.weakPassword].
  ///
  /// Hesap açıldıktan sonra doğrulama e-postası gönderilemezse sonuç yine
  /// başarıdır (hesap vardır; AUT-03'te yeniden gönderilir) ve bekleme süresi
  /// başlamaz. Gönderildiyse [resendCooldownRemaining] başlar.
  Future<AuthResult<AuthUserInfo>> register({
    required String email,
    required String password,
  });

  /// E-posta ve şifreyle oturum açar.
  ///
  /// Adres kilitliyse SDK'ya gidilmez: [AuthError.lockedOut] ve `detail`
  /// alanında [AuthFailureDetail] (kilidin açılacağı an + kalan süre) döner.
  /// [AuthError.invalidCredentials] ile biten her deneme sayılır;
  /// `Limits.loginMaxFailedAttempts`. hatalı deneme **kendi hatasıyla**
  /// ([AuthError.invalidCredentials]) döner ve adresi
  /// `Limits.loginLockout` süresince kilitler ([loginLockRemaining] dolu
  /// olur). Başarılı giriş sayacı sıfırlar; ağ hatası gibi diğer hatalar
  /// sayılmaz.
  ///
  /// Biçimi bozuk adres → [AuthError.invalidEmail], izinli olmayan alan adı
  /// → [AuthError.domainNotAllowed] (SDK'ya gidilmez, sayılmaz).
  Future<AuthResult<AuthUserInfo>> signIn({
    required String email,
    required String password,
  });

  /// [email] için giriş kilidinin kalan süresi; kilitli değilse `null`
  /// (DLG-02 geri sayımı).
  Duration? loginLockRemaining(String email);

  /// Oturumu kapatır.
  Future<AuthResult<void>> signOut();

  /// Oturumdaki kullanıcıya doğrulama e-postasını yeniden gönderir.
  ///
  /// Son gönderimden bu yana `Limits.verificationResendCooldown` geçmediyse
  /// SDK'ya gidilmez: [AuthError.resendCooldown] ve `detail` alanında
  /// [AuthFailureDetail] döner (TST-X3). Oturum yoksa
  /// [AuthError.sessionExpired].
  Future<AuthResult<void>> sendEmailVerification();

  /// Oturumdaki kullanıcı için doğrulama e-postasını yeniden gönderme
  /// bekleme süresinin kalanı; bekleme yoksa `null` (AUT-03 düğme metni).
  Duration? get resendCooldownRemaining;

  /// Oturumdaki kullanıcıyı sunucudan yeniler (AUT-03 "Doğruladım").
  ///
  /// E-posta hâlâ doğrulanmamışsa [AuthError.emailNotVerified] (TST-02).
  /// Doğrulanmışsa kimlik jetonu da yenilenir: Security Rules
  /// `email_verified` bilgisini jetondan okur, eski jetonla yapılan her
  /// Firestore çağrısı `permission-denied` alırdı. Jeton yenilenemezse o hata
  /// döner (yeniden denenir).
  Future<AuthResult<AuthUserInfo>> reloadUser();

  /// [email] adresine şifre sıfırlama bağlantısı gönderir (AUT-04).
  ///
  /// Hesap bulunmasa da başarı döner (adresin kayıtlı olup olmadığı
  /// sızdırılmaz).
  Future<AuthResult<void>> sendPasswordReset({required String email});

  /// Oturumdaki kullanıcıyı [password] ile yeniden doğrular (SHT-32,
  /// SET-03).
  Future<AuthResult<void>> reauthenticate({required String password});

  /// Şifreyi değiştirir: önce [currentPassword] ile yeniden doğrular, sonra
  /// [newPassword] yazar (TST-44).
  ///
  /// [newPassword] politikaya uymuyorsa SDK'ya gidilmeden
  /// [AuthError.weakPassword]; mevcut şifre hatalıysa
  /// [AuthError.invalidCredentials].
  Future<AuthResult<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Oturumdaki kullanıcı süper admin mi (`superadmin` claim'i `true`;
  /// D-28)? [forceRefresh] jetonu sunucudan yeniler (girişte bir kez).
  Future<AuthResult<bool>> isSuperAdmin({bool forceRefresh = false});
}
