// FED-03 · ComposeViewModel: açılış (taslak, duyuru hakkı, kulüp), alan
// sınırları, doğrulama dalları, görsel ekleme (en çok 4 → TST-X5), yayın
// sırası (K-18: görseller → create), kısmi yükleme hatası ve yeniden deneme,
// günlük duyuru hakkı (2 / gün: 3. bildirimli duyuru → DLG-24; bildirimsiz
// sınırsız), taslak (TST-13) kaydet / yükle / yayında sil, düzenleme (W-71),
// danışman TST-26, çevrimdışı TST-24 — PLAN §12.8.
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/feed/provider/compose_state.dart';
import 'package:gu_kulupler/features/feed/provider/compose_view_model.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:gu_ui/gu_ui.dart' show GuIcons;

import '../../../fakes/fake_announcement_counter_repository.dart';
import '../../../fakes/fake_app_preferences_store.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_image_picker_service.dart';
import '../../../fakes/fake_post_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/test_container.dart';
import '../compose_test_support.dart';

void main() {
  late FakePostRepository posts;
  late FakeAnnouncementCounterRepository counters;
  late FakeAppPreferencesStore prefs;
  late FakeImagePickerService picker;
  late FakeFeedbackService feedback;
  late FakeConnectivityService connectivity;

  final provider = composeViewModelProvider(clubId: kComposeClubId);

  ComposeViewModelProvider editOf(PostModel post) =>
      composeViewModelProvider(clubId: kComposeClubId, editPostId: post.id);

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    posts = GetIt.I<PostRepository>() as FakePostRepository;
    counters =
        GetIt.I<AnnouncementCounterRepository>()
            as FakeAnnouncementCounterRepository;
    prefs = GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore;
    picker = GetIt.I<ImagePickerService>() as FakeImagePickerService;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    connectivity = GetIt.I<ConnectivityService>() as FakeConnectivityService;
    seedCompose();
  });

  /// İlk okuması bitmiş kapsayıcı ([of] ViewModel'i dinlenir).
  Future<ProviderContainer> loaded({
    SessionState? session,
    ComposeViewModelProvider? of,
  }) async {
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild(
          (ref, notifier) => session ?? composeSession(),
        ),
      ],
    );
    addTearDown(container.listen(of ?? provider, (_, _) {}).close);
    await pumpEventQueue();
    posts.calls.clear();
    return container;
  }

  /// Bildirimli duyuru formu doldurur.
  void fillAnnouncement(ComposeViewModel vm) => vm
    ..setType(PostType.announcement)
    ..setTitle('Zirve tırmanışı')
    ..setText('Cumartesi 07.00’de kampüs kapısında buluşuyoruz.');

  group('FED-03 · ComposeViewModel · açılış', () {
    test('boş form; kulüp ve günün duyuru sayısı arka planda gelir', () async {
      counters.counts[counters.keyOf(kComposeClubId)] = 1;
      final container = await loaded();
      final state = container.read(provider);
      expect(state.type, PostType.post);
      expect(state.text, isEmpty);
      expect(state.pollOptions, ['', '']);
      expect(state.pollDuration, PollDuration.d3);
      expect(state.pushEnabled, isTrue);
      expect(state.club, kComposeClub);
      expect(state.quotaUsed, 1);
      expect(state.quotaLimit, Limits.announcementDailyLimit);
      expect(state.limitReached, isFalse);
      expect(state.isDirty || state.hasDraft || state.isLoadingEdit, isFalse);
      expect(state.isValid, isFalse);
    });

    test('anket süreleri `Limits.pollDurationsDays` ile aynı', () {
      expect(
        [for (final duration in PollDuration.values) duration.days],
        Limits.pollDurationsDays,
      );
    });
  });

  group('FED-03 · ComposeViewModel · alanlar ve doğrulama', () {
    test(
      'başlık, metin ve seçenek sınırda kesilir; seçenek sayısı 2–4',
      () async {
        final container = await loaded();
        final vm = container.read(provider.notifier)
          ..setType(PostType.poll)
          ..setTitle('a' * (Limits.postTitleMax + 5))
          ..setText('b' * (Limits.postTextMax + 5))
          ..setPollOption(0, 'c' * (Limits.pollOptionTextMax + 5));
        var state = container.read(provider);
        expect(state.title, hasLength(Limits.postTitleMax));
        expect(state.text, hasLength(Limits.postTextMax));
        expect(state.pollOptions.first, hasLength(Limits.pollOptionTextMax));
        expect(state.isDirty, isTrue);

        vm.removePollOption(0);
        expect(container.read(provider).pollOptions, hasLength(2));
        vm
          ..addPollOption()
          ..addPollOption()
          ..addPollOption();
        state = container.read(provider);
        expect(state.pollOptions, hasLength(Limits.pollOptionsMax));
        expect(state.canAddPollOption, isFalse);
        vm.removePollOption(3);
        expect(container.read(provider).pollOptions, hasLength(3));
      },
    );

    test('doğrulama: metin zorunlu; duyuruda başlık; ankette en az iki dolu '
        've farklı seçenek', () async {
      final container = await loaded();
      final vm = container.read(provider.notifier);
      expect(vm.validate(), isFalse);
      expect(container.read(provider).errors, {
        ComposeField.text: FormFieldError.required,
      });

      vm
        ..setText('Merhaba')
        ..setType(PostType.announcement);
      expect(container.read(provider).isValid, isFalse);
      expect(vm.validate(), isFalse);
      expect(container.read(provider).errors, {
        ComposeField.title: FormFieldError.required,
      });
      vm.setTitle('Başlık');
      expect(container.read(provider).errors, isEmpty);
      expect(vm.validate(), isTrue);

      vm
        ..setType(PostType.poll)
        ..setPollOption(0, 'Cumartesi');
      expect(container.read(provider).isValid, isFalse);
      expect(vm.validate(), isFalse);
      expect(container.read(provider).errors, {
        ComposeField.options: FormFieldError.tooShort,
      });
      vm.setPollOption(1, ' Cumartesi ');
      expect(container.read(provider).isValid, isTrue);
      expect(vm.validate(), isFalse);
      expect(container.read(provider).errors, {
        ComposeField.options: FormFieldError.invalidFormat,
      });
      vm.setPollOption(1, 'Pazar');
      expect(vm.validate(), isTrue);
    });
  });

  group('FED-03 · ComposeViewModel · görseller', () {
    test('en çok 4 görsel: beşincide seçici açılmaz → TST-X5; kaldırınca '
        'yeniden eklenir', () async {
      final container = await loaded();
      final vm = container.read(provider.notifier);
      for (var index = 0; index < Limits.postImagesMax; index++) {
        await vm.addImage(MediaSource.gallery);
      }
      expect(container.read(provider).images, hasLength(4));
      expect(container.read(provider).canAddImage, isFalse);
      expect(feedback.toasts, isEmpty);

      await vm.addImage(MediaSource.gallery);
      expect(picker.picks, hasLength(4));
      expect(feedback.toasts, [ToastId.tstX5]);
      expect(vm.ensureCanAddImage(), isFalse);

      vm.removeImage(0);
      expect(container.read(provider).images, hasLength(3));
      expect(vm.ensureCanAddImage(), isTrue);
    });

    test(
      'vazgeçme durumu değiştirmez; büyük görsel alan hatası yazar',
      () async {
        final container = await loaded();
        final vm = container.read(provider.notifier);
        picker.nextPick = null;
        await vm.addImage(MediaSource.gallery);
        expect(container.read(provider).images, isEmpty);
        expect(container.read(provider).isDirty, isFalse);

        picker
          ..nextPick = kFakeJpeg
          ..nextError = ImagePickError.tooLarge;
        await vm.addImage(MediaSource.gallery);
        expect(container.read(provider).errors, {
          ComposeField.images: FormFieldError.limitExceeded,
        });
        await vm.addImage(MediaSource.gallery);
        expect(container.read(provider).errors, isEmpty);
        expect(container.read(provider).images, hasLength(1));
      },
    );

    test('piksel boyutu okunamayan görsel eklenmez (alan hatası)', () async {
      final container = await loaded();
      final vm = container.read(provider.notifier);
      picker.nextPick = PickedImage(
        bytes: kFakeJpeg.bytes,
        contentType: kFakeJpeg.contentType,
        width: 0,
        height: 0,
      );
      await vm.addImage(MediaSource.gallery);
      expect(container.read(provider).images, isEmpty);
      expect(container.read(provider).errors, {
        ComposeField.images: FormFieldError.invalidFormat,
      });
    });
  });

  group('FED-03 · ComposeViewModel · yayın', () {
    test('gönderi: önce görseller yüklenir, sonra create (K-18); sabitle → '
        'pin; TST-14 "Görüntüle" gönderi kimliğini verir', () async {
      posts.newPostIdQueue.add('p_new');
      final container = await loaded();
      final vm = container.read(provider.notifier)..setText('  Zirve!  ');
      await vm.addImage(MediaSource.gallery);
      await vm.addImage(MediaSource.gallery);
      vm.setPinAfterPublish(value: true);
      posts.calls.clear();

      String? viewed;
      final outcome = await vm.publish(onView: (postId) => viewed = postId);
      expect(outcome, ComposeOutcome.published);
      expect(
        [for (final call in posts.calls) call.method],
        ['newPostId', 'uploadImages', 'create', 'pin'],
      );
      expect(posts.imageUploads, hasLength(2));
      expect(
        posts.imageUploads.every(
          (upload) =>
              upload.postId == 'p_new' &&
              upload.clubId == kComposeClubId &&
              // Storage Rules: `metadata.uploaderId == request.auth.uid`.
              upload.uploaderId == kComposeUid,
        ),
        isTrue,
      );
      final post = posts.posts['p_new']!;
      expect(post.type, PostType.post);
      expect(post.text, 'Zirve!');
      expect(post.authorId, kComposeUid);
      expect(post.clubId, kComposeClubId);
      expect(post.images, [
        for (final upload in posts.imageUploads) upload.image,
      ]);
      expect(post.pinned, isTrue);
      expect(post.pushSent, isFalse);

      expect(feedback.toasts, [ToastId.tst14]);
      feedback.tapToastAction();
      expect(viewed, 'p_new');
      final state = container.read(provider);
      expect(state.isSubmitting || state.isDirty, isFalse);
    });

    test('yükleme yarıda kalır (TST-24): yüklenen işaretlenir; yeniden '
        'denemede aynı kimlikle yalnızca kalan gönderilir', () async {
      posts.newPostIdQueue.add('p_new');
      final container = await loaded();
      final vm = container.read(provider.notifier)..setText('Fotoğraflar');
      await vm.addImage(MediaSource.gallery);
      await vm.addImage(MediaSource.gallery);
      posts
        ..failUploadAt = 1
        ..failNext(StorageError.retryLimitExceeded);

      expect(await vm.publish(), ComposeOutcome.failed);
      expect(feedback.toasts, [ToastId.tst24]);
      expect(posts.posts.containsKey('p_new'), isFalse);
      var state = container.read(provider);
      expect(state.isSubmitting, isFalse);
      expect(
        [for (final image in state.images) image.isUploaded],
        [
          true,
          false,
        ],
      );

      posts.calls.clear();
      expect(await vm.publish(), ComposeOutcome.published);
      expect(posts.callsTo('newPostId'), isEmpty);
      final retry = posts.callsTo('uploadImages').single;
      expect(retry.args.first, 'p_new');
      expect(retry.args[1], hasLength(1));
      expect(posts.imageUploads, hasLength(2));
      expect(posts.posts['p_new']!.images, hasLength(2));
      state = container.read(provider);
      expect(state.images.every((image) => image.isUploaded), isTrue);
    });

    test(
      'Storage reddi → TST-X18; bilinmeyen yazım hatası → hata bandı',
      () async {
        final container = await loaded();
        final vm = container.read(provider.notifier)..setText('Merhaba');
        await vm.addImage(MediaSource.gallery);
        posts.failNext(StorageError.unauthorized);
        expect(await vm.publish(), ComposeOutcome.failed);
        expect(feedback.toasts, [ToastId.tstX18]);
        expect(container.read(provider).isSubmitError, isFalse);

        vm.removeImage(0);
        posts.failNext(FirestoreError.unknown);
        expect(await vm.publish(), ComposeOutcome.failed);
        expect(feedback.toasts, [ToastId.tstX18]);
        expect(container.read(provider).isSubmitError, isTrue);
        vm.setText('Merhaba!');
        expect(container.read(provider).isSubmitError, isFalse);
      },
    );

    test(
      'anket: boş satırlar atılır, süre ve sonuç ayarı taslağa geçer',
      () async {
        posts.newPostIdQueue.add('p_poll');
        final container = await loaded();
        final vm = container.read(provider.notifier)
          ..setType(PostType.poll)
          ..setText('Hangi gün?')
          ..setPollOption(0, 'Cumartesi')
          ..addPollOption()
          ..setPollOption(2, 'Pazar')
          ..setPollDuration(PollDuration.d7)
          ..setShowResults(value: false);
        expect(await vm.publish(), ComposeOutcome.published);
        final poll = posts.posts['p_poll']!.poll!;
        expect(
          [for (final option in poll.options) option.text],
          [
            'Cumartesi',
            'Pazar',
          ],
        );
        expect(poll.showResultsAfterVote, isFalse);
        expect(
          poll.endsAt,
          GetIt.I<AppClock>().nowUtc().add(const Duration(days: 7)),
        );
        expect(posts.callsTo('uploadImages'), isEmpty);
      },
    );

    test(
      'geçersiz form yazmaz; danışman → TST-26; çevrimdışı → TST-24',
      () async {
        var container = await loaded();
        expect(
          await container.read(provider.notifier).publish(),
          ComposeOutcome.invalid,
        );
        expect(posts.calls, isEmpty);

        container = await loaded(
          session: composeSession(role: ClubRole.advisor),
        );
        var vm = container.read(provider.notifier)..setText('Merhaba');
        expect(await vm.publish(), ComposeOutcome.blocked);
        expect(feedback.toasts, [ToastId.tst26]);

        container = await loaded();
        vm = container.read(provider.notifier)..setText('Merhaba');
        connectivity.isOffline = true;
        expect(await vm.publish(), ComposeOutcome.blocked);
        expect(feedback.toasts, [ToastId.tst26, ToastId.tst24]);
        expect(posts.calls, isEmpty);
      },
    );
  });

  group('FED-03 · ComposeViewModel · günlük duyuru hakkı (DLG-24)', () {
    /// Yeni bir ekranda bildirimli duyuru yayınlar.
    Future<ComposeOutcome> publishAnnouncement() async {
      final container = await loaded();
      final vm = container.read(provider.notifier);
      fillAnnouncement(vm);
      return vm.publish();
    }

    test('limit 2 / gün: üçüncü bildirimli duyuru DLG-24 sorar — "Vazgeç" '
        'yayınlamaz; "Bildirimsiz yayınla" bildirimsiz yayınlar', () async {
      expect(await publishAnnouncement(), ComposeOutcome.published);
      expect(await publishAnnouncement(), ComposeOutcome.published);
      expect(counters.counts[counters.keyOf(kComposeClubId)], 2);
      expect(feedback.dialogs, isEmpty);

      final container = await loaded();
      expect(container.read(provider).limitReached, isTrue);
      final vm = container.read(provider.notifier);
      fillAnnouncement(vm);
      expect(container.read(provider).pushActive, isFalse);

      expect(await vm.publish(), ComposeOutcome.cancelled);
      expect(feedback.dialogs, [DialogId.dlg24]);
      expect(posts.callsTo('create'), isEmpty);
      expect(container.read(provider).isSubmitting, isFalse);

      feedback.nextDialogResult = true;
      expect(await vm.publish(), ComposeOutcome.published);
      expect(feedback.dialogs, [DialogId.dlg24, DialogId.dlg24]);
      final draft = posts.callsTo('create').single.args.first! as PostDraft;
      expect(draft.type, PostType.announcement);
      expect(draft.pushSent, isFalse);
      expect(counters.counts[counters.keyOf(kComposeClubId)], 2);
    });

    test('bildirimsiz yayın sınırsız: hak doluyken anahtar kapalı duyuru '
        'sorusuz yayınlanır', () async {
      counters.counts[counters.keyOf(kComposeClubId)] =
          Limits.announcementDailyLimit;
      for (var index = 0; index < 3; index++) {
        final container = await loaded();
        final vm = container.read(provider.notifier);
        fillAnnouncement(vm);
        vm.setPushEnabled(value: false);
        expect(await vm.publish(), ComposeOutcome.published);
      }
      expect(feedback.dialogs, isEmpty);
      expect(
        posts.posts.values.where((post) => post.isAnnouncement),
        hasLength(4),
      );
    });

    test('hak yayın anında dolmuş (`announcementLimit`): sayaç güncellenir, '
        'DLG-24 → bildirimsiz yayın', () async {
      final container = await loaded();
      final vm = container.read(provider.notifier);
      fillAnnouncement(vm);
      // Başka yönetici bu arada iki duyuru gönderdi.
      counters.counts[counters.keyOf(kComposeClubId)] =
          Limits.announcementDailyLimit;
      feedback.nextDialogResult = true;
      expect(await vm.publish(), ComposeOutcome.published);
      expect(feedback.dialogs, [DialogId.dlg24]);
      expect(posts.callsTo('create'), hasLength(2));
      expect(posts.posts.values.last.pushSent, isFalse);
    });

    test('hakkı dolmuşken anahtara dokunuş DLG-24 açıklar; "Bildirimsiz '
        'yayınla" duyuruyu bildirimsiz işaretler', () async {
      final container = await loaded();
      feedback.nextDialogResult = true;
      await container.read(provider.notifier).explainLimit();
      expect(feedback.dialogs, [DialogId.dlg24]);
      expect(container.read(provider).pushEnabled, isFalse);
    });

    test('DLG-24 katalog kaydı: megafon, "Bildirimsiz yayınla" (`silent`) / '
        '"Vazgeç" (`cancel`)', () {
      final spec = DialogCatalog.of(DialogId.dlg24)!;
      final l10n = lookupAppLocalizations(const Locale('tr'));
      expect(spec.icon, GuIcons.megaphone);
      expect(spec.title(l10n, const {}), l10n.dlg24Title);
      expect(spec.body!(l10n, const {}), l10n.dlg24Body);
      expect(spec.primary(l10n), l10n.dlg24Silent);
      expect(spec.secondary!(l10n), l10n.commonGiveUp);
      expect(spec.primaryAction, 'silent');
      expect(spec.secondaryAction, 'cancel');
      expect(spec.destructive, isFalse);
    });
  });

  group('FED-03 · ComposeViewModel · taslak (TST-13)', () {
    test('taslak kaydet → TST-13; yeni ekran taslakla açılır (görseller '
        'hariç); yayın taslağı siler', () async {
      var container = await loaded();
      var vm = container.read(provider.notifier)
        ..setType(PostType.poll)
        ..setText('Hangi gün?')
        ..setPollOption(0, 'Cumartesi')
        ..setPollOption(1, 'Pazar')
        ..setPollDuration(PollDuration.d1)
        ..setShowResults(value: false)
        ..setPinAfterPublish(value: true);
      expect(await vm.saveDraft(), isTrue);
      expect(feedback.toasts, [ToastId.tst13]);
      expect(
        prefs.values[AppPreferenceKeys.composeDraft(kComposeClubId)],
        isA<String>(),
      );
      var state = container.read(provider);
      expect(state.hasDraft, isTrue);
      expect(state.isDirty || state.isSavingDraft, isFalse);

      container = await loaded();
      state = container.read(provider);
      expect(state.hasDraft, isTrue);
      expect(state.isDirty, isFalse);
      expect(state.type, PostType.poll);
      expect(state.text, 'Hangi gün?');
      expect(state.pollOptions, ['Cumartesi', 'Pazar']);
      expect(state.pollDuration, PollDuration.d1);
      expect(state.showResultsAfterVote, isFalse);
      expect(state.pinAfterPublish, isTrue);
      expect(state.images, isEmpty);

      vm = container.read(provider.notifier);
      expect(await vm.publish(), ComposeOutcome.published);
      expect(prefs.composeDraft(kComposeClubId), isNull);
      expect(container.read(provider).hasDraft, isFalse);
      expect((await loaded()).read(provider).hasDraft, isFalse);
    });

    test('taslak kulübe özeldir; bozuk taslak boş form açar; düzenlemede '
        'taslak yüklenmez ve kaydedilmez', () async {
      prefs.values[AppPreferenceKeys.composeDraft('c01')] = ComposeDraft.encode(
        const ComposeState(text: 'başka kulüp'),
      );
      expect((await loaded()).read(provider).text, isEmpty);

      prefs.values[AppPreferenceKeys.composeDraft(kComposeClubId)] = '{bozuk';
      expect((await loaded()).read(provider), isA<ComposeState>());
      expect((await loaded()).read(provider).hasDraft, isFalse);

      prefs.values[AppPreferenceKeys.composeDraft(kComposeClubId)] =
          ComposeDraft.encode(const ComposeState(text: 'taslak'));
      final container = await loaded(of: editOf(kEditPost));
      final state = container.read(editOf(kEditPost));
      expect(state.text, kEditPost.text);
      expect(state.hasDraft, isFalse);
      expect(
        await container.read(editOf(kEditPost).notifier).saveDraft(),
        isFalse,
      );
      expect(feedback.toasts, isEmpty);
    });

    test('T-36 (W-97) · `initialType` başlangıç türüdür: boş formda ve '
        'taslakta (metin korunur); düzenlemede yok sayılır', () async {
      ComposeViewModelProvider typed(PostType type, {String? edit}) =>
          composeViewModelProvider(
            clubId: kComposeClubId,
            editPostId: edit,
            initialType: type,
          );
      final announcement = typed(PostType.announcement);
      var state = (await loaded(of: announcement)).read(announcement);
      expect(state.type, PostType.announcement);
      expect(state.isDirty || state.hasDraft, isFalse);

      prefs.values[AppPreferenceKeys.composeDraft(kComposeClubId)] =
          ComposeDraft.encode(const ComposeState(text: 'taslak'));
      final poll = typed(PostType.poll);
      state = (await loaded(of: poll)).read(poll);
      expect(state.type, PostType.poll);
      expect(state.text, 'taslak');
      expect(state.hasDraft, isTrue);

      final edit = typed(PostType.poll, edit: kEditPost.id);
      state = (await loaded(of: edit)).read(edit);
      expect(state.type, kEditPost.type);
      expect(state.text, kEditPost.text);
    });
  });

  group('FED-03 · ComposeViewModel · düzenleme', () {
    test('gönderi yüklenir (ilk kare iskelet); tür değişmez; değişen metin '
        've görseller yazılır (yalnızca yeni görsel yüklenir)', () async {
      final edit = editOf(kEditPost);
      final container = createContainer(
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (ref, notifier) => composeSession(),
          ),
        ],
      );
      addTearDown(container.listen(edit, (_, _) {}).close);
      expect(container.read(edit).isLoadingEdit, isTrue);
      await pumpEventQueue();
      var state = container.read(edit);
      expect(state.isLoadingEdit || state.isError || state.isDirty, isFalse);
      expect(state.editPost, kEditPost);
      expect(state.text, kEditPost.text);
      expect([
        for (final image in state.images) image.uploaded,
      ], kEditPost.images);

      final vm = container.read(edit.notifier)..setType(PostType.poll);
      expect(container.read(edit).type, PostType.post);
      vm
        ..setText('Güncel metin')
        ..removeImage(0);
      await vm.addImage(MediaSource.gallery);
      posts.calls.clear();

      expect(await vm.publish(), ComposeOutcome.published);
      expect(
        [for (final call in posts.calls) call.method],
        ['uploadImages', 'update'],
      );
      final upload = posts.callsTo('uploadImages').single;
      expect(upload.args.first, kEditPost.id);
      expect(upload.args[1], hasLength(1));
      expect(posts.imageUploads.single.uploaderId, kComposeUid);
      final saved = posts.posts[kEditPost.id]!;
      expect(saved.text, 'Güncel metin');
      expect(saved.images, [
        ...kEditPost.images.skip(1),
        posts.imageUploads.single.image,
      ]);
      expect(feedback.toasts, [ToastId.tst14]);
      state = container.read(edit);
      expect(state.isSubmitting || state.isDirty, isFalse);
    });

    test(
      'duyuru: yalnızca değişen başlık yazılır; değişiklik yoksa TST-X9',
      () async {
        final edit = editOf(kEditAnnouncement);
        final container = await loaded(of: edit);
        final vm = container.read(edit.notifier);
        expect(container.read(edit).pinAfterPublish, isTrue);
        expect(await vm.publish(), ComposeOutcome.nothingToSave);
        expect(feedback.toasts, [ToastId.tstX9]);
        expect(posts.calls, isEmpty);

        vm.setTitle('Yeni başlık');
        expect(await vm.publish(), ComposeOutcome.published);
        final call = posts.callsTo('update').single;
        expect(call.args[1], const PostEditPatch(title: 'Yeni başlık'));
        expect(call.args[2], kComposeUid);
        expect(feedback.dialogs, isEmpty);
      },
    );

    test('anket (W-71): soru ve seçenekler salt okunur, `text` gönderilmez; '
        'yalnızca sabitleme yazılır', () async {
      final edit = editOf(kEditPoll);
      final container = await loaded(of: edit);
      final vm = container.read(edit.notifier)
        ..setText('Başka soru')
        ..setPollOption(0, 'Başka seçenek')
        ..addPollOption()
        ..clear();
      final state = container.read(edit);
      expect(state.isPollLocked, isTrue);
      expect(state.text, kEditPoll.text);
      expect(state.pollOptions, [
        for (final option in kEditPoll.poll!.options) option.text,
      ]);
      expect(state.isDirty, isFalse);

      vm.setPinAfterPublish(value: true);
      expect(await vm.publish(), ComposeOutcome.published);
      expect([for (final call in posts.calls) call.method], ['pin']);
      expect(posts.posts[kEditPoll.id]!.pinned, isTrue);
    });

    test('askıdaki kulüp / yetkisiz düzenleme (`permissionDenied`) → '
        'TST-X18; form açık kalır', () async {
      final edit = editOf(kEditPost);
      final container = await loaded(of: edit);
      final vm = container.read(edit.notifier)..setText('Güncel metin');
      posts.failNext(FirestoreError.permissionDenied);
      expect(await vm.publish(), ComposeOutcome.failed);
      expect(feedback.toasts, [ToastId.tstX18]);
      final state = container.read(edit);
      expect(state.isSubmitting, isFalse);
      expect(state.isDirty, isTrue);
      expect(posts.posts[kEditPost.id]!.text, kEditPost.text);
    });

    test('gönderi okunamaz → hata; "Yeniden dene" yükler; başka kulübün '
        'gönderisi okunamadı sayılır', () async {
      final edit = editOf(kEditPost);
      posts.failNext(FirestoreError.unavailable);
      final container = await loaded(of: edit);
      expect(container.read(edit).isError, isTrue);
      expect(
        await container.read(edit.notifier).publish(),
        ComposeOutcome.ignored,
      );
      await container.read(edit.notifier).loadForEdit();
      expect(container.read(edit).isError, isFalse);
      expect(container.read(edit).editPost, kEditPost);

      final foreign = composeViewModelProvider(
        clubId: 'c01',
        editPostId: kEditPost.id,
      );
      final other = await loaded(of: foreign);
      expect(other.read(foreign).isError, isTrue);
    });
  });

  group('FED-03 · ComposeViewModel · önizleme ve temizle', () {
    test('önizleme gönderiyi kurar (boş metin "…"); temizle alanları '
        'boşaltır', () async {
      final container = await loaded();
      final vm = container.read(provider.notifier)..togglePreview();
      var state = container.read(provider);
      expect(state.isPreview, isTrue);
      expect(state.preview!.text, '…');
      expect(state.preview!.authorId, kComposeUid);
      expect(state.preview!.clubId, kComposeClubId);
      vm.togglePreview();
      expect(container.read(provider).isPreview, isFalse);

      vm.setText('Metin');
      await vm.addImage(MediaSource.gallery);
      vm.clear();
      state = container.read(provider);
      expect(state.text, isEmpty);
      expect(state.images, isEmpty);
      expect(state.isDirty, isTrue);
    });
  });
}
