// NTF-01 · NotificationsViewModel: canlı akış + gün grupları (bugün / dün /
// bu hafta / daha önce), adlar ve silinmiş hedef, tercih ve engel süzgeci,
// filtre, rozet ve okunmamış kulüp kümesi (W-68), okundu / tümü, kaydır-sil
// + geri al, türü kapat, TST-55 yeni bildirim (PLAN §12.6, §15.5, §15.9).
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/features/notifications/provider/notifications_state.dart';
import 'package:gu_kulupler/features/notifications/provider/notifications_view_model.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/notification/unread_notification_clubs.dart';
import 'package:gu_kulupler/product/widget/notification/notification_texts.dart';

import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_session_states.dart';
import '../../../fakes/fake_settings_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/fake_app_clock.dart';
import '../notifications_test_support.dart';

void main() {
  late FakeFeedbackService feedback;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
  });

  NotificationsState stateOf(ProviderContainer c) =>
      c.read(notificationsViewModelProvider);

  NotificationsViewModel vmOf(ProviderContainer c) =>
      c.read(notificationsViewModelProvider.notifier);

  List<String> idsOf(ProviderContainer c) => [
    for (final n in stateOf(c).items) n.id,
  ];

  group('NTF-01 · canlı akış ve gruplar', () {
    test('gün grupları, rozet, adlar, okunmamış kulüpler; iskelet adlarla '
        'kalkar', () async {
      seedNotifications();
      final c = await notificationsContainer();
      final state = stateOf(c);
      expect(state.isFetching, isFalse);
      expect(state.isError, isFalse);
      expect(
        {
          for (final s in state.sections)
            s.day: [for (final n in s.items) n.id],
        },
        {
          NotificationDay.today: ['n009'],
          NotificationDay.yesterday: ['n005', 'n011'],
          NotificationDay.week: ['n007', 'n008', 'n010'],
          NotificationDay.earlier: ['n006', 'n004', 'n012'],
        },
      );
      expect(state.unreadCount, kNtfUnread.length);
      expect(state.showPermissionBanner, isTrue);
      expect(state.lookups.clubNames.keys, containsAll(['c01', 'c05', 'c07']));
      expect(state.lookups.events.keys, contains('e01'));
      expect(state.lookups.postTitles.keys, containsAll(['p01', 'p22']));
      expect(c.read(unreadNotificationClubsProvider), {'c01', 'c07'});
    });

    test('yeni bildirim canlı düşer: listede, rozette ve TST-55 adayı '
        '(`incoming`)', () async {
      seedNotifications();
      final c = await notificationsContainer();
      (GetIt.I<AppClock>() as FakeAppClock).advance(const Duration(minutes: 1));
      final fresh = ntf('n009').copyWith(
        id: 'n_new',
        createdAt: kNtfNowUtc.add(const Duration(minutes: 1)),
      );
      ntfInbox.put(fresh);
      await settleNotifications();
      expect(idsOf(c).first, 'n_new');
      expect(stateOf(c).unreadCount, kNtfUnread.length + 1);
      expect(stateOf(c).incoming?.id, 'n_new');
      vmOf(c).consumeIncoming();
      expect(stateOf(c).incoming, isNull);
    });

    test('akış hatası → isError; refresh yeniden dinler', () async {
      seedNotifications();
      final c = await notificationsContainer();
      ntfInbox.emitInboxError(FirestoreError.unavailable);
      await settleNotifications();
      expect(stateOf(c).isError, isTrue);
      await vmOf(c).refresh();
      await settleNotifications();
      expect(stateOf(c).isError, isFalse);
      expect(idsOf(c), hasLength(kNtfIds.length));
    });

    test('silinmiş hedef: gönderi yok → "İçerik kaldırıldı" metni', () async {
      seedNotifications(
        notifications: [
          ntf('n005').copyWith(
            refs: const NotificationRefsModel(clubId: 'c07', postId: 'p_gone'),
          ),
        ],
      );
      final c = await notificationsContainer();
      final state = stateOf(c);
      expect(state.lookups.missing, contains('p_gone'));
      final l10n = lookupAppLocalizations(const Locale('tr'));
      final texts = NotificationTexts(
        l10n,
        AppDateFormats(const Locale('tr'), GetIt.I<AppClock>()),
      );
      final n = state.items.single;
      expect(
        texts.body(n, state.lookups),
        l10n.notifTypeAnnouncementBody(
          l10n.notifTargetRemoved,
        ),
      );
      expect(
        texts.title(n, state.lookups),
        l10n.notifTypeAnnouncementTitle(
          state.lookups.clubNames['c07']!,
        ),
      );
    });
  });

  group('NTF-01 · süzgeçler', () {
    test('filtre çipleri: okunmamış, etkinlikler, sistem', () async {
      seedNotifications();
      final c = await notificationsContainer();
      vmOf(c).setFilter(NotificationFilter.unread);
      expect(idsOf(c).toSet(), kNtfUnread);
      vmOf(c).setFilter(NotificationFilter.events);
      expect(idsOf(c).toSet(), {'n006', 'n007', 'n009', 'n010', 'n011'});
      vmOf(c).setFilter(NotificationFilter.system);
      expect(idsOf(c), ['n012']);
      // Rozet filtreden bağımsızdır.
      expect(stateOf(c).unreadCount, kNtfUnread.length);
    });

    test(
      'tercih: duyurular kapalı → duyurular gizli, rozetten düşer',
      () async {
        seedNotifications();
        final settings =
            GetIt.I<SettingsRepository>() as FakeSettingsRepository;
        await settings.getSettings(kNtfUid);
        await settings.updateSettings(
          kNtfUid,
          const UserSettingsPatch(announcements: false),
        );
        final c = await notificationsContainer();
        expect(idsOf(c), isNot(contains('n005')));
        expect(idsOf(c), isNot(contains('n004')));
        expect(stateOf(c).unreadCount, kNtfUnread.length - 1);
      },
    );

    test('engellenen başvuranın "Yeni başvuru" bildirimi gizli', () async {
      seedNotifications(
        notifications: [
          ntf('n009'),
          ntf('n005').copyWith(
            id: 'n_app',
            type: NotificationType.applicationReceived,
            refs: const NotificationRefsModel(
              clubId: 'c07',
              applicantId: 'u_blocked',
            ),
          ),
        ],
      );
      final c = await notificationsContainer(
        session: FakeSessionStates.active.copyWith(
          blockedUserIds: {'u_blocked'},
        ),
      );
      expect(idsOf(c), ['n009']);
      expect(stateOf(c).unreadCount, 1);
    });
  });

  group('NTF-01 · yazımlar', () {
    test('okundu: iyimser + markRead; hata → geri alınır + TST-24', () async {
      seedNotifications();
      final c = await notificationsContainer();
      await vmOf(c).markRead('n005');
      expect(ntfInbox.notifications['n005']!.read, isTrue);
      expect(stateOf(c).unreadCount, kNtfUnread.length - 1);

      ntfInbox.failNext(FirestoreError.unavailable);
      await vmOf(c).markRead('n007');
      expect(stateOf(c).items.firstWhere((n) => n.id == 'n007').read, isFalse);
      expect(feedback.toasts, [ToastId.tst24]);
    });

    test('tümünü okundu: görünür okunmamışlar tek çağrıda + TST-18', () async {
      seedNotifications();
      final c = await notificationsContainer();
      vmOf(c).setFilter(NotificationFilter.events);
      await vmOf(c).markAllRead();
      final call = ntfInbox.callsTo('markAllRead').single;
      expect((call.args[1]! as List<String>).toSet(), kNtfUnread);
      expect(stateOf(c).unreadCount, 0);
      expect(feedback.toasts, [ToastId.tst18]);
      expect(c.read(unreadNotificationClubsProvider), isEmpty);
    });

    test('kaydır-sil → soft delete + TST-16; "Geri al" → restore', () async {
      seedNotifications();
      final c = await notificationsContainer();
      await vmOf(c).softDelete('n005');
      expect(idsOf(c), isNot(contains('n005')));
      expect(ntfInbox.notifications['n005']!.isDeleted, isTrue);
      expect(stateOf(c).pendingUndo?.id, 'n005');
      expect(feedback.toasts, [ToastId.tst16]);

      feedback.tapToastAction();
      await settleNotifications();
      expect(idsOf(c), contains('n005'));
      expect(ntfInbox.notifications['n005']!.isDeleted, isFalse);
      expect(stateOf(c).pendingUndo, isNull);
      // Geri alınan bildirim "yeni" sayılmaz.
      expect(stateOf(c).incoming, isNull);
    });

    test(
      'silme hatası (yetki) → satır geri döner + TST-X18',
      () async {
        seedNotifications();
        final c = await notificationsContainer();
        ntfInbox.failNext(FirestoreError.permissionDenied);
        await vmOf(c).softDelete('n005');
        expect(idsOf(c), contains('n005'));
        expect(feedback.toasts, [ToastId.tstX18]);
      },
    );

    test('türü kapat: duyurular kapanır (iyimser) + TST-19', () async {
      seedNotifications();
      final c = await notificationsContainer();
      await vmOf(c).muteType(ntf('n005'));
      final settings = GetIt.I<SettingsRepository>() as FakeSettingsRepository;
      expect(settings.patches.single.patch.announcements, isFalse);
      expect(idsOf(c), isNot(contains('n005')));
      expect(feedback.toasts, [ToastId.tst19]);
      expect(
        NotificationsViewModel.mutePatchOf(NotificationType.roleChanged),
        isNull,
      );
    });

    test('izin bandı: kapat → oturum boyunca dönmez', () async {
      seedNotifications();
      final c = await notificationsContainer();
      vmOf(c).dismissPermissionBanner();
      await vmOf(c).checkPermission();
      expect(stateOf(c).showPermissionBanner, isFalse);
    });
  });
}
