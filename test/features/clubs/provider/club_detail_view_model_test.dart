// CLB-03 · ClubDetailViewModel: ilk okuma (kulüp, yok / silinmiş, hata +
// yeniden dene), oturumdan erişim kipi ve üyelik (canlı), kişi listeleri
// (yalnızca kulübün içini görene), sekme, katılım akışı (TST-X1, bekleme,
// SHT-05 gereği, anında katılım TST-34, sunucu redleri TST-X4 / TST-X18 /
// TST-24), ayrılma (DLG-08 → TST-39, başkan DLG-09), paylaşım (TST-35,
// DLG-32, sistem paylaşımı), bağlantılar (DLG-32; e-posta açılamazsa TST-08),
// şikayet (yazım → DLG-12), art arda tetikleme (PLAN §12.6).
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_detail_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_detail_view_model.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/report_reason_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/share_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/external_link_mixin.dart';
import 'package:gu_kulupler/product/navigation/club_detail_tab.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/service/share_service.dart';
import 'package:gu_kulupler/product/service/url_launcher_service.dart';

import '../../../fakes/fake_club_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_event_repository.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_membership_repository.dart';
import '../../../fakes/fake_report_repository.dart';
import '../../../fakes/fake_rsvp_repository.dart';
import '../../../fakes/fake_share_service.dart';
import '../../../fakes/fake_url_launcher_service.dart';
import '../../../fakes/register_fakes.dart';
import '../../../fixtures/event_model_fixtures.dart';
import '../../../fixtures/rsvp_model_fixtures.dart';
import '../../../helpers/test_container.dart';
import '../club_detail_test_support.dart';

/// TST-X4 tarih biçimleyicisinin test karşılığı.
String _formatDate(DateTime instant) => 'D:${instant.toIso8601String()}';

/// Kulübün içini görmeyen kullanıcının (ziyaretçi) dolu durumu: yönetim
/// kurulu herkese okunur (CD-139), önizleme yöneticilerden kurulur.
final ClubDetailState _visitorLoaded = ClubDetailState(
  club: kClub,
  managers: kManagers,
  memberPreview: kManagers.take(4).toList(),
);

void main() {
  late FakeClubRepository clubs;
  late FakeMembershipRepository memberships;
  late FakeReportRepository reports;
  late FakeFeedbackService feedback;
  late FakeConnectivityService connectivity;
  late FakeShareService share;
  late FakeUrlLauncherService launcher;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    clubs = GetIt.I<ClubRepository>() as FakeClubRepository;
    memberships = GetIt.I<MembershipRepository>() as FakeMembershipRepository;
    reports = GetIt.I<ReportRepository>() as FakeReportRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    connectivity = GetIt.I<ConnectivityService>() as FakeConnectivityService;
    share = GetIt.I<ShareService>() as FakeShareService;
    launcher = GetIt.I<UrlLauncherService>() as FakeUrlLauncherService;
    seedClub();
  });

  /// Günlük satırlarını toplar (konsola düşmez); test sonunda özgün
  /// `debugPrint` geri kurulur.
  List<String> captureLogs() {
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    addTearDown(() => debugPrint = original);
    return logs;
  }

  /// [session] oturumuyla, ViewModel'i dinlenen kapsayıcı; [states] verilirse
  /// her state değişimi sırayla eklenir. İlk okuma **bekletilmez**.
  ProviderContainer containerOf(
    SessionState session, {
    List<ClubDetailState>? states,
  }) {
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild((ref, notifier) => session),
      ],
    );
    addTearDown(
      container
          .listen(
            clubDetailViewModelProvider(kClubId),
            (_, next) => states?.add(next),
          )
          .close,
    );
    return container;
  }

  /// İlk okuması bitmiş kapsayıcı.
  Future<ProviderContainer> loaded(
    SessionState session, {
    List<ClubDetailState>? states,
  }) async {
    final container = containerOf(session, states: states);
    await pumpEventQueue();
    states?.clear();
    // Okuma çağrıları sayılmasın: testler yalnızca eylemin çağrılarına bakar.
    clubs.calls.clear();
    memberships.calls.clear();
    return container;
  }

  ClubDetailViewModel vmOf(ProviderContainer container) =>
      container.read(clubDetailViewModelProvider(kClubId).notifier);

  ClubDetailState stateOf(ProviderContainer container) =>
      container.read(clubDetailViewModelProvider(kClubId));

  void setSession(ProviderContainer container, SessionState session) =>
      container.read(sessionViewModelProvider.notifier).state = session;

  /// Kulübü fake'te değiştirir (ekran yüklendikten sonra sunucuda değişmiş).
  void changeClub(ClubModel Function(ClubModel club) change) =>
      clubs.clubs[kClubId] = change(clubs.clubs[kClubId]!);

  /// Oturumdaki kullanıcının fake'teki üyelik belgesi (oturum bundan
  /// habersiz olabilir).
  MembershipModel membershipOf({
    required MembershipStatus status,
    ClubRole role = ClubRole.member,
    DateTime? retryAfter,
  }) => sessionWith(
    status: status,
    role: role,
    retryAfter: retryAfter,
  ).memberships[kClubId]!;

  group('CLB-03 · ClubDetailViewModel · okuma', () {
    test('başlangıç: yükleniyor; erişim kipi ve üyelik oturumdan', () {
      final session = sessionWith(status: MembershipStatus.pending);
      expect(
        stateOf(containerOf(session)),
        ClubDetailState(
          access: ClubAccess.pending,
          membership: session.memberships[kClubId],
          isFetching: true,
        ),
      );
    });

    test('ziyaretçi: kulüp ve yönetim kurulu okunur (CD-139); üye listesi '
        'sorgulanmaz, önizleme yöneticilerden kurulur', () async {
      // Başkan fake'te sona yazılır: sıra sorgudan değil kuraldan gelir.
      memberships.memberships
        ..remove(kPresident.id)
        ..[kPresident.id] = kPresident;
      final states = <ClubDetailState>[];
      final container = containerOf(kVisitorSession, states: states);
      await pumpEventQueue();

      expect(stateOf(container), _visitorLoaded);
      // Etkinlik sekmesinin ara durumları (`isEventsFetching`) ayrı sınanır.
      expect(states.where((s) => !s.isEventsFetching), [
        ClubDetailState(club: kClub),
        _visitorLoaded,
      ]);
      expect(_visitorLoaded.managers, kManagers);
      expect(_visitorLoaded.memberPreview, kManagers.take(4));
      expect(_visitorLoaded.memberPreview.first.role, ClubRole.president);
      expect(clubs.callsTo('getClub'), hasLength(1));
      expect(memberships.callsTo('listManagers').single.args, [kClubId]);
      expect(memberships.callsTo('listActiveMembers'), isEmpty);
    });

    test('ziyaretçi: yönetim kurulu okunamazsa sayfa bozulmaz, listeler boş '
        'kalır', () async {
      memberships.failNext(FirestoreError.permissionDenied);
      final container = containerOf(kVisitorSession);
      await pumpEventQueue();

      expect(stateOf(container), ClubDetailState(club: kClub));
      expect(memberships.callsTo('listActiveMembers'), isEmpty);
    });

    for (final (name, session) in [
      ('üye', sessionWith()),
      ('yönetici', sessionWith(role: ClubRole.board)),
      ('danışman', sessionWith(role: ClubRole.advisor)),
      ('süper admin', kSuperSession),
    ]) {
      test('$name: yönetim kurulu (başkan önde) ve üye önizlemesi '
          'yüklenir', () async {
        // Başkan fake'te sona yazılır: sıra sorgudan değil kuraldan gelir.
        memberships.memberships
          ..remove(kPresident.id)
          ..[kPresident.id] = kPresident;
        final container = containerOf(session);
        await pumpEventQueue();

        final state = stateOf(container);
        expect(state.club, kClub);
        expect(state.isFetching, isFalse);
        expect(state.managers, kManagers);
        expect(state.managers.first.role, ClubRole.president);
        expect(
          state.memberPreview,
          hasLength(ClubDetailState.memberPreviewLimit),
        );
        expect(
          state.memberPreview.every((m) => m.status == MembershipStatus.active),
          isTrue,
        );
        expect(memberships.callsTo('listActiveMembers').single.args, [
          kClubId,
          const PageRequest(limit: ClubDetailState.memberPreviewLimit),
          null,
        ]);
      });
    }

    test('kulüp yok → isNotFound', () async {
      clubs.clubs.clear();
      final container = containerOf(kVisitorSession);
      await pumpEventQueue();
      expect(stateOf(container), const ClubDetailState(isNotFound: true));
    });

    test('silinmiş kulüp → isNotFound', () async {
      changeClub((club) => club.copyWith(isDeleted: true));
      final container = containerOf(kVisitorSession);
      await pumpEventQueue();
      expect(stateOf(container).isNotFound, isTrue);
      expect(stateOf(container).club, isNull);
    });

    test('askıdaki kulüp okunur (SYS-04 değil)', () async {
      changeClub((club) => club.copyWith(status: ClubStatus.suspended));
      final container = containerOf(kVisitorSession);
      await pumpEventQueue();
      expect(stateOf(container).club?.isSuspended, isTrue);
      expect(stateOf(container).isNotFound, isFalse);
    });

    test('okuma hatası → isError; fetch() ile yeniden denenir', () async {
      final logs = captureLogs();
      clubs.failNext(FirestoreError.unavailable);
      final states = <ClubDetailState>[];
      final container = containerOf(kVisitorSession, states: states);
      await pumpEventQueue();
      expect(stateOf(container), const ClubDetailState(isError: true));
      expect(logs.join('\n'), contains('Kulüp okunamadı: unavailable'));

      states.clear();
      await vmOf(container).fetch();
      expect(states.where((s) => !s.isEventsFetching), [
        const ClubDetailState(isFetching: true),
        ClubDetailState(club: kClub),
        _visitorLoaded,
      ]);
    });

    test('art arda fetch(): süren okuma varken yenisi başlamaz', () async {
      final container = containerOf(kVisitorSession);
      // Açılıştaki okuma ile aynı anda gelen çağrılar tek okumaya iner.
      await Future.wait([vmOf(container).fetch(), vmOf(container).fetch()]);
      await pumpEventQueue();
      expect(clubs.callsTo('getClub'), hasLength(1));
      expect(stateOf(container), _visitorLoaded);
    });

    test(
      'kişi listeleri okunamazsa sayfa bozulmaz: listeler boş kalır',
      () async {
        // Kulüp okunur; ardından gelen ilk üyelik sorgusu (yönetim kurulu) düşer.
        memberships.failNext(FirestoreError.permissionDenied);
        final container = containerOf(sessionWith());
        await pumpEventQueue();

        final state = stateOf(container);
        expect(state.club, kClub);
        expect(state.isError, isFalse);
        expect(state.managers, isEmpty);
        expect(
          state.memberPreview,
          hasLength(ClubDetailState.memberPreviewLimit),
        );
      },
    );
  });

  group('CLB-03 · ClubDetailViewModel · oturum', () {
    test(
      'başvuru onaylanınca: kip üye olur, önizleme üye listesinden yeniden '
      'kurulur',
      () async {
        final container = await loaded(
          sessionWith(status: MembershipStatus.pending),
        );
        // Başvuran da yönetim kurulunu görür (CD-139); önizleme yöneticiler.
        expect(stateOf(container).managers, kManagers);
        expect(stateOf(container).memberPreview, kManagers.take(4));

        final approved = sessionWith();
        setSession(container, approved);
        expect(stateOf(container).access, ClubAccess.member);
        expect(stateOf(container).membership, approved.memberships[kClubId]);
        await pumpEventQueue();
        expect(stateOf(container).managers, kManagers);
        expect(
          stateOf(container).memberPreview,
          hasLength(ClubDetailState.memberPreviewLimit),
        );
        expect(memberships.callsTo('listManagers'), hasLength(1));
        expect(memberships.callsTo('listActiveMembers'), hasLength(1));
      },
    );

    test(
      'üyelik bitince: kip ziyaretçi olur, yönetim kurulu kalır, önizleme '
      'yöneticilere iner (üye listesi yeniden okunmaz)',
      () async {
        final container = await loaded(sessionWith());
        expect(stateOf(container).managers, isNotEmpty);
        expect(
          stateOf(container).memberPreview,
          isNot(kManagers.take(4)),
        );

        setSession(container, sessionWith(status: MembershipStatus.left));
        await pumpEventQueue();
        final state = stateOf(container);
        expect(state.access, ClubAccess.visitor);
        expect(state.membership?.status, MembershipStatus.left);
        expect(state.managers, kManagers);
        expect(state.memberPreview, kManagers.take(4));
        expect(memberships.callsTo('listManagers'), hasLength(1));
        expect(memberships.callsTo('listActiveMembers'), isEmpty);
      },
    );

    test(
      'üyelik belgesi silinirse (oturum kapandı) üyelik null olur',
      () async {
        final container = await loaded(
          sessionWith(status: MembershipStatus.pending),
        );
        setSession(container, kVisitorSession);
        expect(stateOf(container).membership, isNull);
        expect(stateOf(container).access, ClubAccess.visitor);
      },
    );

    test('ilgisiz oturum değişimi state yazmaz', () async {
      final states = <ClubDetailState>[];
      final container = await loaded(kVisitorSession, states: states);
      setSession(container, kVisitorSession.copyWith(blockedUserIds: {'u9'}));
      await pumpEventQueue();
      expect(states, isEmpty);
    });
  });

  group('CLB-03 · ClubDetailViewModel · etkinlikler (W-15)', () {
    late FakeEventRepository events;
    late FakeRsvpRepository rsvps;

    /// `c03` etkinlikleri (taslak dahil) + kullanıcının iki kaydı: biri bu
    /// kulüpte (`e03` bekleme listesi), biri başka kulüpte (`e01`).
    final waitlisted = RsvpModelFixtures.e01Mehmet.copyWith(
      id: FirestoreIds.rsvp('e03', kUid),
      eventId: 'e03',
      clubId: kClubId,
      status: RsvpStatus.waitlist,
    );

    setUp(() {
      events = GetIt.I<EventRepository>() as FakeEventRepository;
      rsvps = GetIt.I<RsvpRepository>() as FakeRsvpRepository;
      EventModelFixtures.ofClub(kClubId).forEach(events.put);
      rsvps
        ..put(waitlisted)
        ..put(RsvpModelFixtures.e01Mehmet);
    });

    test('ziyaretçi: yalnızca herkese açık etkinlikler (publicOnly) ve bu '
        'kulüpteki kayıtlar okunur', () async {
      final container = containerOf(kVisitorSession);
      await pumpEventQueue();
      final state = stateOf(container);

      final call = events.callsTo('listClubEvents').single;
      expect(call.args, [kClubId, const PageRequest(), false, true]);
      expect(state.events, isNotEmpty);
      expect(
        state.events.every((e) => e.visibility == EventVisibility.public),
        isTrue,
      );
      expect(state.rsvps, {'e03': waitlisted});
      expect(state.isEventsFetching, isFalse);
      expect(state.isEventsError, isFalse);
    });

    test(
      'üye: yayındaki / iptal edilmiş tüm etkinlikler; taslak yok',
      () async {
        final container = containerOf(sessionWith());
        await pumpEventQueue();
        final call = events.callsTo('listClubEvents').single;
        expect(call.args, [kClubId, const PageRequest(), false, false]);
        final ids = stateOf(container).events.map((e) => e.id);
        expect(ids, contains('e16')); // üyelere özel
        expect(ids, isNot(contains('e22'))); // taslak
      },
    );

    test('okuma hatası → isEventsError; fetchEvents() yeniden dener', () async {
      final container = containerOf(kVisitorSession);
      events.failNext(FirestoreError.unavailable);
      await pumpEventQueue();
      expect(stateOf(container).isEventsError, isTrue);
      expect(stateOf(container).events, isEmpty);

      await vmOf(container).fetchEvents();
      expect(stateOf(container).isEventsError, isFalse);
      expect(stateOf(container).events, isNotEmpty);
    });

    test('kayıtlar okunamazsa etkinlikler yine yüklenir (rozetsiz)', () async {
      final container = containerOf(kVisitorSession);
      rsvps.failNext(FirestoreError.unavailable);
      await pumpEventQueue();
      expect(stateOf(container).events, isNotEmpty);
      expect(stateOf(container).rsvps, isEmpty);
      expect(stateOf(container).isEventsError, isFalse);
    });

    test(
      'kip değişince (ziyaretçi → üye) etkinlikler yeniden okunur',
      () async {
        final container = await loaded(kVisitorSession);
        events.calls.clear();
        setSession(container, sessionWith());
        await pumpEventQueue();
        expect(
          events.callsTo('listClubEvents').single.args,
          [kClubId, const PageRequest(), false, false],
        );
        expect(stateOf(container).events.map((e) => e.id), contains('e16'));
      },
    );

    test('TST-X2: "Kayıtlar kapalı" kartı', () async {
      final container = await loaded(kVisitorSession);
      vmOf(container).showRegistrationClosed();
      expect(feedback.toasts, [ToastId.tstX2]);
    });
  });

  group('CLB-03 · ClubDetailViewModel · sekme', () {
    test('setTab sekmeyi değiştirir; aynı sekme state yazmaz', () async {
      final states = <ClubDetailState>[];
      final container = await loaded(kVisitorSession, states: states);
      vmOf(container).setTab(ClubDetailTab.members);
      expect(stateOf(container).tab, ClubDetailTab.members);
      vmOf(container).setTab(ClubDetailTab.members);
      expect(states, hasLength(1));
    });
  });

  group('CLB-03 · ClubDetailViewModel · katılım', () {
    Future<JoinOutcome> start(
      ProviderContainer container, {
      VoidCallback? onOpenClub,
    }) => vmOf(container).startJoin(
      formatDate: _formatDate,
      onOpenClub: onOpenClub,
    );

    void makeInstant() =>
        changeClub((club) => club.copyWith(approvalRequired: false));

    test('kulüp yüklenmeden → failed; hiçbir şey olmaz', () async {
      final container = containerOf(kVisitorSession);
      expect(await start(container), JoinOutcome.failed);
      expect(feedback.toasts, isEmpty);
    });

    test('başvurular kapalı → TST-X1; sunucuya gidilmez', () async {
      changeClub((club) => club.copyWith(applicationsOpen: false));
      final container = await loaded(kVisitorSession);
      expect(await start(container), JoinOutcome.closed);
      expect(feedback.toasts, [ToastId.tstX1]);
      expect(memberships.calls, isEmpty);
    });

    test('askıdaki kulüp → failed', () async {
      changeClub((club) => club.copyWith(status: ClubStatus.suspended));
      final container = await loaded(kVisitorSession);
      expect(await start(container), JoinOutcome.failed);
      expect(feedback.toasts, isEmpty);
      expect(memberships.calls, isEmpty);
    });

    test('yeniden başvuru beklemesi sürüyor → waiting (CLB-05); bildirim '
        'yok', () async {
      makeInstant();
      final container = await loaded(
        sessionWith(
          status: MembershipStatus.rejected,
          retryAfter: kDefaultFakeNowUtc.add(const Duration(days: 2)),
        ),
      );
      expect(await start(container), JoinOutcome.waiting);
      expect(feedback.toasts, isEmpty);
      expect(memberships.calls, isEmpty);
    });

    test('onay isteyen kulüp → needsApplication (SHT-05); sunucuya '
        'gidilmez', () async {
      final container = await loaded(kVisitorSession);
      expect(await start(container), JoinOutcome.needsApplication);
      expect(feedback.toasts, isEmpty);
      expect(memberships.calls, isEmpty);
    });

    for (final status in [
      MembershipStatus.rejected,
      MembershipStatus.removed,
      MembershipStatus.cancelled,
    ]) {
      test(
        'onaysız kulüp + eski kayıt (${status.name}) → needsApplication',
        () async {
          makeInstant();
          final container = await loaded(sessionWith(status: status));
          expect(await start(container), JoinOutcome.needsApplication);
          expect(memberships.calls, isEmpty);
        },
      );
    }

    test('onaysız kulüp → katılır: TST-34 ("Kulübe git"), üye sayısı '
        'yenilenir', () async {
      makeInstant();
      final states = <ClubDetailState>[];
      final container = await loaded(kVisitorSession, states: states);
      var opened = 0;

      expect(
        await start(container, onOpenClub: () => opened++),
        JoinOutcome.joined,
      );
      expect(memberships.applied.single, (
        clubId: kClubId,
        userId: kUid,
        email: kEmail,
        note: '',
        status: MembershipStatus.active,
      ));
      expect(feedback.toasts, [ToastId.tst34]);
      expect(feedback.hasToastAction, isTrue);
      feedback.tapToastAction();
      expect(opened, 1);
      // Süren işlem bayrağı açılıp kapanır.
      expect(states.map((s) => s.isActing).take(2), [true, false]);

      await pumpEventQueue();
      expect(stateOf(container).club?.memberCount, kClub.memberCount + 1);
      expect(stateOf(container).isRefreshing, isFalse);
    });

    test('"Kulübe git" verilmezse TST-34 eylemsizdir', () async {
      makeInstant();
      final container = await loaded(kVisitorSession);
      expect(await start(container), JoinOutcome.joined);
      expect(feedback.toasts, [ToastId.tst34]);
      expect(feedback.hasToastAction, isFalse);
    });

    test(
      'kulüpten ayrılmış kullanıcı onaysız kulübe yeniden katılır',
      () async {
        makeInstant();
        memberships.put(membershipOf(status: MembershipStatus.left));
        final container = await loaded(
          sessionWith(status: MembershipStatus.left),
        );
        expect(await start(container), JoinOutcome.joined);
      },
    );

    test('çevrimdışı → TST-24; sunucuya gidilmez', () async {
      makeInstant();
      final container = await loaded(kVisitorSession);
      connectivity.isOffline = true;
      expect(await start(container), JoinOutcome.failed);
      expect(feedback.toasts, [ToastId.tst24]);
      expect(memberships.calls, isEmpty);
      expect(stateOf(container).isActing, isFalse);
    });

    test('oturumda profil yok → failed; günlüğe düşer', () async {
      final logs = captureLogs();
      makeInstant();
      final container = await loaded(
        kVisitorSession.copyWith(clearUser: true),
      );
      expect(await start(container), JoinOutcome.failed);
      expect(memberships.calls, isEmpty);
      expect(logs.join('\n'), contains('oturumda profil / e-posta yok'));
    });

    test('art arda dokunma: tek katılım yazılır', () async {
      makeInstant();
      final container = await loaded(kVisitorSession);
      final results = await Future.wait([start(container), start(container)]);
      expect(results, [JoinOutcome.joined, JoinOutcome.failed]);
      expect(memberships.callsTo('joinInstant'), hasLength(1));
      expect(feedback.toasts, [ToastId.tst34]);
    });

    test('sunucu: başvurular bu arada kapanmış → TST-X1; kulüp '
        'yenilenir', () async {
      makeInstant();
      final container = await loaded(kVisitorSession);
      changeClub((club) => club.copyWith(applicationsOpen: false));

      expect(await start(container), JoinOutcome.closed);
      expect(feedback.toasts, [ToastId.tstX1]);
      await pumpEventQueue();
      expect(stateOf(container).club?.applicationsOpen, isFalse);
    });

    test('sunucu: bekleme süresi (oturum eski) → TST-X4 {tarih}', () async {
      makeInstant();
      final retryAfter = kDefaultFakeNowUtc.add(const Duration(days: 5));
      final container = await loaded(kVisitorSession);
      memberships.put(
        membershipOf(
          status: MembershipStatus.rejected,
          retryAfter: retryAfter,
        ),
      );

      expect(await start(container), JoinOutcome.cooldown);
      expect(feedback.toasts, [ToastId.tstX4]);
      expect(feedback.toastParams.single.date, _formatDate(retryAfter));
    });

    test('sunucu: eski kayıt incelemeye gitmeli (oturum eski) → '
        'needsApplication', () async {
      makeInstant();
      final container = await loaded(kVisitorSession);
      memberships.put(membershipOf(status: MembershipStatus.cancelled));

      expect(await start(container), JoinOutcome.needsApplication);
      expect(feedback.toasts, isEmpty);
    });

    test('sunucu: kulüp bu arada onaya geçmiş (çakışma) → kulüp yenilenir, '
        'needsApplication', () async {
      makeInstant();
      final container = await loaded(kVisitorSession);
      changeClub((club) => club.copyWith(approvalRequired: true));

      expect(await start(container), JoinOutcome.needsApplication);
      expect(stateOf(container).club?.approvalRequired, isTrue);
      expect(feedback.toasts, isEmpty);
    });

    test('sunucu: zaten üye (çakışma) → failed; form açılmaz', () async {
      makeInstant();
      final container = await loaded(kVisitorSession);
      memberships.put(membershipOf(status: MembershipStatus.active));

      expect(await start(container), JoinOutcome.failed);
      expect(feedback.toasts, isEmpty);
    });

    test('sunucu: kulüp silinmiş → isNotFound', () async {
      makeInstant();
      final container = await loaded(kVisitorSession);
      clubs.clubs.remove(kClubId);

      expect(await start(container), JoinOutcome.failed);
      expect(stateOf(container).isNotFound, isTrue);
    });

    for (final (error, toast) in [
      (FirestoreError.permissionDenied, ToastId.tstX18),
      (FirestoreError.unavailable, ToastId.tst24),
      (FirestoreError.timeout, ToastId.tst24),
    ]) {
      test('sunucu: ${error.name} → ${toast.name}', () async {
        makeInstant();
        final container = await loaded(kVisitorSession);
        memberships.failNext(error);

        expect(await start(container), JoinOutcome.failed);
        expect(feedback.toasts, [toast]);
        expect(stateOf(container).isActing, isFalse);
      });
    }

    test('sunucu: beklenmeyen hata → günlük + kulüp yenilenir; bildirim '
        'yok', () async {
      final logs = captureLogs();
      makeInstant();
      final container = await loaded(kVisitorSession);
      memberships.failNext(FirestoreError.unknown);

      expect(await start(container), JoinOutcome.failed);
      expect(feedback.toasts, isEmpty);
      expect(logs.join('\n'), contains('Kulübe katılınamadı: unknown'));
      await pumpEventQueue();
      expect(clubs.callsTo('getClub'), hasLength(1));
    });

    test('showApplicationsClosed → TST-X1', () async {
      final container = await loaded(kVisitorSession);
      vmOf(container).showApplicationsClosed();
      expect(feedback.toasts, [ToastId.tstX1]);
    });

    test('showJoined → TST-34 + kulüp yenilenir (SHT-05 katılımla '
        'kapandı)', () async {
      final container = await loaded(kVisitorSession);
      vmOf(container).showJoined();
      expect(feedback.toasts, [ToastId.tst34]);
      await pumpEventQueue();
      expect(clubs.callsTo('getClub'), hasLength(1));
    });
  });

  group('CLB-03 · ClubDetailViewModel · ayrılma', () {
    /// Oturumdaki kullanıcıyı fake'te de [role] rolüyle üye yapar.
    Future<ProviderContainer> asMember({
      ClubRole role = ClubRole.member,
      ClubRole? serverRole,
    }) async {
      memberships.put(
        membershipOf(status: MembershipStatus.active, role: serverRole ?? role),
      );
      return loaded(sessionWith(role: role));
    }

    test('DLG-08 onayı → ayrılır: TST-39, üye sayısı yenilenir', () async {
      final container = await asMember();
      feedback.nextDialogResult = true;

      expect(await vmOf(container).leave(), LeaveOutcome.left);
      expect(feedback.dialogs, [DialogId.dlg08]);
      expect(feedback.dialogParams.single, {DialogParamKeys.club: kClub.name});
      expect(memberships.callsTo('leave').single.args, [kClubId, kUid]);
      expect(feedback.toasts, [ToastId.tst39]);
      await pumpEventQueue();
      expect(stateOf(container).club?.memberCount, kClub.memberCount - 1);
    });

    for (final answer in [false, null]) {
      test('DLG-08 "$answer" → cancelled; yazılmaz', () async {
        final container = await asMember();
        feedback.nextDialogResult = answer;

        expect(await vmOf(container).leave(), LeaveOutcome.cancelled);
        expect(memberships.callsTo('leave'), isEmpty);
        expect(feedback.toasts, isEmpty);
      });
    }

    test('başkan: onay sorulmadan DLG-09; "Tamam" → solePresident', () async {
      final container = await asMember(role: ClubRole.president);

      expect(await vmOf(container).leave(), LeaveOutcome.solePresident);
      expect(feedback.dialogs, [DialogId.dlg09]);
      expect(memberships.callsTo('leave'), isEmpty);
    });

    test('başkan: DLG-09 "Başkanlığı devret" → transferRequested', () async {
      final container = await asMember(role: ClubRole.president);
      feedback.nextDialogResult = true;

      expect(await vmOf(container).leave(), LeaveOutcome.transferRequested);
      expect(feedback.dialogs, [DialogId.dlg09]);
    });

    test('sunucu "başkan ayrılamaz" derse (oturum eski) DLG-09', () async {
      final container = await asMember(
        role: ClubRole.board,
        serverRole: ClubRole.president,
      );
      feedback.nextDialogResult = true;

      // DLG-08 "Kulüpten ayrıl" → sunucu reddi → DLG-09 (kapatıldı).
      expect(await vmOf(container).leave(), LeaveOutcome.solePresident);
      expect(feedback.dialogs, [DialogId.dlg08, DialogId.dlg09]);
      expect(feedback.toasts, isEmpty);
    });

    test('onaydan sonra çevrimdışı → TST-24; yazılmaz', () async {
      final container = await asMember();
      feedback.nextDialogResult = true;
      connectivity.isOffline = true;

      expect(await vmOf(container).leave(), LeaveOutcome.failed);
      expect(feedback.toasts, [ToastId.tst24]);
      expect(memberships.callsTo('leave'), isEmpty);
    });

    for (final (error, toast) in [
      (FirestoreError.permissionDenied, ToastId.tstX18),
      (FirestoreError.unavailable, ToastId.tst24),
    ]) {
      test('sunucu: ${error.name} → ${toast.name}', () async {
        final container = await asMember();
        feedback.nextDialogResult = true;
        memberships.failNext(error);

        expect(await vmOf(container).leave(), LeaveOutcome.failed);
        expect(feedback.toasts, [toast]);
        expect(stateOf(container).isActing, isFalse);
      });
    }

    test(
      'üyelik bu arada bitmiş (çakışma) → failed; günlük + yenileme',
      () async {
        final logs = captureLogs();
        final container = await loaded(sessionWith());
        feedback.nextDialogResult = true;

        expect(await vmOf(container).leave(), LeaveOutcome.failed);
        expect(feedback.toasts, isEmpty);
        expect(logs.join('\n'), contains('Kulüpten ayrılınamadı: conflict'));
      },
    );

    test('oturum yok → failed; dialog açılmaz', () async {
      final container = await loaded(
        sessionWith().copyWith(clearUid: true),
      );
      expect(await vmOf(container).leave(), LeaveOutcome.failed);
      expect(feedback.dialogs, isEmpty);
    });

    test('art arda çağrı: tek onay dialogu, tek yazım', () async {
      final container = await asMember();
      feedback.nextDialogResult = true;

      final results = await Future.wait([
        vmOf(container).leave(),
        vmOf(container).leave(),
      ]);
      expect(results, [LeaveOutcome.left, LeaveOutcome.failed]);
      expect(feedback.dialogs, [DialogId.dlg08]);
      expect(memberships.callsTo('leave'), hasLength(1));
    });
  });

  group('CLB-03 · ClubDetailViewModel · paylaşım ve bağlantılar', () {
    const url = '${AppConstants.shareBaseUrl}/clubs/$kClubId';

    test('shareUrl: paylaşım kökü + kulüp yolu', () async {
      final container = await loaded(kVisitorSession);
      expect(vmOf(container).shareUrl(), url);
    });

    test('kopyala → pano + TST-35', () async {
      final container = await loaded(kVisitorSession);
      await vmOf(container).share(ShareChoice.copyLink);
      expect(share.copied, [url]);
      expect(feedback.toasts, [ToastId.tst35]);
    });

    test('kopyalanamazsa bildirim yok', () async {
      final container = await loaded(kVisitorSession);
      share.canCopy = false;
      await vmOf(container).share(ShareChoice.copyLink);
      expect(feedback.toasts, isEmpty);
    });

    test('WhatsApp → DLG-32 onayı → adres açılır', () async {
      final container = await loaded(kVisitorSession);
      feedback.dialogResults[DialogId.dlg32] = true;
      await vmOf(container).share(ShareChoice.whatsapp);
      expect(feedback.dialogs, [DialogId.dlg32]);
      expect(launcher.opened, [ShareLinks.whatsApp(url)]);
    });

    test('e-posta → DLG-32; vazgeçilirse açılmaz', () async {
      final container = await loaded(kVisitorSession);
      await vmOf(container).share(ShareChoice.email);
      expect(feedback.dialogs, [DialogId.dlg32]);
      expect(launcher.opened, isEmpty);

      feedback.dialogResults[DialogId.dlg32] = true;
      await vmOf(container).share(ShareChoice.email);
      expect(launcher.opened, [ShareLinks.email(kClub.name)]);
    });

    test('"Diğer…" → sistem paylaşım sayfası (bağlantı + kulüp adı)', () async {
      final container = await loaded(kVisitorSession);
      await vmOf(container).share(ShareChoice.other);
      expect(share.sharedTexts, [url]);
      expect(share.subjects, [kClub.name]);
      expect(feedback.toasts, isEmpty);
    });

    test('kulüp yüklenmeden paylaşım yapılmaz', () async {
      final container = containerOf(kVisitorSession);
      await vmOf(container).share(ShareChoice.copyLink);
      expect(share.copied, isEmpty);
    });

    test('e-posta bağlantısı → DLG-32 → mailto açılır', () async {
      final container = await loaded(kVisitorSession);
      feedback.dialogResults[DialogId.dlg32] = true;
      await vmOf(container).openEmail();
      expect(feedback.dialogs, [DialogId.dlg32]);
      expect(launcher.opened, [ExternalLinks.mail(kClub.social.email!)]);
      expect(feedback.toasts, isEmpty);
    });

    test('e-posta: vazgeçilirse açılmaz, kopyalanmaz', () async {
      final container = await loaded(kVisitorSession);
      await vmOf(container).openEmail();
      expect(launcher.opened, isEmpty);
      expect(share.copied, isEmpty);
    });

    test('e-posta cihazda açılamazsa adres kopyalanır → TST-08', () async {
      final container = await loaded(kVisitorSession);
      feedback.dialogResults[DialogId.dlg32] = true;
      launcher.canOpen = false;
      await vmOf(container).openEmail();
      expect(share.copied, [kClub.social.email]);
      expect(feedback.toasts, [ToastId.tst08]);
    });

    test('copyEmail → pano + TST-08; e-posta yoksa etkisiz', () async {
      final container = await loaded(kVisitorSession);
      await vmOf(container).copyEmail();
      expect(share.copied, [kClub.social.email]);
      expect(feedback.toasts, [ToastId.tst08]);

      changeClub((club) => club.copyWith(social: const ClubSocialModel()));
      await vmOf(container).refresh();
      await vmOf(container).copyEmail();
      expect(share.copied, hasLength(1));
    });

    test('Instagram ve web → DLG-32 → adres açılır', () async {
      final container = await loaded(kVisitorSession);
      feedback.dialogResults[DialogId.dlg32] = true;
      await vmOf(container).openInstagram();
      await vmOf(container).openWeb();
      expect(feedback.dialogs, [DialogId.dlg32, DialogId.dlg32]);
      expect(launcher.opened, [
        ExternalLinks.instagram(kClub.social.instagram!),
        ExternalLinks.web(kClub.social.web!),
      ]);
      // Açılamayan Instagram / web adresi kopyalanmaz.
      launcher.canOpen = false;
      await vmOf(container).openWeb();
      expect(share.copied, isEmpty);
    });

    test('bağlantısı olmayan kulüpte dialog açılmaz', () async {
      changeClub((club) => club.copyWith(social: const ClubSocialModel()));
      final container = await loaded(kVisitorSession);
      await vmOf(container).openEmail();
      await vmOf(container).openInstagram();
      await vmOf(container).openWeb();
      expect(feedback.dialogs, isEmpty);
    });

    test('openExternal: izinsiz şema sorulmadan reddedilir', () async {
      final container = await loaded(kVisitorSession);
      expect(
        await vmOf(container).openExternal(Uri(scheme: 'tel', path: '112')),
        ExternalLinkResult.failed,
      );
      expect(feedback.dialogs, isEmpty);
    });
  });

  group('CLB-03 · ClubDetailViewModel · şikayet', () {
    const target = (type: ReportTargetType.club, id: kClubId, clubId: kClubId);
    const report = ReportReasonResult(
      target: target,
      reason: ReportReason.other,
      note: 'Yanıltıcı tanıtım.',
    );

    test('reportTarget: bu kulüp', () async {
      final container = await loaded(kVisitorSession);
      expect(vmOf(container).reportTarget, target);
    });

    test('submitReport: yazılır → true', () async {
      final container = await loaded(kVisitorSession);
      expect(await vmOf(container).submitReport(report), isTrue);
      final written = reports.reports.values.single;
      expect(written.reporterId, kUid);
      expect(written.targetType, ReportTargetType.club);
      expect(written.targetId, kClubId);
      expect(written.targetClubId, kClubId);
      expect(written.reason, ReportReason.other);
      expect(written.note, 'Yanıltıcı tanıtım.');
      expect(feedback.toasts, isEmpty);
    });

    test('aynı kulüp ikinci kez → yine true (DLG-12 gösterilir)', () async {
      final container = await loaded(kVisitorSession);
      expect(await vmOf(container).submitReport(report), isTrue);
      expect(await vmOf(container).submitReport(report), isTrue);
      expect(reports.reports, hasLength(1));
    });

    test('çevrimdışı → TST-24, false; yazılmaz', () async {
      final container = await loaded(kVisitorSession);
      connectivity.isOffline = true;
      expect(await vmOf(container).submitReport(report), isFalse);
      expect(feedback.toasts, [ToastId.tst24]);
      expect(reports.calls, isEmpty);
    });

    for (final (error, toast) in [
      (FirestoreError.permissionDenied, ToastId.tstX18),
      (FirestoreError.unavailable, ToastId.tst24),
    ]) {
      test('sunucu: ${error.name} → ${toast.name}, false', () async {
        final container = await loaded(kVisitorSession);
        reports.failNext(error);
        expect(await vmOf(container).submitReport(report), isFalse);
        expect(feedback.toasts, [toast]);
      });
    }

    test('beklenmeyen hata → false; günlüğe düşer', () async {
      final logs = captureLogs();
      final container = await loaded(kVisitorSession);
      reports.failNext(FirestoreError.unknown);
      expect(await vmOf(container).submitReport(report), isFalse);
      expect(feedback.toasts, isEmpty);
      expect(logs.join('\n'), contains('Şikayet gönderilemedi: unknown'));
    });

    test('oturum yok → false', () async {
      final container = await loaded(
        kVisitorSession.copyWith(clearUid: true),
      );
      expect(await vmOf(container).submitReport(report), isFalse);
      expect(reports.calls, isEmpty);
    });

    test('showReportReceived → DLG-12 (engelleme seçeneği yok)', () async {
      final container = await loaded(kVisitorSession);
      await vmOf(container).showReportReceived();
      expect(feedback.dialogs, [DialogId.dlg12]);
      expect(feedback.dialogParams.single, isEmpty);
    });
  });

  group('CLB-03 · ClubDetailViewModel · yenileme', () {
    test('refresh: kulüp ve kişi listeleri yenilenir; iskelet yok', () async {
      final states = <ClubDetailState>[];
      final container = await loaded(sessionWith(), states: states);
      changeClub((club) => club.copyWith(memberCount: 500));

      await vmOf(container).refresh();
      expect(states.first.isRefreshing, isTrue);
      expect(states.every((s) => !s.isFetching), isTrue);
      expect(stateOf(container).club?.memberCount, 500);
      expect(stateOf(container).isRefreshing, isFalse);
      expect(memberships.callsTo('listManagers'), hasLength(1));
    });

    test('refresh: okunamazsa var olan içerik kalır', () async {
      final logs = captureLogs();
      final container = await loaded(kVisitorSession);
      clubs.failNext(FirestoreError.unavailable);

      await vmOf(container).refresh();
      expect(stateOf(container), _visitorLoaded);
      expect(logs.join('\n'), contains('Kulüp yenilenemedi: unavailable'));
    });

    test('refresh: kulüp silinmişse isNotFound', () async {
      final container = await loaded(kVisitorSession);
      clubs.clubs.remove(kClubId);
      await vmOf(container).refresh();
      expect(stateOf(container).isNotFound, isTrue);
    });

    test('art arda refresh(): tek okuma', () async {
      final container = await loaded(kVisitorSession);
      await Future.wait([vmOf(container).refresh(), vmOf(container).refresh()]);
      expect(clubs.callsTo('getClub'), hasLength(1));
    });
  });
}
