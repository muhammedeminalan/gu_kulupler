// NTF-02 · NotificationPrefsViewModel: okuma (tercihler + aktif kulüpler +
// izin), iyimser anahtar kaydı (TST-19), hata / çevrimdışı geri alma
// (TST-24), art arda dokunuş, hatırlatma zamanı (CD-34) + yerel
// hatırlatıcıların yeniden kurulması (W-85), sessiz saat aralığı (gece
// yarısını aşan geçerli, boş aralık reddedilir), sistem izni (DLG-03 /
// sistem ayarları), SHT-07 sonrası kulüp kaydı yenileme.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/notifications/provider/notification_prefs_state.dart';
import 'package:gu_kulupler/features/notifications/provider/notification_prefs_view_model.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/format/time_of_day_value.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/service/local_reminder_service.dart';
import 'package:gu_kulupler/product/service/permission_service.dart';

import '../../../fakes/fake_club_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_local_reminder_service.dart';
import '../../../fakes/fake_permission_service.dart';
import '../../../fakes/fake_settings_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/test_container.dart';
import '../notification_prefs_test_support.dart';

FakeSettingsRepository _settings() =>
    GetIt.I<SettingsRepository>() as FakeSettingsRepository;
FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;
FakePermissionService _permissions() =>
    GetIt.I<PermissionService>() as FakePermissionService;
FakeLocalReminderService _reminders() =>
    GetIt.I<LocalReminderService>() as FakeLocalReminderService;

/// Kapsayıcıyı kurar, ViewModel'i canlı tutar ve ilk okumayı bekler.
Future<ProviderContainer> _container({SessionState? session}) async {
  final container = createContainer(
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (_, _) => session ?? prefsSession(),
      ),
    ],
  );
  addTearDown(
    container.listen(notificationPrefsViewModelProvider, (_, _) {}).close,
  );
  await pumpEventQueue();
  return container;
}

NotificationPrefsViewModel _vm(ProviderContainer c) =>
    c.read(notificationPrefsViewModelProvider.notifier);

NotificationPrefsState _state(ProviderContainer c) =>
    c.read(notificationPrefsViewModelProvider);

List<UserSettingsPatch> _patches() => [
  for (final write in _settings().patches) write.patch,
];

void main() {
  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    seedPrefs();
  });

  group('NTF-02 · NotificationPrefsViewModel · okuma', () {
    test('ilk durum yükleniyor; okuma kendiliğinden başlar', () {
      final container = createContainer(
        overrides: [
          sessionViewModelProvider.overrideWithBuild((_, _) => prefsSession()),
        ],
      );
      addTearDown(
        container.listen(notificationPrefsViewModelProvider, (_, _) {}).close,
      );
      expect(_state(container), const NotificationPrefsState(isFetching: true));
    });

    test('tercihler + aktif kulüpler (başvuru sırası) + izin; üye '
        'yönetim satırını görmez', () async {
      final container = await _container();
      expect(_state(container), loadedPrefsState());
      expect(_state(container).clubs.map((c) => c.id), ['c01', 'c07']);
      expect(
        (GetIt.I<ClubRepository>() as FakeClubRepository)
            .callsTo('getClubs')
            .single
            .args,
        [
          ['c01', 'c07'],
        ],
      );
    });

    test(
      'yönetici "Yönetim bildirimleri"ni görür; izin verilmişse açık',
      () async {
        _permissions().results[Permission.notification] =
            PermissionStatus.granted;
        final container = await _container(
          session: prefsSession(managerOf: 'c07'),
        );
        expect(_state(container).showManagement, isTrue);
        expect(_state(container).permissionGranted, isTrue);
      },
    );

    test('okuma hatası → isError; "Yeniden dene" yükler', () async {
      _settings().failNext(FirestoreError.unavailable);
      final container = await _container();
      expect(_state(container).isError, isTrue);
      expect(_state(container).isFetching, isFalse);

      await _vm(container).fetch();
      expect(_state(container), loadedPrefsState());
    });
  });

  group('NTF-02 · NotificationPrefsViewModel · anahtarlar', () {
    test('iyimser: önce state, tek alanlı yama, TST-19', () async {
      final container = await _container();
      final future = _vm(
        container,
      ).toggle(NotificationPrefField.announcements, value: false);
      expect(_state(container).settings.announcements, isFalse);
      expect(_state(container).savingKeys, {
        NotificationPrefField.announcements,
      });
      await future;
      expect(_patches(), [const UserSettingsPatch(announcements: false)]);
      expect(_state(container).savingKeys, isEmpty);
      expect(_feedback().toasts, [ToastId.tst19]);
      // Tür anahtarı hatırlatıcıları etkilemez.
      await pumpEventQueue();
      expect(_reminders().rescheduleCalls, 0);
    });

    test('ağ hatası → eski değer + TST-24', () async {
      final container = await _container();
      _settings().failNext(FirestoreError.unavailable);
      await _vm(container).toggle(NotificationPrefField.system, value: false);
      expect(_state(container).settings.system, isTrue);
      expect(_state(container).savingKeys, isEmpty);
      expect(_feedback().toasts, [ToastId.tst24]);
    });

    test('çevrimdışı → hiçbir şey değişmez, TST-24', () async {
      final container = await _container();
      (GetIt.I<ConnectivityService>() as FakeConnectivityService).isOffline =
          true;
      await _vm(
        container,
      ).toggle(NotificationPrefField.newEvents, value: false);
      expect(_state(container).settings.newEvents, isTrue);
      expect(_settings().callsTo('updateSettings'), isEmpty);
      expect(_feedback().toasts, [ToastId.tst24]);
    });

    test('art arda dokunuş: süren yazımdan sonra son değer yazılır', () async {
      final container = await _container();
      final first = _vm(
        container,
      ).toggle(NotificationPrefField.newEvents, value: false);
      final second = _vm(
        container,
      ).toggle(NotificationPrefField.newEvents, value: true);
      await Future.wait([first, second]);
      expect(_patches(), [
        const UserSettingsPatch(newEvents: false),
        const UserSettingsPatch(newEvents: true),
      ]);
      expect(_state(container).settings.newEvents, isTrue);
      expect(_feedback().toasts, [ToastId.tst19]);
    });

    test('"Etkinlik hatırlatmaları" kaydı hatırlatıcıları yeniden kurar '
        '(W-85)', () async {
      final container = await _container();
      await _vm(
        container,
      ).toggle(NotificationPrefField.eventReminders, value: false);
      await pumpEventQueue();
      expect(_reminders().rescheduleCalls, 1);
    });

    test('"Sessiz saatler" açılır; hatırlatıcıya dokunmaz (CD-43)', () async {
      final container = await _container();
      await _vm(container).setQuiet(value: true);
      await pumpEventQueue();
      expect(_patches(), [const UserSettingsPatch(quiet: true)]);
      expect(_reminders().rescheduleCalls, 0);
    });
  });

  group('NTF-02 · NotificationPrefsViewModel · hatırlatma zamanı', () {
    test('1 gün önce → yama + TST-19 + yeniden planlama', () async {
      final container = await _container();
      await _vm(container).setReminderTime(ReminderOption.oneDay);
      await pumpEventQueue();
      expect(_state(container).settings.reminderTime, ReminderOption.oneDay);
      expect(_patches(), [
        const UserSettingsPatch(reminderTime: ReminderOption.oneDay),
      ]);
      expect(_feedback().toasts, [ToastId.tst19]);
      expect(_reminders().rescheduleCalls, 1);
    });

    test('yalnızca 1h / 1d (CD-34); aynı değer yazılmaz', () async {
      final container = await _container();
      await _vm(container).setReminderTime(ReminderOption.fifteenMinutes);
      await _vm(container).setReminderTime(ReminderOption.none);
      await _vm(container).setReminderTime(ReminderOption.oneHour);
      expect(_settings().callsTo('updateSettings'), isEmpty);
    });

    test('hata → eski değer, yeniden planlama yok', () async {
      final container = await _container();
      _settings().failNext(FirestoreError.timeout);
      await _vm(container).setReminderTime(ReminderOption.oneDay);
      await pumpEventQueue();
      expect(_state(container).settings.reminderTime, ReminderOption.oneHour);
      expect(_reminders().rescheduleCalls, 0);
    });
  });

  group('NTF-02 · NotificationPrefsViewModel · sessiz saat aralığı', () {
    test('gece yarısını aşan aralık geçerli; iki uç tek yamada', () async {
      final container = await _container();
      final ok = await _vm(
        container,
      ).setQuietRange(const TimeOfDayValue(23, 30), const TimeOfDayValue(7, 0));
      expect(ok, isTrue);
      expect(_patches(), [
        const UserSettingsPatch(quietFrom: '23:30', quietTo: '07:00'),
      ]);
      expect(_state(container).quietFrom, const TimeOfDayValue(23, 30));
      expect(_state(container).quietTo, const TimeOfDayValue(7, 0));
    });

    test('başlangıç = bitiş → boş aralık, yazılmaz', () async {
      final container = await _container();
      final ok = await _vm(
        container,
      ).setQuietRange(const TimeOfDayValue(8, 0), const TimeOfDayValue(8, 0));
      expect(ok, isFalse);
      expect(_settings().callsTo('updateSettings'), isEmpty);
      expect(
        NotificationPrefsViewModel.isValidQuietRange(
          const TimeOfDayValue(22, 0),
          const TimeOfDayValue(8, 0),
        ),
        isTrue,
      );
    });

    test('ret → iki uç da eski değere döner', () async {
      final container = await _container();
      _settings().failNext(FirestoreError.permissionDenied);
      await _vm(
        container,
      ).setQuietRange(const TimeOfDayValue(21, 0), const TimeOfDayValue(9, 0));
      expect(_state(container).quietFrom, const TimeOfDayValue(22, 0));
      expect(_state(container).quietTo, const TimeOfDayValue(8, 0));
      expect(_feedback().toasts, [ToastId.tstX18]);
    });
  });

  group('NTF-02 · NotificationPrefsViewModel · sistem izni', () {
    test(
      'sorulabilir: DLG-03 → sistem izni → TST-19, kart güncellenir',
      () async {
        final container = await _container();
        _feedback().nextDialogResult = true;
        await _vm(container).enablePermission();
        expect(_feedback().dialogs, [DialogId.dlg03]);
        expect(_permissions().requested, [Permission.notification]);
        expect(_feedback().toasts, [ToastId.tst19]);
        expect(_state(container).permissionGranted, isTrue);
      },
    );

    test('"Şimdi değil" → izin istenmez, kapalı kalır', () async {
      final container = await _container();
      _feedback().nextDialogResult = false;
      await _vm(container).enablePermission();
      expect(_permissions().requested, isEmpty);
      expect(_state(container).permissionGranted, isFalse);
    });

    test('kalıcı ret → sistem ayarları; dönüşte yeniden okunur', () async {
      _permissions().results[Permission.notification] =
          PermissionStatus.permanentlyDenied;
      final container = await _container();
      await _vm(container).enablePermission();
      expect(_feedback().dialogs, isEmpty);
      expect(_permissions().openedSettings, 1);

      _permissions().results[Permission.notification] =
          PermissionStatus.granted;
      await _vm(container).refreshPermission();
      expect(_state(container).permissionGranted, isTrue);
    });
  });

  group('NTF-02 · NotificationPrefsViewModel · kulüp kaydı', () {
    test(
      'SHT-07 sonrası kulüp kayıtları yenilenir ("Sessize alındı")',
      () async {
        final container = await _container();
        expect(_state(container).isClubMuted('c01'), isFalse);
        await _settings().updateClubSettings(
          kPrefsUid,
          'c01',
          const ClubNotificationPrefsModel(
            announcements: false,
            events: false,
            posts: false,
            muted: true,
          ),
        );
        await _vm(container).refreshClubPrefs();
        expect(_state(container).isClubMuted('c01'), isTrue);
        expect(_state(container).isClubMuted('c07'), isFalse);
      },
    );
  });
}
