import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/admin/provider/report_group.dart';
import 'package:gu_kulupler/features/admin/provider/report_target_preview.dart';
import 'package:gu_kulupler/features/admin/view/widget/report_detail_sheet.dart';
import 'package:gu_kulupler/product/navigation/admin_reports_tab.dart';

/// ADM-04 hedef türü süzgeci (`ADM-04.filter.<name>`; prototip sırası
/// `screens-admin.js:63`). Neden süzgeci tasarımda yoktur (CD-33 nedenleri
/// satır rozetinde görünür).
enum ReportTargetFilter {
  /// Tümü.
  all,

  /// Gönderi.
  post,

  /// Yorum.
  comment,

  /// Kullanıcı.
  user,

  /// Kulüp.
  club,

  /// Etkinlik.
  event;

  /// Süzülen hedef türü; [all] → `null`.
  ReportTargetType? get type => switch (this) {
    ReportTargetFilter.all => null,
    ReportTargetFilter.post => ReportTargetType.post,
    ReportTargetFilter.comment => ReportTargetType.comment,
    ReportTargetFilter.user => ReportTargetType.user,
    ReportTargetFilter.club => ReportTargetType.club,
    ReportTargetFilter.event => ReportTargetType.event,
  };
}

/// ADM-04 "Şikayetler" durumu (PLAN §12 `AdminReportsViewModel`; prototip
/// `Reports`, `screens-admin.js:61–66`).
///
/// * Şikayetler sekme başına ayrı okunur ([openReports] — `status == open`,
///   CD-37; [resolvedReports] — `status == resolved`) ve sayfalanır
///   ([cursors]); gruplama (`(targetType, targetId)` → [ReportGroup]) ve
///   hedef türü süzgeci istemcidedir ([visible]).
/// * [previews] satır başlıklarının hedef belgeleridir (grup anahtarı →
///   önizleme; okunamayan hedefin kaydı yoktur, silinmiş hedef boş önizleme
///   — [ReportTargetPreview.isMissing]).
/// * SHT-26: [openGroupKey] açık grubun anahtarı, [detailGroup] grubun açılış
///   anındaki hâli (listede yoksa — `?reportId=` — doğrudan okunur),
///   [targetPreview] sheet önizlemesi (`null` → okunuyor), [reporters]
///   şikayetçi profilleri.
/// * [pendingActions] çözüm yazımı süren gruplar (anahtar → eylem; aynı
///   grupta ikinci yazım yok sayılır, SHT-26 düğmesi `loading`).
final class AdminReportsState extends Equatable {
  /// Varsayılan: içerik yok, açık sekme, tüm hedefler.
  const AdminReportsState({
    this.tab = AdminReportsTab.open,
    this.typeFilter = ReportTargetFilter.all,
    this.openReports = const [],
    this.resolvedReports = const [],
    this.loadedTabs = const {},
    this.cursors = const {},
    this.previews = const {},
    this.reporters = const {},
    this.openGroupKey,
    this.detailGroup,
    this.targetPreview,
    this.pendingActions = const {},
    this.isFetching = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.isError = false,
  });

  /// Seçili sekme (`ADM-04.tab.<name>`).
  final AdminReportsTab tab;

  /// Hedef türü süzgeci (`ADM-04.filter.<name>`).
  final ReportTargetFilter typeFilter;

  /// Okunan açık şikayet belgeleri (en yeni üstte).
  final List<ReportModel> openReports;

  /// Okunan çözülmüş şikayet belgeleri (en yeni üstte).
  final List<ReportModel> resolvedReports;

  /// En az bir okuması başarıyla biten sekmeler.
  final Set<AdminReportsTab> loadedTabs;

  /// Sonraki sayfanın imleci (sekme başına; kaydı yoksa son sayfa).
  final Map<AdminReportsTab, PageCursor> cursors;

  /// Satır önizlemeleri (grup anahtarı → hedef).
  final Map<String, ReportTargetPreview> previews;

  /// Şikayetçi profilleri (`uid` → profil; SHT-26).
  final Map<String, UserModel> reporters;

  /// SHT-26'sı açık grubun anahtarı (`{targetType}_{targetId}`).
  final String? openGroupKey;

  /// SHT-26'daki grup (açılış anındaki hâli).
  final ReportGroup? detailGroup;

  /// SHT-26 hedef önizlemesi (yazar dahil); `null` → okunuyor.
  final ReportTargetPreview? targetPreview;

  /// Çözüm yazımı süren gruplar (anahtar → SHT-26 eylemi).
  final Map<String, ReportDetailAction> pendingActions;

  /// İlk okuma sürüyor (iskelet).
  final bool isFetching;

  /// Çek-yenile sürüyor (içerik kalır).
  final bool isRefreshing;

  /// Sonraki sayfa okunuyor.
  final bool isLoadingMore;

  /// Okuma başarısız (hata görünümü + "Yeniden dene").
  final bool isError;

  /// [tab] sekmesinin okunmuş şikayetleri.
  List<ReportModel> reportsOf(AdminReportsTab tab) => switch (tab) {
    AdminReportsTab.open => openReports,
    AdminReportsTab.resolved => resolvedReports,
  };

  /// [tab] sekmesinin grupları (en son şikayeti en yeni olan üstte).
  List<ReportGroup> groupsOf(AdminReportsTab tab) =>
      ReportGroup.groupOf(reportsOf(tab));

  /// Ekrandaki satırlar: seçili sekmenin [typeFilter] türündeki grupları.
  List<ReportGroup> get visible {
    final type = typeFilter.type;
    return [
      for (final group in groupsOf(tab))
        if (type == null || group.targetType == type) group,
    ];
  }

  /// "Açık" sekmesinin sayaç rozeti: okunan açık grup sayısı.
  int get openCount => groupsOf(AdminReportsTab.open).length;

  /// Seçili sekme en az bir kez okundu.
  bool get isLoaded => loadedTabs.contains(tab);

  /// Seçili sekmenin sonraki sayfası var.
  bool get hasMore => cursors.containsKey(tab);

  /// [key] grubu: önce açık, sonra çözülmüş şikayetlerde; ikisinde de
  /// yoksa SHT-26'daki grup ([detailGroup]); o da değilse `null`.
  ReportGroup? groupByKey(String key) {
    for (final tab in AdminReportsTab.values) {
      for (final group in groupsOf(tab)) {
        if (group.key == key) return group;
      }
    }
    final detail = detailGroup;
    return detail != null && detail.key == key ? detail : null;
  }

  @override
  List<Object?> get props => [
    tab,
    typeFilter,
    openReports,
    resolvedReports,
    loadedTabs,
    cursors,
    previews,
    reporters,
    openGroupKey,
    detailGroup,
    targetPreview,
    pendingActions,
    isFetching,
    isRefreshing,
    isLoadingMore,
    isError,
  ];

  /// Değişen alanlarla kopya; `clear*` bayrakları ilgili alanı `null` yapar.
  AdminReportsState copyWith({
    AdminReportsTab? tab,
    ReportTargetFilter? typeFilter,
    List<ReportModel>? openReports,
    List<ReportModel>? resolvedReports,
    Set<AdminReportsTab>? loadedTabs,
    Map<AdminReportsTab, PageCursor>? cursors,
    Map<String, ReportTargetPreview>? previews,
    Map<String, UserModel>? reporters,
    String? openGroupKey,
    bool clearOpenGroupKey = false,
    ReportGroup? detailGroup,
    bool clearDetailGroup = false,
    ReportTargetPreview? targetPreview,
    bool clearTargetPreview = false,
    Map<String, ReportDetailAction>? pendingActions,
    bool? isFetching,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? isError,
  }) => AdminReportsState(
    tab: tab ?? this.tab,
    typeFilter: typeFilter ?? this.typeFilter,
    openReports: openReports ?? this.openReports,
    resolvedReports: resolvedReports ?? this.resolvedReports,
    loadedTabs: loadedTabs ?? this.loadedTabs,
    cursors: cursors ?? this.cursors,
    previews: previews ?? this.previews,
    reporters: reporters ?? this.reporters,
    openGroupKey: clearOpenGroupKey ? null : openGroupKey ?? this.openGroupKey,
    detailGroup: clearDetailGroup ? null : detailGroup ?? this.detailGroup,
    targetPreview: clearTargetPreview
        ? null
        : targetPreview ?? this.targetPreview,
    pendingActions: pendingActions ?? this.pendingActions,
    isFetching: isFetching ?? this.isFetching,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isError: isError ?? this.isError,
  );
}
