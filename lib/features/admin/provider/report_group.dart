import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';

/// ADM-04 / SHT-26 / ADM-01 — aynı hedefin `(targetType, targetId)`
/// şikayetleri tek grup (PLAN §9.6.12: gruplama istemcide; model değil,
/// değer nesnesi — CD-33, CD-37).
///
/// [reports] en yeni üstte sıralıdır (`createdAt` azalan; zamanı olmayan
/// sonda, eşitlikte girdi sırası korunur). Türetilen alanlar (neden
/// dağılımı, ilk / son zaman, durum, çözüm) [reports]'tan hesaplanır.
final class ReportGroup extends Equatable {
  /// [targetType] / [targetId] hedefinin [reports] grubu.
  const ReportGroup({
    required this.targetType,
    required this.targetId,
    required this.reports,
  });

  /// Şikayetleri hedef başına gruplar (saf; girdi değişmez).
  ///
  /// * Anahtar `{targetType}_{targetId}` ([key]); silinmiş (`isDeleted`)
  ///   şikayet atlanır.
  /// * Gruplar en son şikayeti en yeni olan üstte ([lastAt] azalan; zamanı
  ///   olmayan sonda, eşitlikte ilk görünme sırası).
  /// * Grup içi [reports] `createdAt` azalan (eşitlikte girdi sırası).
  static List<ReportGroup> groupOf(List<ReportModel> reports) {
    final buckets = <String, List<ReportModel>>{};
    for (final report in reports) {
      if (report.isDeleted) continue;
      buckets
          .putIfAbsent(
            FirestoreIds.reportGroupKey(
              report.targetType.json,
              report.targetId,
            ),
            () => <ReportModel>[],
          )
          .add(report);
    }
    final groups = [
      for (final bucket in buckets.values)
        ReportGroup(
          targetType: bucket.first.targetType,
          targetId: bucket.first.targetId,
          reports: List<ReportModel>.unmodifiable(
            _newestFirst<ReportModel>(
              bucket,
              (report) => report.createdAt,
            ),
          ),
        ),
    ];
    return List<ReportGroup>.unmodifiable(
      _newestFirst<ReportGroup>(groups, (group) => group.lastAt),
    );
  }

  /// [items]'ı [timeOf] azalan sıralar (kararlı; `null` zaman sonda).
  static List<T> _newestFirst<T>(List<T> items, DateTime? Function(T) timeOf) {
    final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])]
      ..sort((a, b) {
        final ta = timeOf(a.$2);
        final tb = timeOf(b.$2);
        if (ta != null && tb != null && ta != tb) return tb.compareTo(ta);
        if (ta == null && tb != null) return 1;
        if (ta != null && tb == null) return -1;
        return a.$1.compareTo(b.$1);
      });
    return [for (final (_, item) in indexed) item];
  }

  /// Şikayet edilen şeyin türü.
  final ReportTargetType targetType;

  /// Şikayet edilen belgenin kimliği.
  final String targetId;

  /// Grubun şikayetleri (boş değil; en yeni üstte).
  final List<ReportModel> reports;

  /// Grup anahtarı `{targetType}_{targetId}`
  /// (`FirestoreIds.reportGroupKey`; `?reportId=` ve `report_resolved`
  /// `refs.reportId` değeri, satır anahtarı `ADM-04.row.<key>`).
  String get key => FirestoreIds.reportGroupKey(targetType.json, targetId);

  /// Hedefin kulübü (kullanıcı hedefinde `null`).
  String? get targetClubId => reports
      .map((report) => report.targetClubId)
      .firstWhere((id) => id != null, orElse: () => null);

  /// Şikayet sayısı.
  int get count => reports.length;

  /// Tüm şikayet belge kimlikleri.
  List<String> get reportIds => [for (final report in reports) report.id];

  /// Açık şikayet belge kimlikleri (`AdminRepository.resolveReports`).
  List<String> get openReportIds => [
    for (final report in reports)
      if (report.status == ReportStatus.open) report.id,
  ];

  /// Şikayet edenler (tekil, en yeni şikayet önce).
  List<String> get reporterIds => [
    ...{for (final report in reports) report.reporterId},
  ];

  /// Neden dağılımı: neden → sayı (çoktan aza; eşitlikte enum sırası).
  Map<ReportReason, int> get reasonCounts {
    final counts = <ReportReason, int>{};
    for (final report in reports) {
      counts[report.reason] = (counts[report.reason] ?? 0) + 1;
    }
    final ordered = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.index.compareTo(b.key.index);
      });
    return {for (final entry in ordered) entry.key: entry.value};
  }

  /// Satır rozetindeki neden: grubun ilk (en eski) şikayetinin nedeni
  /// (prototip `r.reasons[0]`).
  ReportReason get primaryReason => reports.last.reason;

  /// İlk şikayet anı (zamanı olmayan atlanır; hiçbiri yoksa `null`).
  DateTime? get firstAt => _bound(latest: false);

  /// Son şikayet anı (satırdaki göreli zaman; hiçbiri yoksa `null`).
  DateTime? get lastAt => _bound(latest: true);

  DateTime? _bound({required bool latest}) {
    DateTime? result;
    for (final report in reports) {
      final at = report.createdAt;
      if (at == null) continue;
      if (result == null ||
          (latest ? at.isAfter(result) : at.isBefore(result))) {
        result = at;
      }
    }
    return result;
  }

  /// Grup durumu: açık şikayeti varsa `open`, yoksa `resolved`.
  ReportStatus get status => reports.any((r) => r.status == ReportStatus.open)
      ? ReportStatus.open
      : ReportStatus.resolved;

  /// Açık mı ([status] `open`).
  bool get isOpen => status == ReportStatus.open;

  /// En son çözülen şikayetin işlemi (açık grupta ya da bilinmeyende
  /// `null`).
  ReportAction? get action => _latestResolved?.action;

  /// En son çözüm anı (çözülmemişse `null`).
  DateTime? get resolvedAt => _latestResolved?.resolvedAt;

  ReportModel? get _latestResolved {
    ReportModel? result;
    for (final report in reports) {
      if (report.status != ReportStatus.resolved) continue;
      final at = report.resolvedAt;
      final best = result?.resolvedAt;
      if (result == null ||
          (at != null && (best == null || at.isAfter(best)))) {
        result = report;
      }
    }
    return result;
  }

  @override
  List<Object?> get props => [targetType, targetId, reports];
}
