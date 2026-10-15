import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';

/// FED-03 formunun hata taşıyabilen alanları.
enum ComposeField {
  /// Duyuru başlığı (`FED-03.title`): duyuruda zorunlu.
  title,

  /// Metin / anket sorusu (`FED-03.text`): her türde zorunlu.
  text,

  /// Görseller: seçilen görsel işlenemedi (`invalidFormat`) ya da boyut
  /// sınırında (`limitExceeded`).
  images,

  /// Anket seçenekleri: ikiden az dolu seçenek (`tooShort`) ya da aynı metin
  /// iki kez (`invalidFormat`).
  options,
}

/// Anketin açık kalacağı süre (`FED-03.duration.<gün>`;
/// `Limits.pollDurationsDays`).
enum PollDuration {
  /// 1 gün.
  d1(1),

  /// 3 gün (varsayılan — prototip `duration: 3`).
  d3(3),

  /// 7 gün.
  d7(7);

  const PollDuration(this.days);

  /// Gün sayısı (`PollDraft.durationDays`).
  final int days;

  /// [days] günlük süre; tanınmayan değerde varsayılan ([d3]).
  static PollDuration ofDays(Object? days) {
    for (final duration in values) {
      if (duration.days == days) return duration;
    }
    return PollDuration.d3;
  }
}

/// `ComposeViewModel.publish` sonucu.
enum ComposeOutcome {
  /// Çağrı yok sayıldı (süren gönderim, yüklenmemiş form, oturum yok).
  ignored,

  /// Form geçersiz; alan hataları state'e yazıldı.
  invalid,

  /// Yazılamaz: danışman (TST-26) ya da çevrimdışı (TST-24).
  blocked,

  /// DLG-24'te "Vazgeç" seçildi.
  cancelled,

  /// Düzenlemede değişiklik yok (TST-X9).
  nothingToSave,

  /// Yükleme ya da yazım başarısız (toast / hata bandı gösterildi).
  failed,

  /// Yayınlandı / kaydedildi (TST-14); view akışa döner.
  published,
}

/// Formdaki tek görsel: yeni seçilmiş ([picked], henüz yüklenmemiş olabilir)
/// ya da gönderide zaten bulunan ([uploaded]).
///
/// Yeni görsel yüklendikten sonra ikisi de doludur: [picked] küçük
/// önizlemeyi çizmeye, [uploaded] yeniden denemede dosyanın bir daha
/// gönderilmemesine yarar.
final class ComposeImage extends Equatable {
  /// Yeni seçilmiş, henüz yüklenmemiş görsel.
  const ComposeImage.local(PickedImage this.picked) : uploaded = null;

  /// Gönderide zaten bulunan görsel (düzenleme kipi).
  const ComposeImage.remote(PostImageModel this.uploaded) : picked = null;

  const ComposeImage._({required this.picked, required this.uploaded});

  /// Seçicinin verdiği yeniden kodlanmış görsel; mevcut görselde `null`.
  final PickedImage? picked;

  /// Storage'daki görsel; yüklenmediyse `null`.
  final PostImageModel? uploaded;

  /// Görsel Storage'da mı?
  bool get isUploaded => uploaded != null;

  /// [model] olarak yüklenmiş kopya.
  ComposeImage withUploaded(PostImageModel model) =>
      ComposeImage._(picked: picked, uploaded: model);

  /// Önizleme kartındaki görsel modeli: yüklenmişse kendisi, değilse
  /// [index] sırasını taşıyan geçici bir yol ([previewPath]) — kart baytları
  /// bu yoldan bulur.
  PostImageModel previewModel(int index) =>
      uploaded ??
      PostImageModel(
        path: previewPath(index),
        w: picked?.width ?? 0,
        h: picked?.height ?? 0,
      );

  /// Yüklenmemiş [index] sırasındaki görselin önizleme yolu (Storage yolu
  /// değildir; hiçbir yere yazılmaz).
  static String previewPath(int index) => 'preview/$index';

  @override
  List<Object?> get props => [picked, uploaded];
}

/// FED-03 "Yeni gönderi" / "Gönderiyi düzenle" durumu (PLAN §12.8; prototip
/// `Compose`, `screens-clubs.js:181–215`).
///
/// Form alanları türe göre okunur: [title] yalnızca duyuruda, [images]
/// yalnızca gönderide, [pollOptions] / [pollDuration] /
/// [showResultsAfterVote] yalnızca ankette, [pushEnabled] yalnızca duyuruda
/// anlam taşır. Tür değişince alanlar silinmez (geri dönüldüğünde durur).
///
/// Düzenleme kipinde [editPost] doludur: tür değişmez; ankette soru,
/// seçenekler ve süre salt okunurdur ([isPollLocked] — W-71).
final class ComposeState extends Equatable {
  /// Varsayılan: boş gönderi formu.
  const ComposeState({
    this.type = PostType.post,
    this.title = '',
    this.text = '',
    this.images = const [],
    this.pollOptions = const ['', ''],
    this.pollDuration = PollDuration.d3,
    this.showResultsAfterVote = true,
    this.pushEnabled = true,
    this.pinAfterPublish = false,
    this.quotaUsed = 0,
    this.quotaLimit = Limits.announcementDailyLimit,
    this.hasDraft = false,
    this.errors = const {},
    this.isDirty = false,
    this.isSubmitting = false,
    this.isSavingDraft = false,
    this.isSubmitError = false,
    this.isLoadingEdit = false,
    this.isError = false,
    this.preview,
    this.club,
    this.editPost,
  });

  /// Gönderi türü (`FED-03.type.*`).
  final PostType type;

  /// Duyuru başlığı (≤ `Limits.postTitleMax`).
  final String title;

  /// Metin; ankette soru (≤ `Limits.postTextMax`).
  final String text;

  /// Görseller, gösterim sırasıyla (≤ `Limits.postImagesMax`).
  final List<ComposeImage> images;

  /// Anket seçenekleri (`Limits.pollOptionsMin` – `Limits.pollOptionsMax`
  /// satır; boş satır yayında atılır).
  final List<String> pollOptions;

  /// Anket süresi.
  final PollDuration pollDuration;

  /// Sonuçlar yalnızca oy verince mi görünsün?
  final bool showResultsAfterVote;

  /// Duyuru üyelere bildirimle mi gitsin? Günün hakkı dolmuşsa anahtar kapalı
  /// çizilir ([pushActive]).
  final bool pushEnabled;

  /// Yayından sonra sabitlensin mi (`FED-03.pin`); düzenlemede gönderinin
  /// sabit olup olmadığı.
  final bool pinAfterPublish;

  /// Kulübün bugün gönderdiği bildirimli duyuru sayısı.
  final int quotaUsed;

  /// Günlük bildirimli duyuru sınırı.
  final int quotaLimit;

  /// Form cihazdaki taslaktan mı kuruldu / taslak kaydedildi mi (CD-45)?
  final bool hasDraft;

  /// Alan hataları (metne çeviri view'da).
  final Map<ComposeField, FormFieldError> errors;

  /// Kaydedilmemiş değişiklik var mı (DLG-25)?
  final bool isDirty;

  /// Görseller yükleniyor / gönderi yazılıyor ("Yayınla" döner, form kilitli).
  final bool isSubmitting;

  /// Taslak yazılıyor.
  final bool isSavingDraft;

  /// Son gönderim toast'la bildirilemeyen bir hatayla bitti (form üstünde
  /// hata bandı).
  final bool isSubmitError;

  /// Düzenlenecek gönderi okunuyor (iskelet).
  final bool isLoadingEdit;

  /// Düzenlenecek gönderi okunamadı ("Yeniden dene").
  final bool isError;

  /// Önizleme kipinde (`FED-03.preview`) form yerine çizilen gönderi; kip
  /// kapalıyken `null`.
  final PostModel? preview;

  /// Kulüp (yazar satırı, bildirim önizlemesi, görsel yer tutucusu);
  /// okunamadıysa `null`.
  final ClubModel? club;

  /// Düzenlenen gönderi; yeni gönderide `null`.
  final PostModel? editPost;

  /// Düzenleme kipi mi?
  bool get isEditing => editPost != null;

  /// Önizleme kipi açık mı?
  bool get isPreview => preview != null;

  /// Düzenlenen anket: soru, seçenekler, süre ve sonuç ayarı değişmez (oylar
  /// taşınamaz — W-71).
  bool get isPollLocked => isEditing && type == PostType.poll;

  /// Günün bildirimli duyuru hakkı doldu mu?
  bool get limitReached => quotaUsed >= quotaLimit;

  /// Bildirim anahtarının çizilen değeri: hak dolmuşsa kapalıdır.
  bool get pushActive => pushEnabled && !limitReached;

  /// Bir görsel daha eklenebilir mi (dolmuşsa TST-X5)?
  bool get canAddImage => images.length < Limits.postImagesMax;

  /// "Seçenek ekle" çizilsin mi?
  bool get canAddPollOption =>
      !isPollLocked && pollOptions.length < Limits.pollOptionsMax;

  /// Seçenek satırlarında "Kaldır" çizilsin mi?
  bool get canRemovePollOption =>
      !isPollLocked && pollOptions.length > Limits.pollOptionsMin;

  /// Dolu seçenekler, kırpılmış, satır sırasıyla.
  List<String> get filledOptions => [
    for (final option in pollOptions)
      if (option.trim().isNotEmpty) option.trim(),
  ];

  /// "Yayınla" etkin mi (prototip `valid`): metin dolu; duyuruda başlık da;
  /// ankette en az iki dolu seçenek. Tekrarlı seçenek dokunuşta denetlenir.
  bool get isValid {
    if (text.trim().isEmpty) return false;
    return switch (type) {
      PostType.post => true,
      PostType.announcement => title.trim().isNotEmpty,
      PostType.poll => filledOptions.length >= Limits.pollOptionsMin,
    };
  }

  @override
  List<Object?> get props => [
    type,
    title,
    text,
    images,
    pollOptions,
    pollDuration,
    showResultsAfterVote,
    pushEnabled,
    pinAfterPublish,
    quotaUsed,
    quotaLimit,
    hasDraft,
    errors,
    isDirty,
    isSubmitting,
    isSavingDraft,
    isSubmitError,
    isLoadingEdit,
    isError,
    preview,
    club,
    editPost,
  ];

  /// Verilen alanları değiştirilmiş kopya. [clearPreview] önizlemeyi kapatır
  /// ve [preview] parametresinden önce gelir.
  ComposeState copyWith({
    PostType? type,
    String? title,
    String? text,
    List<ComposeImage>? images,
    List<String>? pollOptions,
    PollDuration? pollDuration,
    bool? showResultsAfterVote,
    bool? pushEnabled,
    bool? pinAfterPublish,
    int? quotaUsed,
    int? quotaLimit,
    bool? hasDraft,
    Map<ComposeField, FormFieldError>? errors,
    bool? isDirty,
    bool? isSubmitting,
    bool? isSavingDraft,
    bool? isSubmitError,
    bool? isLoadingEdit,
    bool? isError,
    PostModel? preview,
    bool clearPreview = false,
    ClubModel? club,
    PostModel? editPost,
  }) => ComposeState(
    type: type ?? this.type,
    title: title ?? this.title,
    text: text ?? this.text,
    images: images ?? this.images,
    pollOptions: pollOptions ?? this.pollOptions,
    pollDuration: pollDuration ?? this.pollDuration,
    showResultsAfterVote: showResultsAfterVote ?? this.showResultsAfterVote,
    pushEnabled: pushEnabled ?? this.pushEnabled,
    pinAfterPublish: pinAfterPublish ?? this.pinAfterPublish,
    quotaUsed: quotaUsed ?? this.quotaUsed,
    quotaLimit: quotaLimit ?? this.quotaLimit,
    hasDraft: hasDraft ?? this.hasDraft,
    errors: errors ?? this.errors,
    isDirty: isDirty ?? this.isDirty,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    isSavingDraft: isSavingDraft ?? this.isSavingDraft,
    isSubmitError: isSubmitError ?? this.isSubmitError,
    isLoadingEdit: isLoadingEdit ?? this.isLoadingEdit,
    isError: isError ?? this.isError,
    preview: clearPreview ? null : preview ?? this.preview,
    club: club ?? this.club,
    editPost: editPost ?? this.editPost,
  );
}

/// FED-03 yerel taslağının JSON kodlaması (CD-45): cihazda
/// `compose_draft_<clubId>` anahtarında, kulüp başına tek kayıt.
///
/// **Taslak yazarın uid'siyle etiketlenir (T-45 · A3-02):** ortak cihazda
/// başka hesabın taslağı forma yüklenmez; etiketsiz (eski) kayıt da yok
/// sayılır. Sahibi yeniden girince taslağı geri gelir.
///
/// Yalnızca yazarın girdiği alanlar saklanır. **Görseller saklanmaz:**
/// seçilen görsel bellekteki yeniden kodlanmış baytlardır (cihazda dosya yolu
/// yoktur) ve megabaytlarca veri tercihlere yazılmaz; taslak açıldığında
/// görseller yeniden eklenir.
abstract final class ComposeDraft {
  static const String _type = 'type';
  static const String _title = 'title';
  static const String _text = 'text';
  static const String _options = 'options';
  static const String _duration = 'duration';
  static const String _showAfterVote = 'showAfterVote';
  static const String _push = 'push';
  static const String _pin = 'pin';
  static const String _ownerUid = 'ownerUid';

  /// [state] formunun [ownerUid] hesabına ait taslak metni.
  static String encode(ComposeState state, {required String ownerUid}) =>
      jsonEncode(<String, Object>{
        _ownerUid: ownerUid,
        _type: state.type.name,
        _title: state.title,
        _text: state.text,
        _options: state.pollOptions,
        _duration: state.pollDuration.days,
        _showAfterVote: state.showResultsAfterVote,
        _push: state.pushEnabled,
        _pin: state.pinAfterPublish,
      });

  /// [json] taslağından kurulan form ([ComposeState.hasDraft] `true`);
  /// taslak yoksa, okunamıyorsa (bozuk / eski biçim) ya da [uid] hesabının
  /// değilse `null`. Sınır dışı değerler kesilir, tanınmayanlar varsayılana
  /// düşer.
  static ComposeState? decode(String? json, {required String uid}) {
    if (json == null || json.isEmpty) return null;
    final Object? parsed;
    try {
      parsed = jsonDecode(json);
    } on FormatException {
      return null;
    }
    if (parsed is! Map<String, Object?>) return null;
    final decoded = parsed;
    if (decoded[_ownerUid] != uid) return null;
    final options = switch (decoded[_options]) {
      final List<Object?> values =>
        values
            .whereType<String>()
            .take(Limits.pollOptionsMax)
            .map((option) => _capped(option, Limits.pollOptionTextMax))
            .toList(),
      _ => <String>[],
    };
    while (options.length < Limits.pollOptionsMin) {
      options.add('');
    }
    return ComposeState(
      type: PostType.values.firstWhere(
        (type) => type.name == decoded[_type],
        orElse: () => PostType.post,
      ),
      title: _capped(decoded[_title], Limits.postTitleMax),
      text: _capped(decoded[_text], Limits.postTextMax),
      pollOptions: options,
      pollDuration: PollDuration.ofDays(decoded[_duration]),
      showResultsAfterVote: decoded[_showAfterVote] != false,
      pushEnabled: decoded[_push] != false,
      pinAfterPublish: decoded[_pin] == true,
      hasDraft: true,
    );
  }

  static String _capped(Object? value, int max) {
    if (value is! String) return '';
    return value.length <= max ? value : value.substring(0, max);
  }
}
