// MGT-09 testlerinin ortak verisi: tasarım yakalamasındaki görünüm —
// `u_burak` (başkan) → `c03` Doğa Sporları ve Dağcılık Kulübü "Kulüp
// ayarları" (demo veri: bordo × noktalı kapak, başvurular açık, onay ve not
// zorunlu, üç iletişim bağlantısı).
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/management/provider/club_settings_state.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';

import '../../fakes/fake_app_preferences_store.dart';
import '../../fakes/fake_club_repository.dart';
import 'manage_test_support.dart';

/// Tasarımdaki dolu form (ViewModel'in `c03` belgesinden kuracağı biçimde).
ClubSettingsState loadedSettingsState({ClubRole? role = ClubRole.president}) {
  final club = kManageClub;
  return ClubSettingsState(
    role: role,
    original: club,
    summary: club.summary,
    about: club.about,
    email: club.social.email ?? '',
    instagram: club.social.instagram ?? '',
    web: club.social.web ?? '',
    applicationsOpen: club.applicationsOpen,
    approvalRequired: club.approvalRequired,
    requireNote: club.requireNote,
    coverPalette: club.palette,
    coverPattern: club.pattern,
    coverSeed: club.coverSeed,
    coverPath: club.coverPath,
    isLoading: false,
  );
}

/// Kayıtlı fake'lere `c03` kulübünü yazar; galeri ön açıklamasını (DLG-05)
/// onaylanmış sayar.
void seedClubSettings() {
  (GetIt.I<ClubRepository>() as FakeClubRepository).clubs[kManageClubId] =
      kManageClub;
  (GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore)
          .values[AppPreferenceKeys.photoAccessExplained] =
      true;
}
