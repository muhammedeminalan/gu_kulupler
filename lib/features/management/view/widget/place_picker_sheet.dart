import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-30 "Mekân seç" sonucu — sayfanın `pop` değeri: tablodaki mekân
/// ([placeId], `StaticTables.places`) **ya da** serbest metin ([placeText]);
/// ikisinden yalnızca biri doludur. X / scrim / geri → `null`.
final class PlacePickerResult extends Equatable {
  /// Tablodan seçilen mekân (`SHT-30.select.<placeId>`).
  const PlacePickerResult.place(String this.placeId) : placeText = null;

  /// Serbest metin mekân (`SHT-30.okCustom`; kırpılmış, boş değil).
  const PlacePickerResult.custom(String this.placeText) : placeId = null;

  /// Mekân tablosu kimliği; serbest metinde `null`.
  final String? placeId;

  /// Serbest metin; tablodan seçimde `null`.
  final String? placeText;

  @override
  List<Object?> get props => [placeId, placeText];
}

/// SHT-30 "Mekân seç" — arama + sabit mekân listesi (`StaticTables.places`,
/// harita yok — K-16) + "Başka bir yer yaz" serbest metni (prototip
/// `SHEETS['SHT-30']`, `sheets.js:141–143`). Yalnızca MGT-05 açar.
///
/// Sayfa [PlacePickerResult] döner (`pop`). Anahtarlar `SHT-30.search`,
/// `SHT-30.select.<placeId>`, `SHT-30.customToggle`, `SHT-30.custom`,
/// `SHT-30.okCustom`, `SHT-30.close`.
///
/// Design: SHT-30
class PlacePickerSheet extends ConsumerStatefulWidget {
  /// Seçili mekân [placeId] ya da serbest metin [placeText] ile açılır
  /// (serbest metin varsa metin alanı açık gelir).
  const PlacePickerSheet({this.placeId, this.placeText, super.key});

  /// Şu an seçili mekân (onay işareti); yoksa `null`.
  final String? placeId;

  /// Şu anki serbest metin; yoksa `null`.
  final String? placeText;

  /// SHT-30 [action] anahtarı (`SHT-30.<aksiyon>`).
  static Key keyOf(String action) =>
      FeedbackKeys.of(SheetId.sht30.designId, action);

  /// [placeId] satırının anahtarı (`SHT-30.select.<placeId>`).
  static Key selectKeyOf(String placeId) => keyOf('select.$placeId');

  @override
  ConsumerState<PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends ConsumerState<PlacePickerSheet> {
  String _query = '';
  late final TextEditingController _text;

  /// Serbest metin alanı açık mı (prototip `custom`; metin varsa açık gelir).
  late bool _custom;

  @override
  void initState() {
    super.initState();
    final text = widget.placeText ?? '';
    _text = TextEditingController(text: text);
    _custom = text.isNotEmpty;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Karşılaştırma biçimi: Türkçede `toLocaleLowerCase('tr')`, diğer dillerde
  /// yerelden bağımsız küçük harf.
  String _fold(String text, Locale locale) =>
      locale.languageCode == 'tr' ? text.trLower() : text.toLowerCase();

  /// Aramaya (o anki dildeki adda) uyan mekânlar, tablo sırasıyla.
  List<String> _places(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final needle = _fold(_query.trim(), locale);
    return [
      for (final place in StaticTables.places)
        if (needle.isEmpty ||
            _fold(
              StaticLabels.place(context, place.id),
              locale,
            ).contains(needle))
          place.id,
    ];
  }

  void _okCustom() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    context.pop<PlacePickerResult>(PlacePickerResult.custom(text));
  }

  static void _ignoreDisabled() {}

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final canSubmit = _text.text.trim().isNotEmpty;
    return GuSheetFrame(
      title: l10n.sht30Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: PlacePickerSheet.keyOf('close'),
      full: true,
      flush: true,
      footer: _custom
          ? [
              GuButton(
                key: PlacePickerSheet.keyOf('okCustom'),
                label: l10n.commonOk,
                disabled: !canSubmit,
                onPressed: _okCustom,
                onDisabledPressed: _ignoreDisabled,
              ),
            ]
          : null,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // `px16 pb8`: `pb8` CSS'te tanımsız (K-42) → alt dolgu yok.
          Padding(
            padding: GuInsets.sym(h: GuSpacing.s16),
            child: GuSearchField(
              value: _query,
              onChanged: (value) => setState(() => _query = value),
              placeholder: l10n.commonSearch,
              semanticLabel: l10n.commonSearch,
              actionKey: PlacePickerSheet.keyOf('search'),
            ),
          ),
          for (final id in _places(context))
            GuOptionRow(
              key: PlacePickerSheet.selectKeyOf(id),
              label: StaticLabels.place(context, id),
              selected: id == widget.placeId,
              leading: GuIcon(
                GuIcons.mapPin,
                size: GuSizes.icon18,
                color: gu.colors.textMuted,
              ),
              onTap: () =>
                  context.pop<PlacePickerResult>(PlacePickerResult.place(id)),
            ),
          const GuDivider(),
          if (_custom)
            Padding(
              padding: GuInsets.only(
                left: GuSpacing.s16,
                right: GuSpacing.s16,
                top: GuSpacing.s16,
              ),
              child: GuInput(
                controller: _text,
                label: l10n.sht30CustomLabel,
                maxLength: Limits.placeTextMax,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                onSubmitted: _okCustom,
                actionKey: PlacePickerSheet.keyOf('custom'),
              ),
            )
          else
            GuTile(
              key: PlacePickerSheet.keyOf('customToggle'),
              title: l10n.sht30Custom,
              leading: GuIcon(
                GuIcons.pencil,
                size: GuSizes.icon22,
                color: gu.colors.textHeading,
              ),
              onTap: () => setState(() => _custom = true),
            ),
        ],
      ),
    );
  }
}
