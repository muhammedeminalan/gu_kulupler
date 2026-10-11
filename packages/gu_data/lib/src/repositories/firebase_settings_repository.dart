import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gu_data/src/constants/firestore_collections.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/models/club_notification_prefs_model.dart';
import 'package:gu_data/src/models/user_settings_model.dart';
import 'package:gu_data/src/repositories/repository_helpers.dart';
import 'package:gu_data/src/repositories/settings_repository.dart';
import 'package:gu_data/src/services/firestore_service.dart';
import 'package:gu_data/src/services/firestore_types.dart';
import 'package:gu_data/src/utils/field_validators.dart';

/// [SettingsRepository] uygulaması: `settings/{uid}` (PLAN §10.4).
final class FirebaseSettingsRepository implements SettingsRepository {
  /// [_firestore] servisi üzerinden okur ve yazar.
  FirebaseSettingsRepository(this._firestore);

  final FirestoreService _firestore;

  /// Yeni `settings/{uid}` belgesinin yükü: `UserSettingsModel.defaults`
  /// alanları + sunucu zamanlı `updatedAt`. Varsayılan belge yalnızca
  /// buradan üretilir (`getSettings` ve `UserRepository.createProfile`).
  static Json defaultsPayload(String uid) => {
    ...UserSettingsModel.defaults(uid).toJson(),
    ...BaseFieldsPayload.update(),
  };

  @override
  Future<FirestoreResult<UserSettingsModel>> getSettings(String uid) async {
    if (RepositoryHelpers.rejectInvalidIds<UserSettingsModel>({'uid': uid})
        case final rejected?) {
      return rejected;
    }
    final ref = _ref(uid);
    final read = RepositoryHelpers.parseOrNull(
      await _firestore.getDoc(ref),
      (doc) => UserSettingsModel.fromJson(doc.data, id: doc.id),
    );
    switch (read) {
      case FirebaseFailure(:final error, :final message, :final detail):
        return FirebaseFailure(error, message: message, detail: detail);
      case FirebaseSuccess(data: final settings?):
        return FirebaseSuccess(settings);
      case FirebaseSuccess():
        final written = await _firestore.set(ref, defaultsPayload(uid));
        return written.map((_) => UserSettingsModel.defaults(uid));
    }
  }

  @override
  Future<FirestoreResult<void>> updateSettings(
    String uid,
    UserSettingsPatch patch,
  ) async {
    final rejected =
        RepositoryHelpers.rejectInvalidIds<void>({'uid': uid}) ??
        RepositoryHelpers.rejectInvalidFields<void>({
          if (patch.reminderTime case final value?)
            FirestoreFields.reminderTime: FieldValidators.reminderTime(value),
          if (patch.quietFrom case final value?)
            FirestoreFields.quietFrom: FieldValidators.timeOfDay(value),
          if (patch.quietTo case final value?)
            FirestoreFields.quietTo: FieldValidators.timeOfDay(value),
        });
    if (rejected != null) return rejected;
    return _firestore.update(_ref(uid), patch.toJson());
  }

  @override
  Future<FirestoreResult<void>> updateClubSettings(
    String uid,
    String clubId,
    ClubNotificationPrefsModel prefs,
  ) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({'uid': uid})
        case final rejected?) {
      return rejected;
    }
    // Kulüp kimliği noktalı alan yolunun parçası olur: yolu başka bir alana
    // çevirebilecek karakter taşıyamaz.
    if (!RepositoryHelpers.isFieldPathSegment(clubId)) {
      return RepositoryHelpers.invalidArgument('geçersiz kimlik: clubId');
    }
    return _firestore.update(_ref(uid), {
      '${FirestoreFields.clubs}.$clubId': prefs.toJson(),
    });
  }

  DocumentReference<Json> _ref(String uid) =>
      _firestore.doc(FirestoreCollections.settings, uid);
}
