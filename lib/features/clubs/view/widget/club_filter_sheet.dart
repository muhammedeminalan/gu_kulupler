import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/clubs/provider/club_filters.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_ui/gu_ui.dart';

/// "Filtre ve sıralama" sayfası — CLB-01 "Filtre / Sırala" düğmesi
/// (prototip `SHEETS['SHT-04']`, `sheets.js:19–25`).
///
/// Yukarıdan aşağıya (aralık 20): kategori çipleri (çoklu seçim) · üyelik
/// durumu (Tümü / Üye olduklarım / Üye olmadıklarım) · "Yalnızca başvurusu
/// açık" ve "Anında katılım olanlar" anahtarları · sıralama satırları
/// (Popüler / Yeni eklenen / A–Z). Altta "Temizle" + "Sonuçları göster (n)".
///
/// * Taslak [initial] kopyası üzerinde tutulur; liste, "Sonuçları göster"e
///   basılana kadar değişmez. Sayfa hiçbir şey yazmaz: sonuç `pop` değeridir
///   ([ClubFilters]); X / scrim / sürükleme / geri → `null` (değişiklik yok).
/// * "Temizle" taslağı `ClubFilters.none` yapar, sayfayı kapatmaz.
/// * Düğmedeki sayı [countFor] ile sorulur (taslağa uyan kulüp sayısı —
///   kulüp listesi ve üyelikler çağıranın ViewModel'indedir).
///
/// ```dart
/// final result = await feedback.showSheet<ClubFilters>(
///   SheetId.sht04,
///   builder: (_) => ClubFilterSheet(
///     initial: state.filters,
///     countFor: viewModel.countFor,
///   ),
/// );
/// if (result != null) viewModel.setFilters(result);
/// ```
///
/// Design: SHT-04
class ClubFilterSheet extends ConsumerStatefulWidget {
  /// [initial] süzgeciyle açılan sayfa; sonuç sayısı [countFor] ile bulunur.
  const ClubFilterSheet({
    required this.initial,
    required this.countFor,
    super.key,
  });

  /// Sayfa açılırken geçerli süzgeç (taslağın başlangıcı).
  final ClubFilters initial;

  /// Verilen süzgece uyan kulüp sayısı ("Sonuçları göster ({count})").
  final int Function(ClubFilters filters) countFor;

  @override
  ConsumerState<ClubFilterSheet> createState() => _ClubFilterSheetState();
}

class _ClubFilterSheetState extends ConsumerState<ClubFilterSheet> {
  late ClubFilters _draft = widget.initial;

  void _update(ClubFilters next) => setState(() => _draft = next);

  /// Kategori çipi: seçiliyse çıkarır, değilse ekler (`sheets.js:21`).
  void _toggleCategory(String id) {
    final ids = {..._draft.categoryIds};
    if (!ids.remove(id)) ids.add(id);
    _update(_draft.copyWith(categoryIds: ids));
  }

  static Key _sortKey(ClubSort sort) => switch (sort) {
    ClubSort.popular => GuKey.action('SHT-04.sort.popular'),
    ClubSort.newest => GuKey.action('SHT-04.sort.new'),
    ClubSort.az => GuKey.action('SHT-04.sort.az'),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final gu = context.gu;

    Widget label(String text) => Text(text, style: gu.text.fieldLabel);

    Widget toggle({
      required String text,
      required bool value,
      required Key key,
      required ValueChanged<bool> onChanged,
    }) => Row(
      spacing: GuSpacing.s8,
      children: [
        Expanded(child: Text(text, style: gu.text.bodyM)),
        GuSwitch(
          key: key,
          value: value,
          semanticLabel: text,
          onChanged: onChanged,
        ),
      ],
    );

    String sortLabel(ClubSort sort) => switch (sort) {
      ClubSort.popular => l10n.sht04SortPopular,
      ClubSort.newest => l10n.sht04SortNew,
      ClubSort.az => l10n.sht04SortAz,
    };

    return GuSheetFrame(
      title: l10n.sht04Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: GuKey.action('SHT-04.close'),
      // `.sheet-foot .btn{flex:1}` + `white-space:nowrap` (css:139, 277):
      // düğmeler satırı eşit paylaşır, ancak etiketi yarıya sığmayan düğme
      // kendi genişliğini alır ve diğeri daralır (referansta 165 / 179).
      // `IntrinsicColumnWidth(flex: 1)` aynı dağıtımı yapar; hiçbiri sığmazsa
      // sütunlar daralır ve etiketler kısalır (taşma yok).
      footer: [
        Expanded(
          child: Table(
            columnWidths: const {
              0: IntrinsicColumnWidth(flex: 1),
              1: FixedColumnWidth(GuSizes.sheetFootGap),
              2: IntrinsicColumnWidth(flex: 1),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: [
                  GuButton(
                    key: GuKey.action('SHT-04.clear'),
                    label: l10n.commonClear,
                    variant: GuButtonVariant.outline,
                    full: true,
                    onPressed: () => _update(ClubFilters.none),
                  ),
                  const SizedBox.shrink(),
                  GuButton(
                    key: GuKey.action('SHT-04.apply'),
                    label: l10n.sht04Show(widget.countFor(_draft)),
                    full: true,
                    onPressed: () => context.pop(_draft),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
      body: Padding(
        padding: GuInsets.only(bottom: GuSpacing.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: GuSpacing.s20,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: GuSpacing.s8,
              children: [
                label(l10n.sht04Category),
                Wrap(
                  spacing: GuSpacing.s8,
                  runSpacing: GuSpacing.s8,
                  children: [
                    for (final category in StaticTables.categories)
                      GuChip(
                        key: GuKey.action('SHT-04.category.${category.id}'),
                        label: StaticLabels.category(context, category.id),
                        icon: CoverMapper.icon(category.icon),
                        selected: _draft.categoryIds.contains(category.id),
                        onTap: () => _toggleCategory(category.id),
                      ),
                  ],
                ),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: GuSpacing.s8,
              children: [
                label(l10n.sht04Membership),
                GuSegmented(
                  options: [
                    GuSegmentOption(
                      id: ClubMembershipFilter.all.name,
                      label: l10n.commonAll,
                    ),
                    GuSegmentOption(
                      id: ClubMembershipFilter.mine.name,
                      label: l10n.sht04Mine,
                    ),
                    GuSegmentOption(
                      id: ClubMembershipFilter.notMine.name,
                      label: l10n.sht04NotMine,
                    ),
                  ],
                  value: _draft.membership.name,
                  optionKeyBuilder: (index) => GuKey.action(
                    'SHT-04.membership.'
                    '${ClubMembershipFilter.values[index].name}',
                  ),
                  onChanged: (id) => _update(
                    _draft.copyWith(
                      membership: ClubMembershipFilter.values.byName(id),
                    ),
                  ),
                ),
              ],
            ),
            toggle(
              text: l10n.sht04OpenOnly,
              value: _draft.applicationsOpenOnly,
              key: GuKey.action('SHT-04.toggle.openOnly'),
              onChanged: (value) =>
                  _update(_draft.copyWith(applicationsOpenOnly: value)),
            ),
            toggle(
              text: l10n.sht04InstantOnly,
              value: _draft.instantOnly,
              key: GuKey.action('SHT-04.toggle.instantOnly'),
              onChanged: (value) =>
                  _update(_draft.copyWith(instantOnly: value)),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: GuSpacing.s4,
              children: [
                label(l10n.commonSort),
                for (final sort in ClubSort.values)
                  GuOptionRow(
                    key: _sortKey(sort),
                    label: sortLabel(sort),
                    selected: _draft.sort == sort,
                    onTap: () => _update(_draft.copyWith(sort: sort)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
