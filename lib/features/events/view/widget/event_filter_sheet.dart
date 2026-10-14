import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/events/provider/event_filter_state.dart';
import 'package:gu_kulupler/features/events/provider/event_list_state.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/date_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_ui/gu_ui.dart';

/// "Etkinlik filtresi" sayfası — EVT-01 "Filtre" çipi (prototip
/// `SHEETS['SHT-11']`, `sheets.js:54–61`).
///
/// Yukarıdan aşağıya (aralık 20): tarih çipleri (Tümü / Bugün / Bu hafta /
/// Bu ay / Özel aralık — özel aralık SHT-28'i iki kez açar: başlangıç, sonra
/// `sht.11.to` başlıklı bitiş, `min` = başlangıç) · kulüp çipleri (çoklu;
/// üye olunanlar önce, `user-check` ikonlu) · tür çipleri (çoklu) ·
/// görünürlük segmenti · "Yalnızca boş kontenjan" anahtarı · sıralama
/// satırları. Altta "Temizle" + "Uygula ({count})".
///
/// * Taslak [initial] kopyası üzerinde tutulur; sonuç `pop` değeridir
///   ([EventFilterState]); X / scrim / sürükleme / geri → `null`.
/// * "Temizle" taslağı `EventFilterState.none` yapar, sayfayı kapatmaz.
/// * Düğmedeki sayı [countFor] ile sorulur (taslağa uyan etkinlik sayısı).
/// * Özel aralıkta bitiş sayfası kapatılırsa (İptal) aralık değişmez
///   (prototip `onSelect` yalnızca iki seçimden sonra yazar).
///
/// ```dart
/// final result = await feedback.showSheet<EventFilterState>(
///   SheetId.sht11,
///   builder: (_) => EventFilterSheet(
///     initial: state.filter,
///     clubs: clubs,
///     memberClubIds: memberClubIds,
///     countFor: viewModel.countFor,
///   ),
/// );
/// if (result != null) viewModel.setFilter(result);
/// ```
///
/// Design: SHT-11
class EventFilterSheet extends ConsumerStatefulWidget {
  /// [initial] süzgeciyle açılan sayfa.
  const EventFilterSheet({
    required this.initial,
    required this.clubs,
    required this.countFor,
    this.memberClubIds = const <String>{},
    super.key,
  });

  /// Sayfa açılırken geçerli süzgeç (taslağın başlangıcı).
  final EventFilterState initial;

  /// Kulüp çiplerinin kaynağı (görünür kulüpler; sayfa üye olunanları öne
  /// alır, kalan sıra korunur).
  final List<ClubModel> clubs;

  /// Kullanıcının etkin üyesi olduğu kulüpler (çip ikonu + sıra).
  final Set<String> memberClubIds;

  /// Verilen süzgece uyan etkinlik sayısı ("Uygula ({count})").
  final int Function(EventFilterState filter) countFor;

  /// Kulüp çipinin etiketi: adın ilk iki sözcüğü (`sheets.js:57`
  /// `name.split(' ').slice(0, 2)`).
  static String clubChipLabel(String name) =>
      name.split(_wordSeparator).take(_clubLabelWords).join(_wordSeparator);

  static const String _wordSeparator = ' ';
  static const int _clubLabelWords = 2;

  @override
  ConsumerState<EventFilterSheet> createState() => _EventFilterSheetState();
}

class _EventFilterSheetState extends ConsumerState<EventFilterSheet> {
  late EventFilterState _draft = widget.initial;

  void _update(EventFilterState next) => setState(() => _draft = next);

  /// Kulüp çipi: seçiliyse çıkarır, değilse ekler (`sheets.js:57`).
  void _toggleClub(String id) {
    final ids = {..._draft.clubIds};
    if (!ids.remove(id)) ids.add(id);
    _update(_draft.copyWith(clubIds: ids));
  }

  /// Tür çipi: seçiliyse çıkarır, değilse ekler (`sheets.js:58`).
  void _toggleType(EventType type) {
    final types = {..._draft.types};
    if (!types.remove(type)) types.add(type);
    _update(_draft.copyWith(types: types));
  }

  /// Tarih çipi; "Özel aralık" → SHT-28 (başlangıç) → SHT-28 (bitiş,
  /// `min` = başlangıç). İki gün de seçilirse aralık yazılır.
  Future<void> _selectDate(EventDatePreset preset) async {
    if (preset != EventDatePreset.custom) {
      _update(_draft.withDatePreset(preset));
      return;
    }
    final feedback = ref.read(feedbackServiceProvider);
    final today = EventListState.istanbulCalendarDay(
      ref.read(appClockProvider).nowUtc(),
    );
    final from = await feedback.showSheet<DateTime>(
      SheetId.sht28,
      builder: (_) => DatePickerSheet(initial: _draft.from ?? today),
    );
    if (from == null || !mounted) return;
    final title = context.l10n.sht11To;
    final to = await feedback.showSheet<DateTime>(
      SheetId.sht28,
      builder: (_) => DatePickerSheet(
        initial: _draft.to ?? from,
        firstDate: from,
        title: title,
      ),
    );
    if (to == null || !mounted) return;
    _update(_draft.withCustomRange(from: from, to: to));
  }

  static String _dateLabel(AppLocalizations l10n, EventDatePreset preset) =>
      switch (preset) {
        EventDatePreset.all => l10n.commonAll,
        EventDatePreset.today => l10n.timeToday,
        EventDatePreset.week => l10n.eventsChipWeek,
        EventDatePreset.month => l10n.sht11Month,
        EventDatePreset.custom => l10n.sht11Custom,
      };

  static String _sortLabel(AppLocalizations l10n, EventSort sort) =>
      switch (sort) {
        EventSort.date => l10n.sht11SortDate,
        EventSort.popular => l10n.sht11SortPopular,
      };

  /// Özel aralığın özeti (`dateShort(from) → dateShort(to)`, `sheets.js:56`).
  String _rangeText(AppLocalizations l10n, DateTime from, DateTime? to) {
    final formats = AppDateFormats(
      Locale(l10n.localeName),
      ref.read(appClockProvider),
    );
    String day(DateTime value) =>
        formats.dateShort(EventFilterState.istanbulDayStart(value));
    return to == null
        ? l10n.sht11RangeFrom(day(from))
        : l10n.sht11Range(day(from), day(to));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final gu = context.gu;
    final from = _draft.from;
    final clubs = [
      for (final club in widget.clubs)
        if (widget.memberClubIds.contains(club.id)) club,
      for (final club in widget.clubs)
        if (!widget.memberClubIds.contains(club.id)) club,
    ];

    Widget label(String text) => Text(text, style: gu.text.fieldLabel);

    Widget field(String title, Widget child) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s8,
      children: [label(title), child],
    );

    Widget chips(List<Widget> children) => Wrap(
      spacing: GuSpacing.s8,
      runSpacing: GuSpacing.s8,
      children: children,
    );

    return GuSheetFrame(
      title: l10n.sht11Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: GuKey.action('SHT-11.close'),
      // SHT-04 ile aynı alt çubuk: düğmeler satırı eşit paylaşır, etiketi
      // yarıya sığmayan kendi genişliğini alır (`.sheet-foot .btn{flex:1}`).
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
                    key: GuKey.action('SHT-11.clear'),
                    label: l10n.commonClear,
                    variant: GuButtonVariant.outline,
                    full: true,
                    onPressed: () => _update(EventFilterState.none),
                  ),
                  const SizedBox.shrink(),
                  GuButton(
                    key: GuKey.action('SHT-11.apply'),
                    label: l10n.sht11Apply(widget.countFor(_draft)),
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
                label(l10n.sht11Date),
                chips([
                  for (final preset in EventDatePreset.values)
                    GuChip(
                      key: GuKey.action('SHT-11.date.${preset.name}'),
                      label: _dateLabel(l10n, preset),
                      selected: _draft.datePreset == preset,
                      onTap: () => _selectDate(preset),
                    ),
                ]),
                if (_draft.datePreset == EventDatePreset.custom && from != null)
                  Text(
                    _rangeText(l10n, from, _draft.to),
                    style: gu.text.caption,
                  ),
              ],
            ),
            field(
              l10n.sht11Club,
              chips([
                for (final club in clubs)
                  GuChip(
                    key: GuKey.action('SHT-11.club.${club.id}'),
                    label: EventFilterSheet.clubChipLabel(club.name),
                    icon: widget.memberClubIds.contains(club.id)
                        ? GuIcons.userCheck
                        : null,
                    selected: _draft.clubIds.contains(club.id),
                    onTap: () => _toggleClub(club.id),
                  ),
              ]),
            ),
            field(
              l10n.eventFormType,
              chips([
                for (final type in EventType.values)
                  GuChip(
                    key: GuKey.action('SHT-11.type.${type.json}'),
                    label: StaticLabels.eventType(context, type),
                    selected: _draft.types.contains(type),
                    onTap: () => _toggleType(type),
                  ),
              ]),
            ),
            field(
              l10n.eventFormVisibility,
              GuSegmented(
                options: [
                  GuSegmentOption(
                    id: EventVisibilityFilter.all.name,
                    label: l10n.commonAll,
                  ),
                  GuSegmentOption(
                    id: EventVisibilityFilter.public.name,
                    label: l10n.eventVisibilityPublic,
                  ),
                  GuSegmentOption(
                    id: EventVisibilityFilter.members.name,
                    label: l10n.eventVisibilityMembers,
                  ),
                ],
                value: _draft.visibility.name,
                optionKeyBuilder: (index) => GuKey.action(
                  'SHT-11.visibility.'
                  '${EventVisibilityFilter.values[index].name}',
                ),
                onChanged: (id) => _update(
                  _draft.copyWith(
                    visibility: EventVisibilityFilter.values.byName(id),
                  ),
                ),
              ),
            ),
            Row(
              spacing: GuSpacing.s8,
              children: [
                Expanded(child: Text(l10n.sht11FreeOnly, style: gu.text.bodyM)),
                GuSwitch(
                  key: GuKey.action('SHT-11.toggle.freeOnly'),
                  value: _draft.freeOnly,
                  semanticLabel: l10n.sht11FreeOnly,
                  onChanged: (value) =>
                      _update(_draft.copyWith(freeOnly: value)),
                ),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: GuSpacing.s4,
              children: [
                label(l10n.commonSort),
                for (final sort in EventSort.values)
                  GuOptionRow(
                    key: GuKey.action('SHT-11.sort.${sort.name}'),
                    label: _sortLabel(l10n, sort),
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
