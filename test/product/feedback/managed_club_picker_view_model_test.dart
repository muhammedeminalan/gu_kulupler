// SHT-18 · ManagedClubPickerViewModel + ManagedClubPickerState: yönetilen
// kulüp belgelerinin okunması (`clubRepository.getClubs`, oturum sırasıyla),
// yönetilen kulüp yokken okumasız boş durum, hata → `fetch` ile yeniden
// okuma, oturumdaki yönetilen küme değişince yeniden okuma.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/managed_club_picker_state.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/managed_club_picker_view_model.dart';

import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_session_states.dart';
import '../../fakes/register_fakes.dart';
import '../../fixtures/club_model_fixtures.dart';
import '../../helpers/test_container.dart';

FakeClubRepository _clubs() => GetIt.I<ClubRepository>() as FakeClubRepository;

/// Test içinden değiştirilebilen oturum kaynağı: sahte oturum bunu izler.
final class _SessionSource extends Notifier<SessionState> {
  @override
  SessionState build() => FakeSessionStates.active;

  /// Oturumu doğrudan değiştirir.
  void emit(SessionState next) => state = next;
}

final _sessionSource = NotifierProvider<_SessionSource, SessionState>(
  _SessionSource.new,
);

/// Oturumu [session] yapar (sahte oturum ViewModel'i yeniden kurulur).
void _emit(ProviderContainer container, SessionState session) =>
    container.read(_sessionSource.notifier).emit(session);

/// Kapsayıcıyı kurar, ViewModel'i canlı tutar ve ilk okumayı bekler.
Future<ProviderContainer> _container(SessionState session) async {
  final container = createContainer(
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (ref, _) => ref.watch(_sessionSource),
      ),
    ],
  );
  _emit(container, session);
  addTearDown(
    container.listen(managedClubPickerViewModelProvider, (_, _) {}).close,
  );
  await pumpEventQueue();
  return container;
}

ManagedClubPickerState _state(ProviderContainer container) =>
    container.read(managedClubPickerViewModelProvider);

void main() {
  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    for (final id in ['c01', 'c03']) {
      _clubs().clubs[id] = ClubModelFixtures.byId(id);
    }
  });

  group('SHT-18 · ManagedClubPickerState', () {
    test('varsayılanlar, `props` ve `copyWith` tüm alanları taşır', () {
      const initial = ManagedClubPickerState();
      expect(initial.clubs, isEmpty);
      expect(initial.isFetching, isFalse);
      expect(initial.isError, isFalse);

      final clubs = {'c01': ClubModelFixtures.c01};
      final changed = initial.copyWith(
        clubs: clubs,
        isFetching: true,
        isError: true,
      );
      expect(changed.props, [clubs, true, true]);
      expect(changed.copyWith(), changed);
      expect(changed, isNot(initial));
      expect(changed.copyWith(isFetching: false).clubs, clubs);
    });
  });

  group('SHT-18 · ManagedClubPickerViewModel', () {
    test('yönetilen kulüplerin belgeleri oturum sırasıyla okunur; ilk durum '
        'yükleniyor', () async {
      final session = FakeSessionStates.activeManager(
        'c03',
        role: ClubRole.president,
      );
      final container = createContainer(
        overrides: [
          sessionViewModelProvider.overrideWithBuild((_, _) => session),
        ],
      );
      addTearDown(
        container.listen(managedClubPickerViewModelProvider, (_, _) {}).close,
      );
      expect(_state(container).isFetching, isTrue);
      expect(_state(container).clubs, isEmpty);

      await pumpEventQueue();
      expect(_state(container).isFetching, isFalse);
      expect(_state(container).isError, isFalse);
      expect(_state(container).clubs, {'c03': ClubModelFixtures.byId('c03')});
      expect(_clubs().callsTo('getClubs').single.args, [
        ['c03'],
      ]);
    });

    test('yönetilen kulüp yoksa okuma yapılmaz, durum boştur', () async {
      final container = await _container(FakeSessionStates.activeMember('c01'));
      expect(_state(container), const ManagedClubPickerState());
      expect(_clubs().callsTo('getClubs'), isEmpty);
    });

    test('okunamazsa `isError`; `fetch` yeniden okur', () async {
      _clubs().failNext(FirestoreError.unavailable);
      final container = await _container(
        FakeSessionStates.activeAdvisor('c01'),
      );
      expect(_state(container).isError, isTrue);
      expect(_state(container).isFetching, isFalse);
      expect(_state(container).clubs, isEmpty);

      await container.read(managedClubPickerViewModelProvider.notifier).fetch();
      expect(_state(container).isError, isFalse);
      expect(_state(container).clubs.keys, ['c01']);
      expect(_clubs().callsTo('getClubs'), hasLength(2));
    });

    test('oturumdaki yönetilen küme değişince yeniden okunur; başka oturum '
        'değişikliği okuma yapmaz', () async {
      final session = FakeSessionStates.activeManager('c01');
      final container = await _container(session);
      expect(_state(container).clubs.keys, ['c01']);

      // Yönetilen küme aynı (engel listesi değişti): okuma yok.
      _emit(container, session.copyWith(blockedUserIds: {'u001'}));
      await pumpEventQueue();
      expect(_clubs().callsTo('getClubs'), hasLength(1));

      // Yeni kulüpte başkanlık verildi.
      final promoted = FakeSessionStates.activeManager(
        'c03',
        role: ClubRole.president,
      );
      _emit(
        container,
        session.copyWith(
          memberships: {...session.memberships, ...promoted.memberships},
        ),
      );
      await pumpEventQueue();
      expect(_state(container).clubs.keys, ['c01', 'c03']);
      expect(_clubs().callsTo('getClubs').last.args, [
        ['c01', 'c03'],
      ]);

      // Yönetim rolleri alındı: liste boşalır.
      _emit(container, FakeSessionStates.active);
      await pumpEventQueue();
      expect(_state(container), const ManagedClubPickerState());
    });
  });
}
