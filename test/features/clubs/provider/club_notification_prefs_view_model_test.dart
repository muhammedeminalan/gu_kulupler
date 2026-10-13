// SHT-07 · ClubNotificationPrefsViewModel (kulüp başına aile): tercihlerin
// okunması, iyimser `toggle` (TST-38), "Tümünü sessize al" kuralları
// (TST-X16), çevrimdışı ve hata yolları (TST-24, geri alma), art arda tetik.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_notification_prefs_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_notification_prefs_view_model.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';

import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_session_states.dart';
import '../../../fakes/fake_settings_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/test_container.dart';

const String _clubId = 'c01';
const String _uid = FakeSessionStates.uid;

const ClubNotificationPrefsModel _allOn = ClubNotificationPrefsModel();
const ClubNotificationPrefsModel _muted = ClubNotificationPrefsModel(
  announcements: false,
  events: false,
  posts: false,
  muted: true,
);

FakeSettingsRepository _settings() =>
    GetIt.I<SettingsRepository>() as FakeSettingsRepository;
FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;
FakeConnectivityService _connectivity() =>
    GetIt.I<ConnectivityService>() as FakeConnectivityService;

/// Kullanıcının ayarlar belgesini [prefs] kulüp kaydıyla hazırlar.
void _seed(ClubNotificationPrefsModel prefs, {String clubId = _clubId}) =>
    _settings().settings[_uid] = const UserSettingsModel.defaults(
      _uid,
    ).copyWith(clubs: {clubId: prefs});

/// Kapsayıcıyı kurar, ViewModel'i canlı tutar ve ilk okumayı bekler.
Future<ProviderContainer> _container({
  SessionState session = FakeSessionStates.active,
  String clubId = _clubId,
}) async {
  final container = createContainer(
    overrides: [sessionViewModelProvider.overrideWithBuild((_, _) => session)],
  );
  addTearDown(
    container
        .listen(clubNotificationPrefsViewModelProvider(clubId), (_, _) {})
        .close,
  );
  await pumpEventQueue();
  return container;
}

ClubNotificationPrefsViewModel _viewModel(
  ProviderContainer container, {
  String clubId = _clubId,
}) => container.read(clubNotificationPrefsViewModelProvider(clubId).notifier);

ClubNotificationPrefsState _state(
  ProviderContainer container, {
  String clubId = _clubId,
}) => container.read(clubNotificationPrefsViewModelProvider(clubId));

List<ClubNotificationPrefsModel> _writes() => [
  for (final write in _settings().clubSettingsWrites) write.prefs,
];

void main() {
  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
  });

  group('SHT-07 · ClubNotificationPrefsViewModel · okuma', () {
    test('ilk durum yüklenmemiştir; okuma kendiliğinden başlar', () {
      final container = createContainer(
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (_, _) => FakeSessionStates.active,
          ),
        ],
      );
      addTearDown(
        container
            .listen(clubNotificationPrefsViewModelProvider(_clubId), (_, _) {})
            .close,
      );
      expect(_state(container), const ClubNotificationPrefsState());
      expect(_settings().calls, isEmpty);
    });

    test('kulüp kaydı yoksa hepsi açık', () async {
      final container = await _container();
      expect(
        _state(container),
        const ClubNotificationPrefsState(isLoaded: true),
      );
      expect(_settings().callsTo('getSettings').single.args, [_uid]);
    });

    test('kulübün kaydı okunur; başka kulübün kaydı karışmaz', () async {
      _seed(const ClubNotificationPrefsModel(events: false));
      final container = await _container();
      expect(
        _state(container).prefs,
        const ClubNotificationPrefsModel(events: false),
      );

      final other = await _container(clubId: 'c02');
      expect(_state(other, clubId: 'c02').prefs, _allOn);
    });

    test('okuma hatası `isError`; "Yeniden dene" tercihleri getirir', () async {
      _seed(_muted);
      _settings().failNext(FirestoreError.unavailable);
      final container = await _container();
      expect(
        _state(container),
        const ClubNotificationPrefsState(isError: true),
      );

      final retry = _viewModel(container).load();
      expect(_state(container).isError, isFalse);
      await retry;
      expect(
        _state(container),
        const ClubNotificationPrefsState(prefs: _muted, isLoaded: true),
      );
    });

    test('oturumda kullanıcı yoksa `isError`; okuma yapılmaz', () async {
      final container = await _container(session: FakeSessionStates.signedOut);
      expect(_state(container).isError, isTrue);
      expect(_state(container).isLoaded, isFalse);
      expect(_settings().calls, isEmpty);
    });

    test('süren okuma varken `load` yok sayılır', () async {
      final container = await _container();
      final first = _viewModel(container).load();
      final second = _viewModel(container).load();
      await Future.wait([first, second]);
      expect(_settings().callsTo('getSettings'), hasLength(2));
    });
  });

  group('SHT-07 · ClubNotificationPrefsViewModel · toggle', () {
    test('yüklenmeden dokunuş yok sayılır', () async {
      _settings().failNext(FirestoreError.unavailable);
      final container = await _container();
      await _viewModel(container).toggle(ClubPrefKey.posts, value: false);
      expect(_state(container).prefs, _allOn);
      expect(_writes(), isEmpty);
      expect(_feedback().toasts, isEmpty);
    });

    for (final key in [
      ClubPrefKey.announcements,
      ClubPrefKey.events,
      ClubPrefKey.posts,
    ]) {
      test('TST-38: ${key.name} iyimser kapanır, yazılır', () async {
        final container = await _container();
        final expected = switch (key) {
          ClubPrefKey.announcements => const ClubNotificationPrefsModel(
            announcements: false,
          ),
          ClubPrefKey.events => const ClubNotificationPrefsModel(events: false),
          _ => const ClubNotificationPrefsModel(posts: false),
        };

        final pending = _viewModel(container).toggle(key, value: false);
        // Yazım bitmeden state güncellenmiştir.
        expect(
          _state(container),
          ClubNotificationPrefsState(
            prefs: expected,
            isLoaded: true,
            isSaving: true,
          ),
        );
        expect(_feedback().toasts, isEmpty);
        await pending;

        expect(
          _state(container),
          ClubNotificationPrefsState(prefs: expected, isLoaded: true),
        );
        expect(_settings().clubSettingsWrites.single, (
          uid: _uid,
          clubId: _clubId,
          prefs: expected,
        ));
        expect(_feedback().toasts, [ToastId.tst38]);
        expect(_state(container).valueOf(key), isFalse);
      });
    }

    test('aynı değere dokunuş yazmaz', () async {
      final container = await _container();
      await _viewModel(container).toggle(ClubPrefKey.events, value: true);
      expect(_writes(), isEmpty);
      expect(_feedback().toasts, isEmpty);
    });

    test('"Tümünü sessize al" açılınca üç tür kapanır, kapatılınca üçü de '
        'açılır (TST-38)', () async {
      _seed(const ClubNotificationPrefsModel(posts: false));
      final container = await _container();

      await _viewModel(container).toggle(ClubPrefKey.muted, value: true);
      expect(_state(container).prefs, _muted);
      for (final key in ClubPrefKey.values) {
        expect(_state(container).valueOf(key), key == ClubPrefKey.muted);
        expect(_state(container).isLocked(key), key != ClubPrefKey.muted);
      }

      await _viewModel(container).toggle(ClubPrefKey.muted, value: false);
      expect(_state(container).prefs, _allOn);
      expect(_writes(), [_muted, _allOn]);
      expect(_feedback().toasts, [ToastId.tst38, ToastId.tst38]);
    });

    test(
      'TST-X16: sessizdeyken diğer anahtarlar kilitlidir; yazılmaz',
      () async {
        _seed(_muted);
        final container = await _container();
        for (final key in [
          ClubPrefKey.announcements,
          ClubPrefKey.events,
          ClubPrefKey.posts,
        ]) {
          await _viewModel(container).toggle(key, value: true);
        }
        expect(_feedback().toasts, [
          ToastId.tstX16,
          ToastId.tstX16,
          ToastId.tstX16,
        ]);
        expect(_state(container).prefs, _muted);
        expect(_writes(), isEmpty);
      },
    );

    test('TST-24: çevrimdışıyken değer değişmez, yazılmaz', () async {
      final container = await _container();
      _connectivity().isOffline = true;

      await _viewModel(container).toggle(ClubPrefKey.muted, value: true);
      expect(_feedback().toasts, [ToastId.tst24]);
      expect(
        _state(container),
        const ClubNotificationPrefsState(isLoaded: true),
      );
      expect(_writes(), isEmpty);
    });

    for (final error in [
      FirestoreError.offline,
      FirestoreError.unavailable,
      FirestoreError.timeout,
    ]) {
      test(
        'TST-24: ağ hatasında (${error.name}) eski değere dönülür',
        () async {
          _seed(const ClubNotificationPrefsModel(events: false));
          final container = await _container();
          _settings().failNext(error);

          final pending = _viewModel(
            container,
          ).toggle(ClubPrefKey.announcements, value: false);
          expect(_state(container).prefs.announcements, isFalse);
          await pending;

          expect(
            _state(container),
            const ClubNotificationPrefsState(
              prefs: ClubNotificationPrefsModel(events: false),
              isLoaded: true,
            ),
          );
          expect(_feedback().toasts, [ToastId.tst24]);
          expect(_writes(), isEmpty);
        },
      );
    }

    test('sunucu reddi: eski değere dönülür, `isError`; sonraki başarılı '
        'yazım hatayı siler', () async {
      final container = await _container();
      _settings().failNext(FirestoreError.permissionDenied);

      await _viewModel(container).toggle(ClubPrefKey.posts, value: false);
      expect(
        _state(container),
        const ClubNotificationPrefsState(isLoaded: true, isError: true),
      );
      expect(_feedback().toasts, isEmpty);

      await _viewModel(container).toggle(ClubPrefKey.posts, value: false);
      expect(
        _state(container),
        const ClubNotificationPrefsState(
          prefs: ClubNotificationPrefsModel(posts: false),
          isLoaded: true,
        ),
      );
      expect(_feedback().toasts, [ToastId.tst38]);
    });

    test('geri alma hedefi son kaydedilen değerdir', () async {
      final container = await _container();
      await _viewModel(container).toggle(ClubPrefKey.events, value: false);
      _settings().failNext(FirestoreError.unavailable);
      await _viewModel(container).toggle(ClubPrefKey.muted, value: true);

      expect(
        _state(container).prefs,
        const ClubNotificationPrefsModel(events: false),
      );
      expect(_feedback().toasts, [ToastId.tst38, ToastId.tst24]);
    });

    test('art arda tetik: dokunuşlar sıraya girer, son değer yazılır, tek '
        'TST-38', () async {
      final container = await _container();
      final viewModel = _viewModel(container);

      final first = viewModel.toggle(ClubPrefKey.announcements, value: false);
      final second = viewModel.toggle(ClubPrefKey.events, value: false);
      final third = viewModel.toggle(ClubPrefKey.announcements, value: true);
      await Future.wait([first, second, third]);

      const last = ClubNotificationPrefsModel(events: false);
      expect(_writes(), [
        const ClubNotificationPrefsModel(announcements: false),
        last,
      ]);
      expect(
        _state(container),
        const ClubNotificationPrefsState(prefs: last, isLoaded: true),
      );
      expect(_feedback().toasts, [ToastId.tst38]);
      expect(_settings().settings[_uid]!.clubs[_clubId], last);
    });

    test(
      'art arda tetik: süren yazım düşerse sıradaki de geri alınır',
      () async {
        final container = await _container();
        final viewModel = _viewModel(container);
        _settings().failNext(FirestoreError.permissionDenied);

        final first = viewModel.toggle(ClubPrefKey.announcements, value: false);
        final second = viewModel.toggle(ClubPrefKey.posts, value: false);
        await Future.wait([first, second]);

        expect(
          _state(container),
          const ClubNotificationPrefsState(isLoaded: true, isError: true),
        );
        expect(_writes(), isEmpty);
        expect(_feedback().toasts, isEmpty);
      },
    );

    test('yazım yalnızca kendi kulübüne gider', () async {
      _seed(_muted, clubId: 'c02');
      final container = await _container();
      await _viewModel(container).toggle(ClubPrefKey.posts, value: false);

      final clubs = _settings().settings[_uid]!.clubs;
      expect(clubs['c02'], _muted);
      expect(clubs[_clubId], const ClubNotificationPrefsModel(posts: false));
    });
  });
}
