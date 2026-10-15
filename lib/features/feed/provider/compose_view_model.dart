import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/feed/provider/compose_state.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/mixin/form_validation_mixin.dart';
import 'package:gu_kulupler/product/mixin/permission_prompt_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'compose_view_model.g.dart';

/// FED-03 "Yeni gönderi" / "Gönderiyi düzenle" ekranının ViewModel'i (PLAN
/// §12.8; prototip `Compose`, `screens-clubs.js:181–215`).
///
/// * **Açılış:** yeni gönderide form cihazdaki taslaktan kurulur
///   (`compose_draft_<clubId>` — CD-45); `initialType` verilmişse
///   (`?type=`, MGT-01 "Duyuru yap" — W-97) tür onunla başlar, taslağın
///   metni korunur. Düzenlemede gönderi okunur ([loadForEdit]; tür
///   gönderininkidir). Kulüp ve günün duyuru hakkı ([loadQuota]) arka planda
///   gelir.
/// * **Yayın sırası (K-18, CD-39):** gönderi kimliği önceden üretilir →
///   görseller `postRepository.uploadImages` ile yüklenir → `create`. Yükleme
///   yarıda kalırsa yüklenenler işaretlenir; yeniden denemede aynı kimlikle
///   yalnızca kalanlar gönderilir.
/// * **Duyuru hakkı (Q-10):** bildirimli duyuruda günün hakkı dolmuşsa
///   DLG-24 sorar → "Bildirimsiz yayınla" bildirimsiz yayınlar. Bildirimsiz
///   yayın sınırsızdır. Hak yayın anında dolmuşsa (`announcementLimit`) aynı
///   soru sorulur.
/// * **Düzenleme (W-71):** tür değişmez; ankette soru ve seçenekler salt
///   okunurdur ve `text` gönderilmez. Yalnızca değişen alanlar yazılır
///   (`PostEditPatch`); sabitleme değiştiyse `pin` / `unpin`.
///
/// | İşlem | Koruma | Yazım | Geri bildirim |
/// |---|---|---|---|
/// | [publish] | doğrulama · danışman TST-26 · çevrimdışı TST-24 · hak DLG-24 | `uploadImages` → `create` (→ `pin`) / `update` (→ `pin` / `unpin`) | TST-14 "Görüntüle"; hata → TST-24 / TST-X18 / hata bandı |
/// | [saveDraft] | yalnızca yeni gönderi | `appPreferencesStore.setComposeDraft` | TST-13 |
/// | [addImage] | en çok 4 → TST-X5 · DLG-04 / DLG-05 | — | görsel hatası alan altında |
///
/// Design: FED-03, DLG-24
@riverpod
final class ComposeViewModel extends _$ComposeViewModel
    with
        ProjectDependencyMixin,
        WriteGuardMixin,
        FormValidationMixin<ComposeField>,
        PermissionPromptMixin {
  static const Set<StorageError> _networkUploadErrors = {
    StorageError.retryLimitExceeded,
    StorageError.timeout,
  };

  /// Yeni gönderinin önceden üretilmiş kimliği: görseller bu kimliğin
  /// klasörüne yüklenir, yeniden denemede aynı kalır (CD-39).
  String? _postId;

  bool _isPicking = false;

  /// Önizleme kartındaki gönderinin kimliği (hiçbir yere yazılmaz).
  static const String _previewId = 'preview';

  /// Metin boşken önizlemede çizilen yer tutucu (prototip `f.text || '…'`).
  static const String _previewEmptyText = '…';

  @override
  ComposeState build({
    required String clubId,
    String? editPostId,
    PostType? initialType,
  }) {
    // Okumalar ilk karede başlar; view ayrıca çağırmaz.
    unawaited(Future<void>.microtask(_start));
    if (editPostId != null) return const ComposeState(isLoadingEdit: true);
    final draft =
        ComposeDraft.decode(appPreferencesStore.composeDraft(clubId)) ??
        const ComposeState();
    return initialType == null ? draft : draft.copyWith(type: initialType);
  }

  // ───────────────────────────────── alanlar ────────────────────────────────

  /// Tür dilimi (`FED-03.type.*`): alan hataları silinir. Düzenlemede tür
  /// değişmez.
  void setType(PostType type) {
    if (_isLocked || state.isEditing || type == state.type) return;
    state = state.copyWith(
      type: type,
      errors: const {},
      isDirty: true,
      isSubmitError: false,
    );
  }

  /// Duyuru başlığı (`FED-03.title`); `Limits.postTitleMax`'te kesilir.
  void setTitle(String title) {
    final value = _clamped(title, Limits.postTitleMax);
    if (_isLocked || value == state.title) return;
    state = _edited(state.copyWith(title: value), const [ComposeField.title]);
  }

  /// Metin / soru (`FED-03.text`); `Limits.postTextMax`'te kesilir.
  /// Düzenlenen ankette soru değişmez.
  void setText(String text) {
    final value = _clamped(text, Limits.postTextMax);
    if (_isLocked || state.isPollLocked || value == state.text) return;
    state = _edited(state.copyWith(text: value), const [ComposeField.text]);
  }

  /// Bir görsel daha eklenebilir mi? Dolmuşsa TST-X5 gösterir ve `false`
  /// döner (`FED-03.addImage`, SHT-16 açılmadan önce).
  bool ensureCanAddImage() {
    if (state.canAddImage) return true;
    feedback.showToast(ToastId.tstX5);
    return false;
  }

  /// [source] kaynağından bir görsel seçtirir ve listeye ekler (SHT-16
  /// sonrası). İzin ön açıklamaları `PermissionPromptMixin.pickImage`
  /// içindedir. Vazgeçme durumu değiştirmez; görsel işlenemezse görseller
  /// alanına hata yazılır.
  Future<void> addImage(MediaSource source) async {
    if (_isPicking || _isLocked || state.type != PostType.post) return;
    if (!ensureCanAddImage()) return;
    _isPicking = true;
    try {
      final result = await pickImage(source);
      if (!ref.mounted) return;
      switch (result) {
        // Piksel boyutu okunamayan görsel yüklenemez (`uploadImages` ön
        // denetimi `invalidArgument` verir): seçim anında reddedilir.
        case ImagePickSuccess(:final image)
            when image.width < 1 || image.height < 1:
          AppLogger.warn('Gönderi görseli: piksel boyutu okunamadı');
          state = state.copyWith(
            errors: {
              ...state.errors,
              ComposeField.images: FormFieldError.invalidFormat,
            },
          );
        case ImagePickSuccess(:final image):
          if (!ensureCanAddImage()) return;
          state = _edited(
            state.copyWith(
              images: [...state.images, ComposeImage.local(image)],
            ),
            const [ComposeField.images],
          );
        case ImagePickCancelled() ||
            ImagePickFailure(error: ImagePickError.permissionDenied):
          break;
        case ImagePickFailure(:final error):
          AppLogger.warn('Gönderi görseli seçilemedi: ${error.name}');
          state = state.copyWith(
            errors: {
              ...state.errors,
              ComposeField.images: error == ImagePickError.tooLarge
                  ? FormFieldError.limitExceeded
                  : FormFieldError.invalidFormat,
            },
          );
      }
    } finally {
      _isPicking = false;
    }
  }

  /// [index] sırasındaki görseli listeden çıkarır (`FED-03.removeImage.<i>`).
  /// Yüklenmiş dosya Storage'da kalır (D-10); gönderiye yazılmaz.
  void removeImage(int index) {
    if (_isLocked || index < 0 || index >= state.images.length) return;
    state = _edited(
      state.copyWith(
        images: [
          for (final (i, image) in state.images.indexed)
            if (i != index) image,
        ],
      ),
      const [ComposeField.images],
    );
  }

  /// [index] sırasındaki anket seçeneği (`FED-03.option.<i>`);
  /// `Limits.pollOptionTextMax`'te kesilir.
  void setPollOption(int index, String value) {
    if (_isLocked || state.isPollLocked) return;
    if (index < 0 || index >= state.pollOptions.length) return;
    final option = _clamped(value, Limits.pollOptionTextMax);
    if (option == state.pollOptions[index]) return;
    state = _edited(
      state.copyWith(
        pollOptions: [
          for (final (i, current) in state.pollOptions.indexed)
            i == index ? option : current,
        ],
      ),
      const [ComposeField.options],
    );
  }

  /// "Seçenek ekle" (`FED-03.addOption`): en çok `Limits.pollOptionsMax`.
  void addPollOption() {
    if (_isLocked || !state.canAddPollOption) return;
    state = _edited(
      state.copyWith(pollOptions: [...state.pollOptions, '']),
      const [ComposeField.options],
    );
  }

  /// [index] sırasındaki seçeneği kaldırır (`FED-03.removeOption.<i>`): en az
  /// `Limits.pollOptionsMin` satır kalır.
  void removePollOption(int index) {
    if (_isLocked || !state.canRemovePollOption) return;
    if (index < 0 || index >= state.pollOptions.length) return;
    state = _edited(
      state.copyWith(
        pollOptions: [
          for (final (i, option) in state.pollOptions.indexed)
            if (i != index) option,
        ],
      ),
      const [ComposeField.options],
    );
  }

  /// Anket süresi (`FED-03.duration.<gün>`).
  void setPollDuration(PollDuration duration) {
    if (_isLocked || state.isPollLocked || duration == state.pollDuration) {
      return;
    }
    state = state.copyWith(pollDuration: duration, isDirty: true);
  }

  /// "Sonuçlar oy verince görünsün" (`FED-03.showAfterVote`).
  void setShowResults({required bool value}) {
    if (_isLocked || state.isPollLocked) return;
    state = state.copyWith(showResultsAfterVote: value, isDirty: true);
  }

  /// "Üyelere bildirim gönder" (`FED-03.pushToggle`).
  void setPushEnabled({required bool value}) {
    if (_isLocked || state.isEditing) return;
    state = state.copyWith(pushEnabled: value, isDirty: true);
  }

  /// "Sabitle" (`FED-03.pin`).
  void setPinAfterPublish({required bool value}) {
    if (_isLocked) return;
    state = state.copyWith(pinAfterPublish: value, isDirty: true);
  }

  /// Hakkı dolmuşken bildirim anahtarına dokunuldu: DLG-24 açıklar;
  /// "Bildirimsiz yayınla" seçilirse duyuru bildirimsiz işaretlenir
  /// (yayınlamaz).
  Future<void> explainLimit() async {
    final silent = await feedback.showDialog<bool>(DialogId.dlg24) ?? false;
    if (silent && ref.mounted) setPushEnabled(value: false);
  }

  /// "Önizle" / "Düzenlemeye dön" (`FED-03.preview`): form yerine gönderinin
  /// üyelere görüneceği kart çizilir (prototip `authorPreview`). Önizleme
  /// hiçbir şey yazmaz.
  void togglePreview() {
    if (_isLocked) return;
    if (state.isPreview) {
      state = state.copyWith(clearPreview: true);
      return;
    }
    final now = appClock.nowUtc();
    final isPoll = state.type == PostType.poll;
    state = state.copyWith(
      preview: PostModel(
        id: _previewId,
        clubId: clubId,
        authorId: ref.read(sessionViewModelProvider).uid ?? '',
        type: state.type,
        title: state.type == PostType.announcement ? state.title : null,
        text: state.text.isEmpty ? _previewEmptyText : state.text,
        images: state.type == PostType.post
            ? [
                for (final (index, image) in state.images.indexed)
                  image.previewModel(index),
              ]
            : const [],
        poll: isPoll
            ? PollModel(
                options: [
                  for (final (index, text) in state.filledOptions.indexed)
                    PollOptionModel(
                      id: FirestoreIds.pollOption(index),
                      text: text,
                    ),
                ],
                endsAt: now.add(Duration(days: state.pollDuration.days)),
              )
            : null,
        pinned: state.pinAfterPublish,
        pushSent: state.pushEnabled,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// "Temizle" (`FED-03.clear`): metin, başlık, görseller ve seçenekler
  /// boşalır. Düzenlenen ankette etkisizdir.
  void clear() {
    if (_isLocked || state.isPollLocked) return;
    state = state.copyWith(
      title: '',
      text: '',
      images: const [],
      pollOptions: const ['', ''],
      errors: const {},
      isDirty: true,
      isSubmitError: false,
    );
  }

  // ───────────────────────────────── okuma ──────────────────────────────────

  /// Günün bildirimli duyuru sayısını okur ("{used}/2" çubuğu). Okunamazsa
  /// eldeki değer kalır; sınırı yayın anında repository uygular.
  Future<void> loadQuota() async {
    final result = await announcementCounterRepository.getToday(clubId);
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess(:final data):
        state = state.copyWith(quotaUsed: data?.count ?? 0);
      case FirebaseFailure(:final error):
        AppLogger.warn('Duyuru hakkı okunamadı: ${error.name}');
    }
  }

  /// Düzenlenecek gönderiyi okur ve formu doldurur; hata görünümündeki
  /// "Yeniden dene" (`FED-03.retry`). Başka kulübün gönderisi okunamadı
  /// sayılır.
  Future<void> loadForEdit() async {
    final postId = editPostId;
    if (postId == null || !ref.mounted) return;
    state = state.copyWith(isLoadingEdit: true, isError: false);
    final result = await postRepository.getPost(postId);
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess(:final data) when data.clubId == clubId:
        final poll = data.poll;
        state = state.copyWith(
          editPost: data,
          type: data.type,
          title: data.title ?? '',
          text: data.text,
          images: [
            for (final image in data.images) ComposeImage.remote(image),
          ],
          pollOptions: poll == null
              ? null
              : [for (final option in poll.options) option.text],
          showResultsAfterVote: poll?.showResultsAfterVote,
          pushEnabled: data.pushSent,
          pinAfterPublish: data.pinned,
          errors: const {},
          isDirty: false,
          isLoadingEdit: false,
        );
      case FirebaseSuccess():
        AppLogger.warn('Düzenlenecek gönderi başka kulübün: $postId');
        state = state.copyWith(isLoadingEdit: false, isError: true);
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Düzenlenecek gönderi okunamadı: ${error.name}',
          error: message,
        );
        state = state.copyWith(isLoadingEdit: false, isError: true);
    }
  }

  // ───────────────────────────── doğrulama / taslak ─────────────────────────

  /// Formu doğrular ve alan hatalarını state'e yazar; hata yoksa `true`
  /// (prototip `validate`). Metin zorunlu; duyuruda başlık zorunlu; ankette
  /// en az iki dolu ve birbirinden farklı seçenek.
  bool validate() {
    final errors = _errors();
    state = state.copyWith(errors: errors);
    return errors.isEmpty;
  }

  /// "Taslak kaydet" (`FED-03.saveDraft`, DLG-25 "Kaydet"): formu cihaza
  /// yazar → TST-13. Kulüp başına tek taslak tutulur (yenisi eskisinin
  /// yerini alır); görseller saklanmaz. Düzenlemede taslak yoktur (`false`).
  Future<bool> saveDraft() async {
    if (editPostId != null || _isLocked || state.isSavingDraft) return false;
    state = state.copyWith(isSavingDraft: true);
    final persisted = await appPreferencesStore.setComposeDraft(
      clubId,
      ComposeDraft.encode(state),
    );
    // Depo değeri bellekte tutar: oturum boyunca taslak geçerlidir.
    if (!persisted) AppLogger.warn('Yazı taslağı kalıcı yazılamadı');
    if (ref.mounted) {
      state = state.copyWith(
        isSavingDraft: false,
        isDirty: false,
        hasDraft: true,
      );
    }
    feedback.showToast(ToastId.tst13);
    return true;
  }

  /// Cihazdaki taslağı kaldırır (yayın başarısında).
  Future<void> clearDraft() async {
    if (!await appPreferencesStore.setComposeDraft(clubId, null)) {
      AppLogger.warn('Yazı taslağı kaldırılamadı');
    }
    if (ref.mounted) state = state.copyWith(hasDraft: false);
  }

  // ───────────────────────────────── yayın ──────────────────────────────────

  /// "Yayınla" / "Kaydet" (`FED-03.publish`). Sıra sınıf açıklamasındadır.
  /// [onView] TST-14'ün "Görüntüle" eylemidir (gönderi kimliğiyle; view
  /// FED-02'ye gider).
  Future<ComposeOutcome> publish({
    void Function(String postId)? onView,
  }) async {
    if (_isLocked || state.isLoadingEdit || state.isError) {
      return ComposeOutcome.ignored;
    }
    if (!validate()) return ComposeOutcome.invalid;
    final session = ref.read(sessionViewModelProvider);
    final uid = session.uid;
    if (uid == null) return ComposeOutcome.ignored;
    // Prototip `app.guard(clubId)`: danışman salt okunurdur.
    if (session.accessTo(clubId) == ClubAccess.advisor) {
      feedback.showToast(ToastId.tst26);
      return ComposeOutcome.blocked;
    }
    if (!ensureOnline()) return ComposeOutcome.blocked;
    final post = state.editPost;
    return post == null ? _create(uid, onView) : _update(uid, post, onView);
  }

  // ────────────────────────────────── iç ────────────────────────────────────

  /// Gönderim sürerken form değişmez.
  bool get _isLocked => !ref.mounted || state.isSubmitting;

  Future<void> _start() async {
    if (!ref.mounted) return;
    await Future.wait<void>([
      _loadClub(),
      loadQuota(),
      if (editPostId != null) loadForEdit(),
    ]);
  }

  Future<void> _loadClub() async {
    final result = await clubRepository.getClub(clubId);
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess(:final data):
        state = state.copyWith(club: data);
      case FirebaseFailure(:final error):
        AppLogger.warn('Yazı ekranı: kulüp okunamadı: ${error.name}');
    }
  }

  Future<ComposeOutcome> _create(
    String uid,
    void Function(String postId)? onView,
  ) async {
    var pushSent = state.type == PostType.announcement && state.pushEnabled;
    if (pushSent && state.limitReached) {
      if (!await _confirmSilent()) return ComposeOutcome.cancelled;
      pushSent = false;
    }
    if (!ref.mounted) return ComposeOutcome.ignored;
    // Ekran gönderim sürerken kapanabilir: sonraki adımlar bu kopyayı okur.
    final form = state;
    state = form.copyWith(isSubmitting: true, isSubmitError: false);
    final postId = _postId ??= postRepository.newPostId();
    final images = await _uploadImages(uid, postId, form);
    if (images == null) return ComposeOutcome.failed;

    Future<FirestoreResult<PostModel>> write({required bool pushSent}) =>
        postRepository.create(
          _draftOf(form, images, pushSent: pushSent),
          authorId: uid,
          clubId: clubId,
          postId: postId,
        );

    var result = await write(pushSent: pushSent);
    if (result case FirebaseFailure(
      error: FirestoreError.ruleViolation,
      detail: FirestoreFailureDetail(code: FirestoreRuleCode.announcementLimit),
    )) {
      // Hak bu arada doldu (başka yönetici yayınladı): hiçbir şey yazılmadı.
      if (ref.mounted) state = state.copyWith(quotaUsed: state.quotaLimit);
      if (!await _confirmSilent()) {
        if (ref.mounted) state = state.copyWith(isSubmitting: false);
        return ComposeOutcome.cancelled;
      }
      result = await write(pushSent: false);
    }
    switch (result) {
      case FirebaseSuccess():
        if (form.pinAfterPublish) await _applyPin(postId, pinned: true);
        await clearDraft();
        return _published(postId, onView);
      case FirebaseFailure(:final error, :final message):
        return _writeFailed(error, message);
    }
  }

  Future<ComposeOutcome> _update(
    String uid,
    PostModel post,
    void Function(String postId)? onView,
  ) async {
    final form = state;
    final text = form.text.trim();
    final title = form.title.trim();
    // Anket sorusu yayından sonra değişmez: `text` gönderilmez (W-71).
    final textChanged = !post.isPoll && text != post.text;
    final titleChanged = post.isAnnouncement && title != (post.title ?? '');
    final imagesChanged =
        post.type == PostType.post && !_sameImages(form.images, post.images);
    final pinChanged = form.pinAfterPublish != post.pinned;
    if (!textChanged && !titleChanged && !imagesChanged && !pinChanged) {
      feedback.showToast(ToastId.tstX9);
      return ComposeOutcome.nothingToSave;
    }
    state = form.copyWith(isSubmitting: true, isSubmitError: false);
    List<PostImageModel>? images;
    if (imagesChanged) {
      images = await _uploadImages(uid, post.id, form);
      if (images == null) return ComposeOutcome.failed;
    }
    if (textChanged || titleChanged || imagesChanged) {
      final result = await postRepository.update(
        post.id,
        PostEditPatch(
          text: textChanged ? text : null,
          title: titleChanged ? title : null,
          images: images,
        ),
        authorId: uid,
      );
      // Askıdaki / silinmiş kulüpte ve yazar olmayan yöneticide
      // `permissionDenied` → TST-X18.
      if (result case FirebaseFailure(:final error, :final message)) {
        return _writeFailed(error, message);
      }
    }
    if (pinChanged) {
      final error = await _applyPin(post.id, pinned: form.pinAfterPublish);
      if (error != null) return _writeFailed(error, null);
    }
    return _published(post.id, onView);
  }

  /// [form] görsellerinden yüklenmemiş olanları yükler ve tüm görsellerin
  /// modellerini form sırasıyla döner; yükleme başarısızsa bildirir ve `null`
  /// döner (yüklenenler state'te işaretli kalır). Görsel yalnızca gönderi
  /// türünde yazılır. [uid] oturumdaki kullanıcıdır: dosyanın üst verisine
  /// yükleyen olarak yazılır (Storage Rules oturumla karşılaştırır).
  Future<List<PostImageModel>?> _uploadImages(
    String uid,
    String postId,
    ComposeState form,
  ) async {
    if (form.type != PostType.post) return const [];
    final models = <int, PostImageModel>{};
    final pending = <int>[];
    for (final (index, image) in form.images.indexed) {
      final uploaded = image.uploaded;
      if (uploaded == null) {
        pending.add(index);
      } else {
        models[index] = uploaded;
      }
    }
    if (pending.isNotEmpty) {
      final result = await postRepository.uploadImages(
        postId,
        [
          for (final index in pending)
            if (form.images[index].picked case final picked?)
              PostImageUpload(
                bytes: picked.bytes,
                contentType: picked.contentType,
                width: picked.width,
                height: picked.height,
              ),
        ],
        clubId: clubId,
        uploaderId: uid,
        onUploaded: (position, model) {
          final index = pending[position];
          models[index] = model;
          if (!ref.mounted) return;
          state = state.copyWith(
            images: [
              for (final (i, image) in state.images.indexed)
                i == index ? image.withUploaded(model) : image,
            ],
          );
        },
      );
      if (result case FirebaseFailure(:final error, :final message)) {
        _uploadFailed(error, message);
        return null;
      }
    }
    return [
      for (var index = 0; index < form.images.length; index++) ?models[index],
    ];
  }

  /// Sabitler / sabitlemeyi kaldırır; hata döner (yoksa `null`). Yeni
  /// gönderide hata yayını geri almaz (gönderi yazıldı), yalnızca günlüğe
  /// düşer.
  Future<FirestoreError?> _applyPin(
    String postId, {
    required bool pinned,
  }) async {
    final result = pinned
        ? await postRepository.pin(postId, clubId: clubId)
        : await postRepository.unpin(postId, clubId: clubId);
    if (result case FirebaseFailure(:final error, :final message)) {
      AppLogger.warn('Sabitleme yazılamadı: ${error.name}', error: message);
      return error;
    }
    return null;
  }

  /// DLG-24: "Bildirimsiz yayınla" → `true`; "Vazgeç" / scrim / geri →
  /// `false`.
  Future<bool> _confirmSilent() async =>
      await feedback.showDialog<bool>(DialogId.dlg24) ?? false;

  ComposeOutcome _published(
    String postId,
    void Function(String postId)? onView,
  ) {
    if (ref.mounted) {
      state = state.copyWith(isSubmitting: false, isDirty: false);
    }
    feedback.showToast(
      ToastId.tst14,
      onAction: onView == null ? null : () => onView(postId),
    );
    return ComposeOutcome.published;
  }

  /// Yazım hatası: ağ → TST-24, yetki yok → TST-X18; diğerleri hata bandı.
  ComposeOutcome _writeFailed(FirestoreError error, String? message) {
    final shown = showWriteFailureToast(error);
    if (!shown) {
      AppLogger.warn('Gönderi yazılamadı: ${error.name}', error: message);
    }
    if (ref.mounted) {
      state = state.copyWith(isSubmitting: false, isSubmitError: !shown);
    }
    return ComposeOutcome.failed;
  }

  /// Yükleme hatası: bağlantı → TST-24, Storage reddi → TST-X18; diğerleri
  /// hata bandı.
  void _uploadFailed(MediaUpdateError error, String? message) {
    final storage = error.storage;
    final firestore = error.firestore;
    var shown = true;
    if (_networkUploadErrors.contains(storage) ||
        WriteGuardMixin.networkErrors.contains(firestore)) {
      feedback.showToast(ToastId.tst24);
    } else if (storage == StorageError.unauthorized ||
        firestore == FirestoreError.permissionDenied) {
      feedback.showToast(ToastId.tstX18);
    } else {
      shown = false;
      AppLogger.warn('Gönderi görseli yüklenemedi: $error', error: message);
    }
    if (ref.mounted) {
      state = state.copyWith(isSubmitting: false, isSubmitError: !shown);
    }
  }

  /// [form] alanlarından yayın taslağı: yalnızca türün alanları taşınır.
  static PostDraft _draftOf(
    ComposeState form,
    List<PostImageModel> images, {
    required bool pushSent,
  }) => PostDraft(
    type: form.type,
    text: form.text.trim(),
    title: form.type == PostType.announcement ? form.title.trim() : null,
    images: images,
    poll: form.type == PostType.poll
        ? PollDraft(
            options: form.filledOptions,
            durationDays: form.pollDuration.days,
            showResultsAfterVote: form.showResultsAfterVote,
          )
        : null,
    pushSent: pushSent,
  );

  Map<ComposeField, FormFieldError> _errors() => validateFields({
    ComposeField.text: () =>
        state.text.trim().isEmpty ? FormFieldError.required : null,
    if (state.type == PostType.announcement)
      ComposeField.title: () =>
          state.title.trim().isEmpty ? FormFieldError.required : null,
    if (state.type == PostType.poll && !state.isPollLocked)
      ComposeField.options: () {
        final options = state.filledOptions;
        if (options.length < Limits.pollOptionsMin) {
          return FormFieldError.tooShort;
        }
        return options.toSet().length == options.length
            ? null
            : FormFieldError.invalidFormat;
      },
  });

  /// Düzenleme sonrası ortak güncelleme: form kirlenir, [fields] alanlarının
  /// hatası ve eski gönderim hatası silinir.
  ComposeState _edited(ComposeState next, List<ComposeField> fields) =>
      next.copyWith(
        isDirty: true,
        isSubmitError: false,
        errors: {
          for (final entry in next.errors.entries)
            if (!fields.contains(entry.key)) entry.key: entry.value,
        },
      );

  /// Formdaki görseller gönderidekilerle aynı mı (sıra dahil; yeni görsel
  /// yok)?
  static bool _sameImages(
    List<ComposeImage> images,
    List<PostImageModel> original,
  ) {
    if (images.length != original.length) return false;
    for (final (index, image) in images.indexed) {
      if (image.picked != null || image.uploaded != original[index]) {
        return false;
      }
    }
    return true;
  }

  /// [text] metninin [max] karakterle sınırlı hali; vekil çiftin ortasından
  /// kesilmez.
  static String _clamped(String text, int max) {
    if (text.length <= max) return text;
    final end = _isHighSurrogate(text.codeUnitAt(max - 1)) ? max - 1 : max;
    return text.substring(0, end);
  }

  static bool _isHighSurrogate(int unit) => (unit & 0xFC00) == 0xD800;
}
