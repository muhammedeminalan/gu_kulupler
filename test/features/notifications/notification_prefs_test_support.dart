// NTF-02 testlerinin ortak verisi: demo verideki Mehmet (`u_mehmet`) —
// `c01` (Yazılım ve Yapay Zekâ Topluluğu) ve `c07` (Fotoğraf ve Sinema
// Kulübü) aktif üyelikleri (`c06` bekleyen, `c05` reddedilmiş: listede
// yok), ayarlar varsayılan (hepsi açık, 1 saat önce, sessiz saat kapalı).
// Modeller fixture'lardan kurulur; elle yazılmış alan yoktur.
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/features/notifications/provider/notification_prefs_state.dart';

import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_session_states.dart';
import '../../fakes/fake_settings_repository.dart';
import '../../fixtures/club_model_fixtures.dart';
import '../../fixtures/membership_model_fixtures.dart';

/// Oturumdaki kullanıcı.
const String kPrefsUid = FakeSessionStates.uid;

/// Mehmet'in demo verideki üyelik belgeleri (aktif, bekleyen, reddedilmiş).
const List<String> kPrefsMembershipIds = [
  'c07_u_mehmet',
  'c01_u_mehmet',
  'c06_u_mehmet',
  'c05_u_mehmet',
];

/// Kulüp bazlı satırlar (başvuru sırasıyla: c01 Mayıs, c07 Ağustos).
final List<ClubModel> kPrefsClubs = [
  ClubModelFixtures.byId('c01'),
  ClubModelFixtures.byId('c07'),
];

/// Aktif oturum + Mehmet'in üyelikleri; [managerOf] verilirse o kulüpte
/// rolü `board` olur.
SessionState prefsSession({String? managerOf}) =>
    FakeSessionStates.active.copyWith(
      memberships: {
        for (final membership in kPrefsMembershipIds.map(
          MembershipModelFixtures.byId,
        ))
          membership.clubId: membership.clubId == managerOf
              ? membership.copyWith(role: ClubRole.board)
              : membership,
      },
    );

/// Dolu ekran durumu (ViewModel'in ürettiğiyle aynı).
NotificationPrefsState loadedPrefsState({
  UserSettingsModel? settings,
  List<ClubModel>? clubs,
  bool permissionGranted = false,
  bool showManagement = false,
}) => NotificationPrefsState(
  settings: settings ?? const UserSettingsModel.defaults(kPrefsUid),
  clubs: clubs ?? kPrefsClubs,
  permissionGranted: permissionGranted,
  showManagement: showManagement,
);

/// Kayıtlı fake'lere kulüpleri ve ([settings] verilirse) ayar belgesini
/// yazar.
void seedPrefs({UserSettingsModel? settings}) {
  final clubs = GetIt.I<ClubRepository>() as FakeClubRepository;
  for (final club in kPrefsClubs) {
    clubs.clubs[club.id] = club;
  }
  if (settings != null) {
    (GetIt.I<SettingsRepository>() as FakeSettingsRepository)
            .settings[kPrefsUid] =
        settings;
  }
}
