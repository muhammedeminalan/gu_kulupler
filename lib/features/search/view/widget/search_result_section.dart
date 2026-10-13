import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/search/provider/search_scope.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_ui/gu_ui.dart';

/// CLB-02 arama sonuçları — prototip `screens-clubs.js:52–53, 56`: seçili
/// sekmenin ([scope]) sonuç satırları ya da "sonuç yok" bloğu.
///
/// * Kulüp satırı: amblem (44) · ad (eşleşen kısım kalın) · "kategori · N
///   üye" · `chevron-right`.
/// * Etkinlik satırı: tarih rozeti · başlık (eşleşen kısım kalın) · "kulüp ·
///   saat" · `chevron-right`.
/// * Sonuç yok: ham `.empty` gövdesi (dolgu 32 / 24, aralık 12, ortalı) —
///   `empty-clubs` illüstrasyonu 100 dp · "'{q}' için sonuç yok" (`titleS`)
///   · ilk dört popüler arama çipi (ikonsuz).
///
/// Anahtarlar çağırandan gelir (D-18): [clubKeyOf] `CLB-02.result.club.<id>`,
/// [eventKeyOf] `CLB-02.result.event.<id>`, [suggestKeyOf]
/// `CLB-02.suggest.<i>`.
class SearchResultSection extends StatelessWidget {
  /// [term] aramasının [scope] sekmesindeki sonuçları.
  const SearchResultSection({
    required this.scope,
    required this.term,
    required this.clubs,
    required this.events,
    required this.popular,
    required this.formats,
    required this.clubNameOf,
    required this.onClub,
    required this.onEvent,
    required this.onSuggest,
    required this.clubKeyOf,
    required this.eventKeyOf,
    required this.suggestKeyOf,
    super.key,
  });

  /// Seçili sonuç sekmesi.
  final SearchScope scope;

  /// Aranan terim (kırpılmış).
  final String term;

  /// Eşleşen kulüpler.
  final List<ClubModel> clubs;

  /// Eşleşen etkinlikler.
  final List<EventModel> events;

  /// Popüler aramalar; "sonuç yok" bloğunda ilk [suggestionCount] tanesi
  /// önerilir.
  final List<String> popular;

  /// Tarih / saat biçimleri (etkinlik satırı).
  final AppDateFormats formats;

  /// Etkinliğin kulübünün adı; kulüp bilinmiyorsa `null`.
  final String? Function(String clubId) clubNameOf;

  /// Kulüp satırına dokunma.
  final ValueChanged<ClubModel> onClub;

  /// Etkinlik satırına dokunma.
  final ValueChanged<EventModel> onEvent;

  /// "Sonuç yok" çipine dokunma: terim arama alanına yazılır.
  final ValueChanged<String> onSuggest;

  /// Kulüp satırının anahtarı.
  final Key Function(String clubId) clubKeyOf;

  /// Etkinlik satırının anahtarı.
  final Key Function(String eventId) eventKeyOf;

  /// Verilen sıradaki öneri çipinin anahtarı.
  final Key Function(int index) suggestKeyOf;

  /// "Sonuç yok" bloğundaki öneri sayısı (`screens-clubs.js:56`
  /// `slice(0, 4)`).
  static const int suggestionCount = 4;

  /// `screens-clubs.js:56` `Illustration size=100` —
  /// `GuSizes.illustrationSizes` (56 · 72 · 80 · 96 · 100 · 140 · 160 · 200)
  /// içindeki CLB-02 değeri.
  static final double illustrationSize = GuSizes.illustrationSizes[4];

  /// İkon adı kayıtta olmayan kulübün amblemi (kulüp kartıyla aynı).
  static const GuIcons _fallbackIcon = GuIcons.users;

  /// Alt satır ayracı (`screens-clubs.js:52–53` `' · '`).
  static const String _separator = ' · ';

  /// [text] içinde [term] ile eşleşen ilk kısım [emphasis] stiliyle
  /// (prototip `Highlight`, `screens-clubs.js:36`); eşleşme Türkçe harf
  /// duyarsızdır (`trLower`). Eşleşme yoksa metin düz kalır.
  static TextSpan highlight(String text, String term, TextStyle emphasis) {
    final haystack = text.trLower();
    final needle = term.trLower();
    final start = needle.isEmpty || haystack.length != text.length
        ? -1
        : haystack.indexOf(needle);
    if (start < 0) return TextSpan(text: text);
    final end = start + needle.length;
    return TextSpan(
      children: [
        if (start > 0) TextSpan(text: text.substring(0, start)),
        TextSpan(text: text.substring(start, end), style: emphasis),
        if (end < text.length) TextSpan(text: text.substring(end)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = switch (scope) {
      SearchScope.clubs => [for (final club in clubs) _clubRow(context, club)],
      SearchScope.events => [
        for (final event in events) _eventRow(context, event),
      ],
    };
    if (rows.isEmpty) return _noResults(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  /// `<b>`: satır başlığı (`bodyM`, `text.heading`) + en kalın başlık
  /// ağırlığı (700).
  TextStyle _emphasis(BuildContext context) {
    final gu = context.gu;
    return gu.text.bodyM.copyWith(
      color: gu.colors.textHeading,
      fontWeight: gu.text.titleL.fontWeight,
    );
  }

  Widget _clubRow(BuildContext context, ClubModel club) {
    final l10n = context.l10n;
    return GuTile(
      key: clubKeyOf(club.id),
      leading: GuEmblem(
        icon: CoverMapper.icon(club.iconName) ?? _fallbackIcon,
      ),
      title: club.name,
      titleSpan: highlight(club.name, term, _emphasis(context)),
      subtitle: [
        StaticLabels.category(context, club.categoryId),
        l10n.clubsCardMembers(club.memberCount),
      ].join(_separator),
      chevron: true,
      onTap: () => onClub(club),
    );
  }

  Widget _eventRow(BuildContext context, EventModel event) {
    final locale = Localizations.localeOf(context);
    final clubName = clubNameOf(event.clubId);
    return GuTile(
      key: eventKeyOf(event.id),
      leading: GuDateBadge(
        day: AppDateFormats.toIstanbul(event.startsAt).day,
        monthShort: formats.monthShort(event.startsAt).upperFor(locale),
        semanticLabel: formats.date(event.startsAt),
      ),
      title: event.title,
      titleSpan: highlight(event.title, term, _emphasis(context)),
      subtitle: [
        ?clubName,
        formats.time(event.startsAt),
      ].join(_separator),
      chevron: true,
      onTap: () => onEvent(event),
    );
  }

  Widget _noResults(BuildContext context) {
    final gu = context.gu;
    return Padding(
      padding: GuInsets.sym(
        h: GuSizes.emptyPaddingX,
        v: GuSizes.emptyPaddingY,
      ),
      child: Column(
        spacing: GuSizes.emptyGap,
        children: [
          GuIllustration(GuIllustrations.emptyClubs, size: illustrationSize),
          Semantics(
            header: true,
            liveRegion: true,
            child: Text(
              context.l10n.searchNoResults(term),
              style: gu.text.titleS,
              textAlign: TextAlign.center,
            ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: GuSpacing.s8,
            runSpacing: GuSpacing.s8,
            children: [
              for (final (index, suggestion)
                  in popular.take(suggestionCount).indexed)
                GuChip(
                  key: suggestKeyOf(index),
                  label: suggestion,
                  onTap: () => onSuggest(suggestion),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
