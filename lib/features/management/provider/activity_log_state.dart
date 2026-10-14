import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/manage/activity_lookups.dart';

/// MGT-10'da bir gün grubu (Istanbul günü) ve kayıtları (en yeni üstte) —
/// prototip `groups` (`screens-manage.js:194`, `dayKey(a.createdAt)`).
final class ActivityDaySection extends Equatable {
  /// [day] gününün [items] kayıtları.
  const ActivityDaySection({required this.day, required this.items});

  /// Günün başlangıcı (Istanbul gece yarısı, UTC an); başlık metni
  /// `RelativeTimeFormatter.dayLabel` ile view'da üretilir.
  final DateTime day;

  /// O günün kayıtları (sorgu sırasıyla).
  final List<ActivityModel> items;

  @override
  List<Object?> get props => [day, items];
}

/// Faaliyet satırına dokunmanın hedef türü — prototip `ActivityRow.go`
/// (`screens-manage.js:37`) sırasıyla.
enum ActivityLogTargetKind {
  /// EVT-02 Etkinlik detayı (`refs.eventId`).
  event,

  /// FED-02 Gönderi (`refs.postId`).
  post,

  /// MGT-02 Başvurular (`application_*` türleri).
  applications,

  /// CLB-07 Profil (`refs.userId`).
  profile,

  /// MGT-09 Kulüp ayarları (diğer her şey).
  settings,

  /// Hedef kaldırılmış (silinmiş etkinlik): satır bir yere gitmez.
  none,
}

/// Faaliyet satırının hedefi: tür + (varsa) belge kimliği.
final class ActivityLogTarget extends Equatable {
  /// [kind] hedefi; [id] etkinlik / gönderi / kullanıcı kimliği.
  const ActivityLogTarget(this.kind, [this.id]);

  /// Hedef türü.
  final ActivityLogTargetKind kind;

  /// Hedef belge kimliği ([ActivityLogTargetKind.event] / `post` /
  /// `profile`); diğerlerinde `null`.
  final String? id;

  @override
  List<Object?> get props => [kind, id];
}

/// MGT-10 "Faaliyet geçmişi" durumu (PLAN §12.6 `ActivityLogViewModel`).
///
/// * [entries] okunmuş sayfaların kayıtları (en yeni üstte; tanınmayan tür
///   [ActivityKind.unknown] süzülmüş); [sections] aynı listenin Istanbul gün
///   grupları.
/// * [category] seçili tür grubu çipi; `null` → "Tümü". Süzgeç sorguda
///   uygulanır (`listActivity(category:)`), değişince liste baştan okunur.
/// * [lookups] satır metinlerinin adları (eylemci / hedef kullanıcı,
///   etkinlik başlığı); bulunamayan → "Silinmiş kullanıcı" / "İçerik
///   kaldırıldı".
/// * [cursor] sonraki sayfanın imleci (20 + imleç); `null` → liste bitti.
final class ActivityLogState extends Equatable {
  /// Varsayılan: içerik yok.
  const ActivityLogState({
    this.club,
    this.entries = const [],
    this.sections = const [],
    this.category,
    this.lookups = const ActivityLookups(),
    this.cursor,
    this.isFetching = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.isError = false,
  });

  /// Kulüp (başlık: ad); okunamadıysa `null`.
  final ClubModel? club;

  /// Okunmuş kayıtlar (tüm sayfalar).
  final List<ActivityModel> entries;

  /// [entries]'in gün grupları (boş grup yok).
  final List<ActivityDaySection> sections;

  /// Seçili tür grubu; `null` → tümü.
  final ActivityCategory? category;

  /// Satır metinlerinin adları.
  final ActivityLookups lookups;

  /// Sonraki sayfanın imleci; `null` → son sayfa okundu.
  final PageCursor? cursor;

  /// İlk sayfa (ya da süzgeç değişince yeni ilk sayfa) okunuyor (iskelet).
  final bool isFetching;

  /// Sonraki sayfa okunuyor (liste sonunda iskelet).
  final bool isLoadingMore;

  /// Çek-yenile sürüyor (içerik kalır).
  final bool isRefreshing;

  /// İlk sayfa okunamadı (hata görünümü + "Yeniden dene").
  final bool isError;

  /// Sonraki sayfa var mı?
  bool get hasMore => cursor != null;

  /// Liste boş mu (süzgeç sonrası).
  bool get isEmpty => entries.isEmpty;

  /// Sonraki sayfa istenebilir mi (okuma sürmüyor, hata yok, imleç var)?
  bool get wantsMore => hasMore && !isFetching && !isLoadingMore && !isError;

  @override
  List<Object?> get props => [
    club,
    entries,
    sections,
    category,
    lookups,
    cursor,
    isFetching,
    isLoadingMore,
    isRefreshing,
    isError,
  ];

  /// Değişen alanlarla kopya; [clearCategory] / [clearCursor] ilgili alanı
  /// `null` yapar.
  ActivityLogState copyWith({
    ClubModel? club,
    List<ActivityModel>? entries,
    List<ActivityDaySection>? sections,
    ActivityCategory? category,
    bool clearCategory = false,
    ActivityLookups? lookups,
    PageCursor? cursor,
    bool clearCursor = false,
    bool? isFetching,
    bool? isLoadingMore,
    bool? isRefreshing,
    bool? isError,
  }) => ActivityLogState(
    club: club ?? this.club,
    entries: entries ?? this.entries,
    sections: sections ?? this.sections,
    category: clearCategory ? null : category ?? this.category,
    lookups: lookups ?? this.lookups,
    cursor: clearCursor ? null : cursor ?? this.cursor,
    isFetching: isFetching ?? this.isFetching,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isError: isError ?? this.isError,
  );
}
