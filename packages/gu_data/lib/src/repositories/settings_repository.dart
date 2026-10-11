import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/models/club_notification_prefs_model.dart';
import 'package:gu_data/src/models/user_settings_model.dart';

/// Kullanıcının bildirim ayarları — `settings/{uid}` (PLAN §10.4; rules-spec
/// §3.12).
///
/// Belgeyi yalnızca sahibi okur ve yazar. Kimlik parametreleri dış girdi
/// sayılır: geçersiz kimlik [FirestoreError.invalidArgument] döner.
abstract interface class SettingsRepository {
  /// [uid] kullanıcısının ayarları.
  ///
  /// Belge yoksa (profil akışından önce açılmış hesap)
  /// `UserSettingsModel.defaults` **yazılır** ve o değer döner; yazım
  /// başarısız olursa o hata döner (başarı, belgenin var olduğu anlamına
  /// gelir).
  Future<FirestoreResult<UserSettingsModel>> getSettings(String uid);

  /// Genel tercihleri [patch] ile günceller (+ `updatedAt`).
  ///
  /// Boş yama, `1h`/`1d` dışı `reminderTime` ya da `HH:mm` olmayan
  /// `quietFrom`/`quietTo` → [FirestoreError.invalidArgument]; belge yoksa
  /// [FirestoreError.notFound].
  Future<FirestoreResult<void>> updateSettings(
    String uid,
    UserSettingsPatch patch,
  );

  /// Tek bir kulübün tercihlerini (`clubs.<clubId>`) [prefs] ile değiştirir
  /// (+ `updatedAt`); diğer kulüplerin kayıtlarına dokunmaz.
  Future<FirestoreResult<void>> updateClubSettings(
    String uid,
    String clubId,
    ClubNotificationPrefsModel prefs,
  );
}
