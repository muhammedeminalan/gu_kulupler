// T-26 · Derin bağlantı tablosu (PLAN §13.7, navigation.md §4.1):
// `NotificationTargets.locationFor` her `NotificationType` için beklenen
// konum ve sekme; türün gerektirdiği kimlik eksikse SYS-04. Gecikmeli sheet
// hedefleri: W-28 (T-32, MGT-02 `?applicant=`), W-29 (T-40, ADM-04
// `?reportId=`).
// `NotificationNavigator.open` / `openPayload`: okundu, bilet ayrımı
// (going / attended → EVT-03; waitlist / kayıt yok → EVT-02), silinmiş /
// gizli hedef → SYS-04, TST-17, hatırlatıcı liste belgesi, bozuk yük; gerçek
// kabukta yığın `kök → … → hedef` (§13.5 tek liste).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/notification_navigator.dart';

import '../../fakes/fake_event_repository.dart';
import '../../fakes/fake_feedback_service.dart';
import '../../fakes/fake_notification_repository.dart';
import '../../fakes/fake_post_repository.dart';
import '../../fakes/fake_rsvp_repository.dart';
import '../../fakes/fake_session_states.dart';
import '../../fakes/register_fakes.dart';
import '../../fakes/test_router.dart';
import '../../fixtures/event_model_fixtures.dart';
import '../../fixtures/post_model_fixtures.dart';
import '../../fixtures/rsvp_model_fixtures.dart';

/// `go` çağrılarını kaydeden router (yalnızca konum tablosu).
final class _RecordingRouter extends Fake implements GoRouter {
  final List<String> gone = <String>[];

  @override
  void go(String location, {Object? extra}) => gone.add(location);
}

const NotificationRefsModel _refs = NotificationRefsModel(
  clubId: 'c01',
  eventId: 'e01',
  postId: 'p01',
  applicantId: 'u02',
  reportId: 'r01',
);

const NotificationRefsModel _none = NotificationRefsModel();

String? _at(
  NotificationType type, {
  NotificationRefsModel refs = _refs,
  bool hasTicket = false,
}) => NotificationTargets.locationFor(type, refs, hasTicket: hasTicket);

GuTab? _tabOf(String location) => GuTab.ofLocation(Uri.parse(location));

void main() {
  group('T-26 · NotificationTargets.locationFor', () {
    test('her tür → beklenen konum ve sekme', () {
      const expected = <NotificationType, (String?, GuTab?)>{
        // MGT-02 + SHT-19 (`?applicant=`; W-28).
        NotificationType.applicationReceived: (
          '/clubs/c01/manage/applications?applicant=u02',
          GuTab.clubs,
        ),
        NotificationType.applicationApproved: ('/clubs/c01', GuTab.clubs),
        NotificationType.roleChanged: ('/clubs/c01', GuTab.clubs),
        NotificationType.applicationRejected: (
          '/clubs/c01/application',
          GuTab.clubs,
        ),
        NotificationType.removedFromClub: (
          '/clubs/c01/application',
          GuTab.clubs,
        ),
        NotificationType.announcement: (
          '/clubs/c01/posts/p01?tab=posts',
          GuTab.clubs,
        ),
        NotificationType.eventNew: ('/events/e01', GuTab.events),
        NotificationType.eventCancelled: (
          '/events/e01?showCancelled=true',
          GuTab.events,
        ),
        NotificationType.eventReminder: ('/events/e01', GuTab.events),
        NotificationType.waitlistPromoted: ('/events/e01', GuTab.events),
        NotificationType.reportResolved: (null, null),
        // ADM-04 + SHT-26 (`?reportId=` grup anahtarı; W-29).
        NotificationType.newReport: (
          '/admin/reports?reportId=r01',
          GuTab.admin,
        ),
        NotificationType.system: ('/profile/settings/about', GuTab.profile),
        NotificationType.unknown: ('/profile/settings/about', GuTab.profile),
      };
      expect(expected.keys, unorderedEquals(NotificationType.values));
      for (final MapEntry(key: type, value: (location, tab))
          in expected.entries) {
        final actual = _at(type);
        expect(actual, location, reason: type.name);
        if (actual != null) expect(_tabOf(actual), tab, reason: type.name);
      }
    });

    test('hatırlatma / bekleme listesi: bilet varsa TicketRoute', () {
      for (final type in [
        NotificationType.eventReminder,
        NotificationType.waitlistPromoted,
      ]) {
        expect(_at(type, hasTicket: true), '/events/e01/ticket');
        expect(_at(type), '/events/e01');
      }
    });

    test('gereken kimlik eksik → SYS-04', () {
      for (final type in [
        NotificationType.applicationReceived,
        NotificationType.applicationApproved,
        NotificationType.roleChanged,
        NotificationType.applicationRejected,
        NotificationType.removedFromClub,
        NotificationType.announcement,
        NotificationType.eventNew,
        NotificationType.eventCancelled,
        NotificationType.eventReminder,
        NotificationType.waitlistPromoted,
        NotificationType.newReport,
      ]) {
        expect(_at(type, refs: _none), AppPaths.notFound, reason: type.name);
      }
      expect(
        _at(
          NotificationType.announcement,
          refs: const NotificationRefsModel(clubId: 'c01'),
        ),
        AppPaths.notFound,
      );
    });

    test('varlık kontrolü ve gecikmeli sheet bayrakları', () {
      expect(
        NotificationType.values.where(NotificationTargets.needsExistenceCheck),
        unorderedEquals([
          NotificationType.announcement,
          NotificationType.eventNew,
          NotificationType.eventCancelled,
          NotificationType.eventReminder,
          NotificationType.waitlistPromoted,
        ]),
      );
      expect(
        NotificationType.values.where(
          NotificationTargets.opensSheetAfterNavigation,
        ),
        unorderedEquals([
          NotificationType.applicationReceived,
          NotificationType.newReport,
        ]),
      );
    });

    test('yerel hatırlatıcı yükü çözümü', () {
      expect(NotificationNavigator.parsePayload('event_reminder:e01'), 'e01');
      expect(NotificationNavigator.parsePayload('x'), isNull);
      expect(NotificationNavigator.parsePayload('event:e01'), isNull);
      expect(NotificationNavigator.parsePayload(null), isNull);
    });
  });

  group('T-26 · NotificationNavigator', () {
    const uid = FakeSessionStates.uid;
    late _RecordingRouter router;
    late NotificationNavigator navigator;
    late FakeNotificationRepository inbox;
    late FakeEventRepository events;
    late FakePostRepository posts;
    late FakeRsvpRepository rsvps;
    late FakeFeedbackService feedback;
    final post = PostModelFixtures.p01;
    final event = EventModelFixtures.e01;

    setUp(() async {
      await GetIt.I.reset();
      registerDefaultFakes();
      addTearDown(GetIt.I.reset);
      inbox = GetIt.I<NotificationRepository>() as FakeNotificationRepository;
      events = GetIt.I<EventRepository>() as FakeEventRepository;
      posts = GetIt.I<PostRepository>() as FakePostRepository;
      rsvps = GetIt.I<RsvpRepository>() as FakeRsvpRepository;
      feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
      router = _RecordingRouter();
      navigator = NotificationNavigator(
        router: router,
        userId: uid,
        isSuperAdmin: false,
      );
      events.put(event);
      posts.put(post);
    });

    NotificationModel notif(
      NotificationType type, {
      NotificationRefsModel? refs,
      bool read = false,
    }) {
      final notification = NotificationModel(
        id: 'n_${type.name}',
        userId: uid,
        type: type,
        refs:
            refs ??
            NotificationRefsModel(
              clubId: post.clubId,
              eventId: event.id,
              postId: post.id,
            ),
        read: read,
      );
      inbox.put(notification);
      return notification;
    }

    void putRsvp(RsvpStatus status) =>
        rsvps.put(RsvpModelFixtures.e01Mehmet.copyWith(status: status));

    /// Konsola düşen günlük satırları (`AppLogger` test kipinde
    /// `debugPrint`'e yazar).
    List<String> captureLogs() {
      final lines = <String>[];
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) => lines.add(message ?? '');
      addTearDown(() => debugPrint = previous);
      return lines;
    }

    test('her tür: okundu işaretlenir, hedefe `go` (tablo; reportResolved → '
        'TST-17)', () async {
      for (final type in NotificationType.values) {
        router.gone.clear();
        await navigator.open(notif(type));
        await pumpEventQueue();
        final expected = NotificationTargets.locationFor(
          type,
          notif(type).refs,
          hasTicket: false,
        );
        expect(
          router.gone,
          expected == null ? isEmpty : [expected],
          reason: type.name,
        );
        expect(
          inbox.callsTo('markRead').map((c) => c.args.single),
          contains('n_${type.name}'),
          reason: type.name,
        );
      }
      expect(feedback.toasts, [ToastId.tst17]);
    });

    test(
      'okunmuş bildirim ve `markAsRead: false` yeniden işaretlenmez',
      () async {
        await navigator.open(notif(NotificationType.eventNew, read: true));
        await navigator.open(
          notif(NotificationType.eventNew),
          markAsRead: false,
        );
        await pumpEventQueue();
        expect(inbox.callsTo('markRead'), isEmpty);
        expect(router.gone, ['/events/e01', '/events/e01']);
      },
    );

    test('hatırlatma / bekleme listesi: going, attended → bilet; waitlist, '
        'kayıt yok → etkinlik', () async {
      final expected = <RsvpStatus?, String>{
        RsvpStatus.going: '/events/e01/ticket',
        RsvpStatus.attended: '/events/e01/ticket',
        RsvpStatus.waitlist: '/events/e01',
        null: '/events/e01',
      };
      for (final MapEntry(key: status, value: location) in expected.entries) {
        if (status != null) putRsvp(status);
        for (final type in [
          NotificationType.eventReminder,
          NotificationType.waitlistPromoted,
        ]) {
          router.gone.clear();
          await navigator.open(notif(type));
          expect(router.gone, [location], reason: '$status · ${type.name}');
        }
        rsvps.rsvps.clear();
      }
    });

    test('silinmiş / gizli / başka kulübün hedefi → SYS-04', () async {
      Future<String> landing(NotificationModel n) async {
        router.gone.clear();
        await navigator.open(n);
        return router.gone.single;
      }

      posts.put(post.copyWith(isDeleted: true));
      expect(await landing(notif(NotificationType.announcement)), '/not-found');
      posts.put(post.copyWith(isHidden: true));
      expect(await landing(notif(NotificationType.announcement)), '/not-found');
      posts.put(post);
      expect(
        await landing(
          notif(
            NotificationType.announcement,
            refs: NotificationRefsModel(clubId: 'c99', postId: post.id),
          ),
        ),
        '/not-found',
      );
      // Okunamayan (yok / yetkisiz) gönderi de bulunamadı sayılır (FED-02).
      expect(
        await landing(
          notif(
            NotificationType.announcement,
            refs: const NotificationRefsModel(clubId: 'c01', postId: 'p_yok'),
          ),
        ),
        '/not-found',
      );

      events.put(event.copyWith(isDeleted: true));
      for (final type in [
        NotificationType.eventNew,
        NotificationType.eventCancelled,
        NotificationType.eventReminder,
        NotificationType.waitlistPromoted,
      ]) {
        expect(await landing(notif(type)), '/not-found', reason: type.name);
      }
    });

    test('etkinlik okunamıyor (yetki / ağ) → hedefe gidilir, ekran kendi '
        'durumunu çizer (CD-57)', () async {
      events.failNext(FirestoreError.permissionDenied);
      await navigator.open(notif(NotificationType.eventNew));
      events.failNext(FirestoreError.unavailable);
      await navigator.open(notif(NotificationType.eventCancelled));
      expect(router.gone, ['/events/e01', '/events/e01?showCancelled=true']);
    });

    test('oturum yoksa gezinme ve yazım yok', () async {
      final signedOut = NotificationNavigator(
        router: router,
        userId: null,
        isSuperAdmin: false,
      );
      await signedOut.open(notif(NotificationType.eventNew));
      await signedOut.openPayload('event_reminder:e01');
      await pumpEventQueue();
      expect(router.gone, isEmpty);
      expect(inbox.calls, isEmpty);
    });

    group('openPayload', () {
      test('going / attended → bilet, waitlist / kayıt yok → etkinlik; '
          'hatırlatıcı liste belgesi yazılır', () async {
        final expected = <RsvpStatus?, String>{
          RsvpStatus.going: '/events/e01/ticket',
          RsvpStatus.attended: '/events/e01/ticket',
          RsvpStatus.waitlist: '/events/e01',
          null: '/events/e01',
        };
        for (final MapEntry(key: status, value: location) in expected.entries) {
          rsvps.rsvps.clear();
          if (status != null) putRsvp(status);
          router.gone.clear();
          await navigator.openPayload('event_reminder:e01');
          await pumpEventQueue();
          expect(router.gone, [location], reason: '$status');
        }
        expect(
          inbox.notifications['event_reminder_e01_$uid']?.refs.clubId,
          event.clubId,
        );
        expect(inbox.callsTo('createSelf').first.args, [
          uid,
          event.id,
          event.clubId,
        ]);
      });

      test('silinmiş etkinlik → SYS-04, belge yazılmaz', () async {
        events.put(event.copyWith(isDeleted: true));
        await navigator.openPayload('event_reminder:e01');
        await pumpEventQueue();
        expect(router.gone, ['/not-found']);
        expect(inbox.callsTo('createSelf'), isEmpty);
      });

      test('bozuk yük → gezinme yok + uyarı', () async {
        final logs = captureLogs();
        for (final payload in ['x', 'event:e01', 'event_reminder:']) {
          await navigator.openPayload(payload);
        }
        expect(router.gone, isEmpty);
        expect(events.callsTo('getEvent'), isEmpty);
        expect(logs.where((l) => l.startsWith('[W]')), hasLength(3));
      });
    });
  });

  group('T-26 · NotificationNavigator · gerçek kabuk yığını', () {
    testWidgets('bildirimden hedef: sekme değişir, yığın kök → … → hedef; '
        'çağıran dalın yığını korunur', (tester) async {
      final shell = await TestRouter.pumpShell(tester);
      await shell.go('/clubs/c01');
      final clubsDepth = shell.stackDepth(GuTab.clubs);
      (GetIt.I<EventRepository>() as FakeEventRepository).put(
        EventModelFixtures.e01,
      );
      (GetIt.I<RsvpRepository>() as FakeRsvpRepository).put(
        RsvpModelFixtures.e01Mehmet.copyWith(status: RsvpStatus.going),
      );
      final navigator = NotificationNavigator(
        router: shell.router,
        userId: FakeSessionStates.uid,
        isSuperAdmin: false,
      );

      unawaited(navigator.openPayload('event_reminder:e01'));
      await tester.pumpAndSettle();

      expect(shell.location, '/events/e01/ticket');
      expect(shell.currentTab, GuTab.events);
      // `/events` → `/events/e01` → `/events/e01/ticket`.
      expect(shell.stackDepth(GuTab.events), 3);
      expect(shell.stackDepth(GuTab.clubs), clubsDepth);
    });
  });
}
