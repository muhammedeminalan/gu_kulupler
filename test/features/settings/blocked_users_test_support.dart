// SET-02 testlerinin ortak verisi: demo verideki Mehmet'in engellediği
// `u042` (Eren Çakır, Kimya · 2. sınıf) ve ikinci satır için `u_ayse`.
// Kullanıcılar fixture'lardan kurulur; engel kaydı fake depoya yazılır.
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/features/settings/provider/blocked_users_state.dart';

import '../../fakes/fake_block_repository.dart';
import '../../fakes/fake_session_states.dart';
import '../../fakes/fake_user_repository.dart';
import '../../fixtures/user_model_fixtures.dart';

/// Oturumdaki kullanıcı (`u_mehmet`).
const String kBlockerUid = FakeSessionStates.uid;

/// Demo verideki engellenen kullanıcı (tasarım yakalaması).
final UserModel kBlockedEren = UserModelFixtures.byId('u042');

/// İkinci engellenen kullanıcı.
final UserModel kBlockedAyse = UserModelFixtures.ayse;

/// [users] kullanıcılarını engellemiş aktif oturum.
SessionState blockedSession([List<UserModel>? users]) =>
    FakeSessionStates.active.copyWith(
      blockedUserIds: {
        for (final user in users ?? [kBlockedEren]) user.uid,
      },
    );

/// Fake'leri tohumlar: [users] kullanıcıları + Mehmet'in onlara engeli.
void seedBlocked([List<UserModel>? users]) {
  final blocks = GetIt.I<BlockRepository>() as FakeBlockRepository;
  final repo = GetIt.I<UserRepository>() as FakeUserRepository;
  for (final user in users ?? [kBlockedEren]) {
    repo.users[user.uid] = user;
    blocks.put(kBlockerUid, user.uid);
  }
}

/// Dolu ekran durumu: [users] satırları.
BlockedUsersState loadedBlocked([List<UserModel>? users]) => BlockedUsersState(
  items: [
    for (final user in users ?? [kBlockedEren])
      (BlockModel(blockerId: kBlockerUid, blockedId: user.uid), user),
  ],
);
