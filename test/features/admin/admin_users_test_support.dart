// ADM-05 testlerinin ortak verisi: tasarım yakalamasındaki görünüm —
// `u_admin` (süper admin): demo verinin silinmemiş kullanıcıları ada göre
// (Türkçe) ilk 80'i (`screens-admin.js:74` `slice(0, 80)`), alt metin
// "Bölüm · N. sınıf · {n} kulüp" (etkin üyelikler). Modeller demo veriden
// kurulur.
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/admin/provider/admin_users_state.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_membership_repository.dart';
import '../../fakes/fake_user_repository.dart';
import '../../fixtures/demo_data.dart';
import '../../fixtures/membership_model_fixtures.dart';
import '../../fixtures/user_model_fixtures.dart';

/// Prototipin satır sınırı (`slice(0, 80)`) — envanterdeki 80 satır.
const int kAdminUsersShown = 80;

/// Demo verideki askıdaki kullanıcı ("Askıdaki Kullanıcı").
const String kSuspendedUserId = 'u_suspended';

/// Tasarımın ilk satırı: "Alp Aksoy".
const String kFirstUserName = 'Alp Aksoy';

/// Silinmemiş tüm demo kullanıcıları.
List<UserModel> demoUsers() => [
  for (final id in DemoDataFixture.ids(FirestoreCollections.users))
    if (UserModelFixtures.byId(id) case final user
        when !user.isDeleted && !user.isAnonymized)
      user,
];

/// Tasarımdaki 80 satırın kullanıcıları (ada göre, Türkçe).
List<UserModel> adminUsersShown() =>
    (demoUsers()..sort((a, b) => a.name.trCompareTo(b.name)))
        .take(kAdminUsersShown)
        .toList();

/// Demo verideki etkin üyelikler.
List<MembershipModel> demoActiveMemberships() => [
  for (final id in DemoDataFixture.ids(FirestoreCollections.memberships))
    if (MembershipModelFixtures.byId(id) case final membership
        when membership.status == MembershipStatus.active)
      membership,
];

/// Kullanıcı başına etkin üyelik sayısı (her demo kullanıcısı için).
Map<String, int> demoClubCounts() {
  final counts = {for (final user in demoUsers()) user.uid: 0};
  for (final membership in demoActiveMemberships()) {
    counts.update(membership.userId, (n) => n + 1, ifAbsent: () => 1);
  }
  return counts;
}

/// Etkin `board` / `president` üyeliği olanlar.
Set<String> demoManagerIds() => {
  for (final membership in demoActiveMemberships())
    if (membership.role == ClubRole.board ||
        membership.role == ClubRole.president)
      membership.userId,
};

/// Tasarımdaki dolu görünüm (ViewModel'in üreteceği biçimde).
AdminUsersState loadedAdminUsersState({List<UserModel>? users}) =>
    AdminUsersState(
      users: users ?? adminUsersShown(),
      managerUserIds: demoManagerIds(),
      clubCounts: demoClubCounts(),
      isLoaded: true,
    );

/// Kayıtlı fake'lere demo kullanıcılarını (e-posta hesabıyla) ve etkin
/// üyelikleri yazar.
void seedAdminUsers() {
  final users = GetIt.I<UserRepository>() as FakeUserRepository;
  final memberships =
      GetIt.I<MembershipRepository>() as FakeMembershipRepository;
  final raw = DemoDataFixture.raw['users']! as Map<String, Object?>;
  for (final user in demoUsers()) {
    users.users[user.uid] = user;
    final email = (raw[user.uid]! as Map<String, Object?>)['email'] as String?;
    if (email != null && email.isNotEmpty) {
      users.accounts[user.uid] = UserAccountModel(
        email: email,
        emailLower: email.toLowerCase(),
      );
    }
  }
  demoActiveMemberships().forEach(memberships.put);
}
