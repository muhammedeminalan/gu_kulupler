// MGT-04 · ManageEventsViewModel: yükleme (taslaklar dahil tek sayfa) ve
// sekmeler (yayında / taslak / geçmiş / iptal, sıra); ortak
// `ManageEventActionsMixin` SHT-23 akışları: çoğalt (+7 gün, kapak yok,
// TST-13 → MGT-05), taslağa al (K-F: kayıtlı varken yazım yok; başarı
// TST-X19), kayıtları aç / kapat (TST-X15), iptal (DLG-23 nedeni →
// bildirim + TST-48; hata → geri alınır), taslak silme (yalnız taslak;
// DLG-31 → TST-45 "Geri al"); danışman TST-26 — PLAN §12.6, roadmap T-34.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/manage_events_view_model.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/event_menu_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/manage_event_actions_mixin.dart';
import 'package:gu_kulupler/product/navigation/manage_events_tab.dart';

import '../../../fakes/fake_event_repository.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_management_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/test_container.dart';
import '../manage_test_support.dart';

const ManageEventTexts _texts = (copySuffix: ' (kopya)', draftLabel: 'Taslak');

void main() {
  late FakeEventRepository events;
  late FakeManagementRepository management;
  late FakeFeedbackService feedback;

  final provider = manageEventsViewModelProvider(kManageClubId);

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    events = GetIt.I<EventRepository>() as FakeEventRepository;
    management = GetIt.I<ManagementRepository>() as FakeManagementRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    seedManage();
  });

  Future<ProviderContainer> loaded({SessionState? session}) async {
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild(
          (ref, notifier) => session ?? manageSession(),
        ),
      ],
    );
    addTearDown(container.listen(provider, (_, _) {}).close);
    await pumpEventQueue();
    return container;
  }

  ManageEventsViewModel vm(ProviderContainer c) => c.read(provider.notifier);

  EventModel event(ProviderContainer c, String id) =>
      c.read(provider).find(id)!;

  List<String> tabIds(ProviderContainer c, ManageEventsTab tab) => [
    for (final e in c.read(provider).eventsOf(tab, kDefaultFakeNowUtc)) e.id,
  ];

  group('MGT-04 · yükleme ve sekmeler', () {
    test('taslaklar dahil tek sayfa; sekmeler istemcide, yayında en yakın '
        'üstte', () async {
      final container = await loaded();
      final state = container.read(provider);
      expect(state.isFetching, isFalse);
      expect(state.club, kManageClub);
      final call = events.callsTo('listClubEvents').single;
      expect(call.args[0], kManageClubId);
      expect(call.args[2], isTrue, reason: 'includeDrafts');
      expect(tabIds(container, ManageEventsTab.published), ['e03', 'e16']);
      expect(tabIds(container, ManageEventsTab.draft), ['e22']);
      expect(tabIds(container, ManageEventsTab.past), ['e19']);
      expect(tabIds(container, ManageEventsTab.cancelled), isEmpty);

      expect(state.tab, ManageEventsTab.published);
      vm(container).setTab(ManageEventsTab.draft);
      expect(container.read(provider).tab, ManageEventsTab.draft);
    });

    test('okunamazsa hata; "Yeniden dene" okur', () async {
      events.failNext(FirestoreError.unavailable);
      final container = await loaded();
      expect(container.read(provider).isError, isTrue);
      await vm(container).fetch();
      expect(container.read(provider).isError, isFalse);
      expect(tabIds(container, ManageEventsTab.published), ['e03', 'e16']);
    });
  });

  group('MGT-04 · SHT-23 akışları', () {
    test('çoğalt: +7 gün, başlık soneki, taslak, kapak yok → TST-13; '
        'kopya düzenlemeye açılır', () async {
      final container = await loaded();
      final source = event(container, 'e03');
      feedback.nextSheetResult = EventMenuAction.duplicate;
      final outcome = await vm(container).openMenu(source, _texts);

      expect(feedback.sheets, [SheetId.sht23]);
      final copy = events.created.single;
      expect(outcome, (next: ManageEventNext.edit, eventId: copy.id));
      expect(copy.status, EventStatus.draft);
      expect(copy.startsAt, source.startsAt.add(const Duration(days: 7)));
      expect(copy.endsAt, source.endsAt.add(const Duration(days: 7)));
      expect(copy.title, '${source.title} (kopya)');
      expect(copy.coverPath, isNull);
      expect(copy.goingCount, 0);
      expect(feedback.toasts, [ToastId.tst13]);
      expect(tabIds(container, ManageEventsTab.draft), contains(copy.id));
    });

    test('K-F: kayıtlı varken "Taslağa al" devre dışı ve yazılmaz', () async {
      final container = await loaded();
      final e03 = event(container, 'e03');
      expect(
        EventMenuSheet.actionsOf(e03, kDefaultFakeNowUtc),
        contains(
          const EventMenuOption(EventMenuAction.unpublish, enabled: false),
        ),
      );
      expect(await vm(container).unpublishEvent(e03), isFalse);
      expect(management.callsTo('unpublishEvent'), isEmpty);
      expect(event(container, 'e03').status, EventStatus.published);
    });

    test('taslağa al (kayıtsız): taslak sekmesine geçer → TST-X19', () async {
      events.put(events.events['e16']!.copyWith(goingCount: 0));
      final container = await loaded();
      feedback.nextSheetResult = EventMenuAction.unpublish;
      await vm(container).openMenu(event(container, 'e16'), _texts);
      expect(management.callsTo('unpublishEvent').single.args, ['e16']);
      expect(event(container, 'e16').status, EventStatus.draft);
      expect(tabIds(container, ManageEventsTab.draft), contains('e16'));
      expect(feedback.toasts, [ToastId.tstX19]);
    });

    test('iptal: DLG-23 nedeni → cancelEvent (bildirim) → TST-48', () async {
      final container = await loaded();
      feedback
        ..nextSheetResult = EventMenuAction.cancel
        ..dialogResults[DialogId.dlg23] = 'weather';
      await vm(container).openMenu(event(container, 'e03'), _texts);
      expect(feedback.dialogs, [DialogId.dlg23]);
      expect(management.callsTo('cancelEvent').single.args, [
        'e03',
        kManageClubId,
        'weather',
        kManageUid,
      ]);
      expect(management.fanOuts.single.kind, NotificationType.eventCancelled);
      final cancelled = event(container, 'e03');
      expect(cancelled.status, EventStatus.cancelled);
      expect(cancelled.cancelReason, 'weather');
      expect(tabIds(container, ManageEventsTab.cancelled), ['e03']);
      expect(feedback.toasts, [ToastId.tst48]);
    });

    test('iptal yazılamazsa iyimser değişiklik geri alınır → TST-24', () async {
      final container = await loaded();
      feedback.dialogResults[DialogId.dlg23] = 'venue';
      management.failNext(FirestoreError.unavailable);
      expect(await vm(container).cancelEvent(event(container, 'e03')), isFalse);
      expect(event(container, 'e03').status, EventStatus.published);
      expect(feedback.toasts, [ToastId.tst24]);
    });

    test('TST-X15: kayıtları kapat / aç → setRegistrationOpen; iptalde '
        'yazım yok', () async {
      final container = await loaded();
      expect(
        await vm(
          container,
        ).setRegistrationOpen(event(container, 'e16'), open: false),
        isTrue,
      );
      expect(event(container, 'e16').registrationOpen, isFalse);
      expect(events.events['e16']!.registrationOpen, isFalse);
      expect(feedback.toasts, [ToastId.tstX15]);
      expect(feedback.toastParams.last.open, isFalse);
      await vm(
        container,
      ).setRegistrationOpen(event(container, 'e16'), open: true);
      expect(feedback.toastParams.last.open, isTrue);
      final cancelled = event(
        container,
        'e03',
      ).copyWith(status: EventStatus.cancelled);
      expect(
        await vm(container).setRegistrationOpen(cancelled, open: false),
        isFalse,
      );
      expect(events.callsTo('setRegistrationOpen'), hasLength(2));
    });

    test('taslak silme yalnız taslakta: yayındaki etkinlikte dialog ve '
        'yazım yok', () async {
      final container = await loaded();
      final removed = await vm(
        container,
      ).softDeleteDraft(event(container, 'e03'), draftLabel: 'Taslak');
      expect(removed, isFalse);
      expect(feedback.dialogs, isEmpty);
      expect(events.callsTo('softDeleteEvent'), isEmpty);
    });

    test(
      'taslak sil: DLG-31 → düşer + TST-45 "Geri al" → geri gelir',
      () async {
        final container = await loaded();
        feedback
          ..nextSheetResult = EventMenuAction.delete
          ..dialogResults[DialogId.dlg31] = true;
        final outcome = await vm(
          container,
        ).openMenu(event(container, 'e22'), _texts);
        expect(outcome.next, ManageEventNext.removed);
        expect(feedback.dialogs, [DialogId.dlg31]);
        expect(events.callsTo('softDeleteEvent').single.args, [
          'e22',
          kManageUid,
        ]);
        expect(events.events['e22']!.isDeleted, isTrue);
        expect(tabIds(container, ManageEventsTab.draft), isEmpty);
        expect(feedback.toasts, [ToastId.tst45]);
        expect(feedback.toastParams.last.what, 'Taslak');

        feedback.tapToastAction();
        await pumpEventQueue();
        expect(events.callsTo('restoreEvent').single.args, ['e22']);
        expect(events.events['e22']!.isDeleted, isFalse);
        expect(tabIds(container, ManageEventsTab.draft), ['e22']);
      },
    );

    test(
      "düzenle → MGT-05; katılımcılar → MGT-06 (gezinme view'da)",
      () async {
        final container = await loaded();
        final e03 = event(container, 'e03');
        feedback.nextSheetResult = EventMenuAction.edit;
        expect(await vm(container).openMenu(e03, _texts), (
          next: ManageEventNext.edit,
          eventId: 'e03',
        ));
        feedback.nextSheetResult = EventMenuAction.attendees;
        expect(
          (await vm(container).openMenu(e03, _texts)).next,
          ManageEventNext.attendees,
        );
        expect(feedback.toasts, isEmpty);
      },
    );

    test('danışman: düzenle / çoğalt → TST-26, yazım yok', () async {
      final container = await loaded(
        session: manageSession(role: ClubRole.advisor),
      );
      expect(container.read(provider).isReadOnly, isTrue);
      final e03 = event(container, 'e03');
      feedback.nextSheetResult = EventMenuAction.edit;
      expect(
        (await vm(container).openMenu(e03, _texts)).next,
        ManageEventNext.none,
      );
      feedback.nextSheetResult = EventMenuAction.duplicate;
      await vm(container).openMenu(e03, _texts);
      expect(events.callsTo('duplicate'), isEmpty);
      expect(feedback.toasts, [ToastId.tst26, ToastId.tst26]);
      expect(vm(container).ensureWritable(), isFalse);
    });
  });
}
