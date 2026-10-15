// ADM-03 testlerinin ortak kurulumu: süper admin oturumu (fake Auth —
// `createClub` aktörü), iki etkin kullanıcı (başkan adayı), galeri ön
// açıklaması (DLG-05) onaylanmış; fake `createClub` ile kurulmuş düzenleme
// kulübü.
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';

import '../../fakes/fake_admin_repository.dart';
import '../../fakes/fake_app_preferences_store.dart';
import '../../fakes/fake_auth_service.dart';
import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_user_repository.dart';

/// Başkan (yeni kulüpte seçilen / düzenlemedeki başkan).
const String kFormPresidentId = 'u_pres';

/// Başkan e-postası (`createClub` `presidentEmail`).
const String kFormPresidentEmail = 'ece@ogr.gumushane.edu.tr';

/// İkinci etkin kullanıcı (başkan ata).
const String kFormNextId = 'u_next';

/// Bağlı danışman hesabı (W-101 a).
const String kFormAdvisorUid = 'u_adv';

/// Kayıtlı fake'lere oturumu, kullanıcıları ve DLG-05 onayını yazar.
void seedClubForm() {
  (GetIt.I<AuthService>() as FakeAuthService).currentUser = const AuthUserInfo(
    uid: 'u_admin',
    email: 'admin@ogr.gumushane.edu.tr',
    emailVerified: true,
    displayName: 'Admin',
  );
  (GetIt.I<UserRepository>() as FakeUserRepository)
    ..putActive(
      kFormPresidentId,
      name: 'Ece Başkan',
      email: kFormPresidentEmail,
    )
    ..putActive(kFormNextId, name: 'Can Yeni');
  (GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore)
          .values[AppPreferenceKeys.photoAccessExplained] =
      true;
}

/// Fake `createClub` ile kurulmuş "Doğa Kulübü" (başkan [kFormPresidentId],
/// danışman "Dr. Ayşe Kaya"; [linkedAdvisor] → hesabı [kFormAdvisorUid]'ye
/// bağlı). Çağrı kaydı temizlenir.
Future<ClubModel> seedFormClub({bool linkedAdvisor = false}) async {
  final admin = GetIt.I<AdminRepository>() as FakeAdminRepository;
  final users = GetIt.I<UserRepository>() as FakeUserRepository;
  final result = await admin.createClub(
    const ClubCreateInput(
      name: 'Doğa Kulübü',
      nameLower: 'doğa kulübü',
      categoryId: 'k03',
      iconName: 'mountain',
      founded: 2020,
      palette: ClubPalette.slate,
      pattern: ClubPattern.waves,
      summary: 'Dağ, doğa ve kamp.',
    ),
    presidentUserId: kFormPresidentId,
    presidentUser: users.users[kFormPresidentId]!,
    presidentEmail: kFormPresidentEmail,
    advisor: const AdvisorInput(name: 'Ayşe Kaya', title: 'Dr.'),
  );
  var club = result.dataOrNull!;
  if (linkedAdvisor) {
    club = club.copyWith(
      advisor: club.advisor!.copyWith(userId: kFormAdvisorUid),
    );
    (GetIt.I<ClubRepository>() as FakeClubRepository).clubs[club.id] = club;
  }
  admin.calls.clear();
  return club;
}
