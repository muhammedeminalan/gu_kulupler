// MGT-05 · EventFormViewModel: açılış (prototip varsayılanları, kulüp
// paleti), adım doğrulaması (başlık zorunlu, bitiş > başlangıç, geçmiş
// başlangıç, mekân, kontenjan ≥ goingCount), taslak (createDraft → TST-13),
// yayın + bildirim sayısı (publishEvent → event_new fan-out), kapak yükleme
// sırası (K-18: createDraft → uploadCover → publish) ve yarıda kalan yazımın
// yeniden denenmesi, düzenleme (yalnızca değişen alanlar), zaman kilidi
// (W-82), K-F, danışman TST-26, çevrimdışı TST-24 — PLAN §12.6.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/event_form_state.dart';
import 'package:gu_kulupler/features/management/provider/event_form_view_model.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/format/time_of_day_value.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';

import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_event_repository.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_management_repository.dart';
import '../../../fakes/fake_recipient_resolver.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/test_container.dart';
import '../event_form_test_support.dart';
import '../manage_test_support.dart';

void main() {
  late FakeEventRepository events;
  late FakeManagementRepository management;
  late FakeFeedbackService feedback;

  final provider = eventFormViewModelProvider(clubId: kManageClubId);

  EventFormViewModelProvider editOf(EventModel event) =>
      eventFormViewModelProvider(
        clubId: kManageClubId,
        editEventId: event.id,
      );

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    events = GetIt.I<EventRepository>() as FakeEventRepository;
    management = GetIt.I<ManagementRepository>() as FakeManagementRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    seedEventForm();
  });

  /// İlk okuması bitmiş kapsayıcı ([of] ViewModel'i dinlenir).
  Future<ProviderContainer> loaded({
    SessionState? session,
    EventFormViewModelProvider? of,
  }) async {
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild(
          (ref, notifier) => session ?? manageSession(),
        ),
      ],
    );
    addTearDown(container.listen(of ?? provider, (_, _) {}).close);
    await pumpEventQueue();
    events.calls.clear();
    return container;
  }

  /// Yeni etkinliğin zorunlu alanlarını doldurur.
  void fill(EventFormViewModel vm) => vm
    ..setTitle('  Ilgaz Kayak Günü  ')
    ..setPlace(placeId: 'pl09');

  List<String> eventCalls() => [for (final c in events.calls) c.method];

  group('MGT-05 · EventFormViewModel · açılış', () {
    test('yeni etkinlik: prototip varsayılanları + kulübün paleti; kulüp ve '
        'kulüp etkinlikleri okunur', () async {
      final container = await loaded();
      final state = container.read(provider);
      expect(state.step, EventFormStep.basics);
      expect(state.type, EventType.social);
      expect(state.startsAt, kDefaultStart);
      expect(state.endsAt, kDefaultStart.add(const Duration(hours: 2)));
      expect(state.capacityValue, EventFormState.defaultCapacity);
      expect(state.visibility, EventVisibility.public);
      expect(state.autoReminder, isTrue);
      expect(state.coverPalette, kManageClub.palette);
      expect(state.coverPattern, ClubPattern.mountain);
      expect(state.club, kManageClub);
      expect(state.clubEvents, isNotEmpty);
      expect(state.isDirty, isFalse);
    });

    test('düzenleme: etkinlik okunur, form dolar (taslak)', () async {
      final container = await loaded(of: editOf(kDraftEvent));
      final state = container.read(editOf(kDraftEvent));
      expect(state.isLoading, isFalse);
      expect(state.original, kDraftEvent);
      expect(state.title, kDraftEvent.title);
      expect(state.capacityValue, kDraftEvent.capacity);
      expect(state.isUnlimited, kDraftEvent.capacity == null);
      expect(state.visibility, kDraftEvent.visibility);
      expect(state.timeLocked, isFalse);
      expect(state.isDirty, isFalse);
    });

    test(
      'düzenleme: okunamayan etkinlik → hata; "Yeniden dene" okur',
      () async {
        events.failNext(FirestoreError.unavailable);
        final container = await loaded(of: editOf(kDraftEvent));
        expect(container.read(editOf(kDraftEvent)).isError, isTrue);
        await container.read(editOf(kDraftEvent).notifier).loadForEdit();
        expect(container.read(editOf(kDraftEvent)).isError, isFalse);
        expect(container.read(editOf(kDraftEvent)).original, kDraftEvent);
      },
    );

    test('yayındaki etkinlik başladıysa zaman kilitli (W-82): tarih / saat '
        'değişmez', () async {
      final container = await loaded(of: editOf(kStartedEvent));
      final vm = container.read(editOf(kStartedEvent).notifier);
      expect(container.read(editOf(kStartedEvent)).timeLocked, isTrue);
      vm
        ..setStartDate(DateTime(2026, 12))
        ..setEndTime(const TimeOfDayValue(23, 0));
      final state = container.read(editOf(kStartedEvent));
      expect(state.startsAt, kStartedEvent.startsAt);
      expect(state.endsAt, kStartedEvent.endsAt);
    });
  });

  group('MGT-05 · EventFormViewModel · doğrulama', () {
    test('1. adım: başlık zorunlu — "Devam" ilerlemez', () async {
      final container = await loaded();
      container.read(provider.notifier).next();
      final state = container.read(provider);
      expect(state.step, EventFormStep.basics);
      expect(state.errors, {EventField.title: FormFieldError.required});
    });

    test('2. adım: mekân zorunlu; bitiş > başlangıç; geçmiş başlangıç '
        'reddedilir', () async {
      final container = await loaded();
      final vm = container.read(provider.notifier)
        ..setTitle('Ilgaz')
        ..next();
      expect(container.read(provider).step, EventFormStep.schedule);
      // Bitiş başlangıçtan önce; başlangıç dün.
      vm
        ..setEndTime(const TimeOfDayValue(10, 0))
        ..next();
      expect(container.read(provider).errors, {
        EventField.endsAt: FormFieldError.endBeforeStart,
        EventField.place: FormFieldError.required,
      });
      vm
        ..setStartDate(DateTime(2026, 10, 11))
        ..setPlace(placeText: '  Kampüs önü  ')
        ..next();
      final state = container.read(provider);
      expect(state.errors, {EventField.startsAt: FormFieldError.limitExceeded});
      expect(state.placeText, 'Kampüs önü');
      expect(state.step, EventFormStep.schedule);
    });

    test('başlangıç bitişi geçince bitiş başlangıç + 2 sa olur', () async {
      final container = await loaded();
      container
          .read(provider.notifier)
          .setStartTime(
            const TimeOfDayValue(21, 30),
          );
      final state = container.read(provider);
      // 19 Ekim 21:30 Istanbul = 18:30Z.
      expect(state.startsAt, DateTime.utc(2026, 10, 19, 18, 30));
      expect(state.endsAt, DateTime.utc(2026, 10, 19, 20, 30));
    });

    test('düzenleme: kontenjan kayıtlı sayısının altına inemez '
        '(capacityBelowGoing)', () async {
      final container = await loaded(of: editOf(kPublishedEvent));
      final vm = container.read(editOf(kPublishedEvent).notifier)
        ..setCapacity(kPublishedEvent.goingCount - 5);
      expect(vm.validate(), isFalse);
      final state = container.read(editOf(kPublishedEvent));
      expect(state.errors, {
        EventField.capacity: FormFieldError.capacityBelowGoing,
      });
      expect(state.step, EventFormStep.schedule);
      expect(state.minCapacity, kPublishedEvent.goingCount);
    });
  });

  group('MGT-05 · EventFormViewModel · taslak', () {
    test(
      "yeni: createDraft (kırpılmış alanlar) → TST-13; kimlik state'te",
      () async {
        final container = await loaded();
        final vm = container.read(provider.notifier);
        fill(vm);
        expect(await vm.saveDraft(), EventFormOutcome.saved);
        expect(eventCalls(), ['createDraft']);
        final draft =
            events.callsTo('createDraft').single.args.first! as EventDraft;
        expect(draft.title, 'Ilgaz Kayak Günü');
        expect(draft.placeId, 'pl09');
        expect(draft.placeText, isNull);
        expect(draft.capacity, EventFormState.defaultCapacity);
        expect(draft.coverPalette, kManageClub.palette);
        final state = container.read(provider);
        expect(state.eventId, events.created.single.id);
        expect(state.isDirty, isFalse);
        expect(feedback.toasts, [ToastId.tst13]);
        expect(management.fanOuts, isEmpty);
      },
    );

    test('düzenleme: yalnızca değişen alanlar yazılır (update)', () async {
      final container = await loaded(of: editOf(kDraftEvent));
      final vm = container.read(editOf(kDraftEvent).notifier)
        ..setTitle('Kış Kampı')
        ..setCapacity(12);
      expect(await vm.saveChanges(), EventFormOutcome.saved);
      expect(eventCalls(), ['update']);
      expect(
        events.patches.single.patch,
        const EventEditPatch(title: 'Kış Kampı', capacity: 12),
      );
      expect(feedback.toasts, [ToastId.tst13]);
    });

    test('düzenleme: değişiklik yoksa yazım yok → TST-X9', () async {
      final container = await loaded(of: editOf(kDraftEvent));
      final vm = container.read(editOf(kDraftEvent).notifier);
      expect(await vm.saveChanges(), EventFormOutcome.ignored);
      expect(eventCalls(), isEmpty);
      expect(feedback.toasts, [ToastId.tstX9]);
    });

    test('yayındaki etkinlik: "Taslak olarak kaydet" kayıtlı yokken taslağa '
        'alır (TST-X19); kayıtlı varken reddedilir (K-F)', () async {
      final empty = await loaded(of: editOf(kEmptyPublishedEvent));
      expect(
        await empty.read(editOf(kEmptyPublishedEvent).notifier).saveDraft(),
        EventFormOutcome.unpublished,
      );
      expect(management.callsTo('unpublishEvent'), hasLength(1));
      expect(events.events[kEmptyPublishedEvent.id]!.status, EventStatus.draft);
      expect(feedback.toasts, [ToastId.tstX19]);

      final full = await loaded(of: editOf(kPublishedEvent));
      expect(full.read(editOf(kPublishedEvent)).canUnpublish, isFalse);
      expect(
        await full.read(editOf(kPublishedEvent).notifier).saveDraft(),
        EventFormOutcome.blocked,
      );
      expect(management.callsTo('unpublishEvent'), hasLength(1));
    });
  });

  group('MGT-05 · EventFormViewModel · yayın', () {
    test('yeni + bildirim: createDraft → publishEvent; üyelere event_new '
        '(1 fan-out) → TST-30 "Görüntüle"', () async {
      final container = await loaded();
      final vm = container.read(provider.notifier);
      fill(vm);
      String? viewed;
      final outcome = await vm.publish(
        notify: true,
        onView: (id) => viewed = id,
      );
      expect(outcome, EventFormOutcome.published);
      expect(eventCalls(), ['createDraft', 'publish']);
      final id = events.created.single.id;
      expect(events.events[id]!.status, EventStatus.published);
      expect(management.fanOuts, [
        (kind: NotificationType.eventNew, clubId: kManageClubId, id: id),
      ]);
      expect(feedback.toasts, [ToastId.tst30]);
      feedback.tapToastAction();
      expect(viewed, id);
    });

    test(
      'bildirimsiz yayın: fan-out yok; DLG-22 sayısı estimateEventNew '
      '(yayıncı hariç, CD-38), okunamazsa kulübün üye sayısı',
      () async {
        final recipients = GetIt.I<RecipientResolver>() as FakeRecipientResolver
          ..eventNewIds = ['u90', 'u91', 'u92', kManageUid];
        final container = await loaded();
        final vm = container.read(provider.notifier)
          ..setVisibility(EventVisibility.membersOnly);
        fill(vm);
        expect(await vm.estimateRecipients(), 3);
        expect(
          recipients.callsTo('estimateEventNew').single.args,
          [kManageClubId, EventVisibility.membersOnly, kManageClubId],
        );
        recipients.failNext(FirestoreError.unavailable);
        expect(await vm.estimateRecipients(), kManageClub.memberCount);
        expect(await vm.publish(notify: false), EventFormOutcome.published);
        expect(management.fanOuts, isEmpty);
      },
    );

    test(
      'özel kapak sırası (K-18): createDraft → uploadCover → publish',
      () async {
        final container = await loaded();
        final vm = container.read(provider.notifier);
        fill(vm);
        await vm.pickCover(MediaSource.gallery);
        expect(container.read(provider).pendingCover, isNotNull);
        expect(await vm.publish(notify: true), EventFormOutcome.published);
        expect(eventCalls(), ['createDraft', 'uploadCover', 'publish']);
        final upload = events.coverUploads.single;
        expect(upload.eventId, events.created.single.id);
        expect(upload.uploaderId, kManageUid);
        final state = container.read(provider);
        expect(state.pendingCover, isNull);
        expect(state.coverPath, upload.path);
      },
    );

    test('kapak yüklenemezse hata bandı; yeniden denemede taslak yeniden '
        'oluşturulmaz', () async {
      final container = await loaded();
      final vm = container.read(provider.notifier);
      fill(vm);
      expect(await vm.saveDraft(), EventFormOutcome.saved);
      await vm.pickCover(MediaSource.gallery);
      events
        ..calls.clear()
        ..failNext(StorageError.unknown);
      expect(await vm.publish(notify: false), EventFormOutcome.failed);
      expect(container.read(provider).isSubmitError, isTrue);
      expect(container.read(provider).pendingCover, isNotNull);
      expect(await vm.publish(notify: false), EventFormOutcome.published);
      expect(eventCalls(), ['uploadCover', 'uploadCover', 'publish']);
      expect(events.created, hasLength(1));
    });

    test('yayında başlangıç gelecekte olmalı: düzenlenen taslak geçmişteyse '
        'yayın reddedilir', () async {
      final past = kDraftEvent.copyWith(
        placeId: 'pl01',
        startsAt: kDefaultFakeNowUtc.subtract(const Duration(days: 1)),
        endsAt: kDefaultFakeNowUtc.subtract(const Duration(hours: 20)),
      );
      events.put(past);
      final container = await loaded(of: editOf(past));
      final vm = container.read(editOf(past).notifier);
      expect(vm.validate(), isTrue);
      expect(await vm.publish(notify: true), EventFormOutcome.invalid);
      expect(container.read(editOf(past)).errors, {
        EventField.startsAt: FormFieldError.limitExceeded,
      });
      expect(management.callsTo('publishEvent'), isEmpty);
    });

    test(
      'yayındaki etkinlikte "Kaydet": update → TST-21, yeniden yayın yok',
      () async {
        final container = await loaded(of: editOf(kStartedEvent));
        final vm = container.read(editOf(kStartedEvent).notifier)
          ..setDesc('Yeni açıklama');
        expect(
          await vm.publish(notify: true),
          EventFormOutcome.saved,
        );
        // Kilitli zaman yazılmaz.
        expect(
          events.patches.single.patch,
          const EventEditPatch(desc: 'Yeni açıklama'),
        );
        expect(management.callsTo('publishEvent'), isEmpty);
        expect(feedback.toasts, [ToastId.tst21]);
      },
    );

    test('kontenjan kuralı reddi (capacityFull) alana yazılır', () async {
      final container = await loaded(of: editOf(kEmptyPublishedEvent));
      final vm = container.read(editOf(kEmptyPublishedEvent).notifier)
        ..setCapacity(10);
      events.bumpCounters(kEmptyPublishedEvent.id, going: 20);
      expect(await vm.saveChanges(), EventFormOutcome.failed);
      final state = container.read(editOf(kEmptyPublishedEvent));
      expect(state.errors, {
        EventField.capacity: FormFieldError.capacityBelowGoing,
      });
      expect(state.isSubmitting, isFalse);
    });

    test(
      'danışman → TST-26; çevrimdışı → TST-24; hiçbir şey yazılmaz',
      () async {
        final advisor = await loaded(
          session: manageSession(role: ClubRole.advisor),
        );
        fill(advisor.read(provider.notifier));
        expect(
          await advisor.read(provider.notifier).publish(notify: true),
          EventFormOutcome.blocked,
        );
        expect(feedback.toasts, [ToastId.tst26]);

        (GetIt.I<ConnectivityService>() as FakeConnectivityService).isOffline =
            true;
        final offline = await loaded();
        fill(offline.read(provider.notifier));
        expect(
          await offline.read(provider.notifier).saveDraft(),
          EventFormOutcome.blocked,
        );
        expect(feedback.toasts, [ToastId.tst26, ToastId.tst24]);
        expect(events.created, isEmpty);
      },
    );
  });
}
