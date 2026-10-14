import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/management/provider/event_form_state.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_kulupler/product/media/post_image_resolver.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_kulupler/product/widget/event/event_card.dart';
import 'package:gu_kulupler/product/widget/event/event_card_status.dart';
import 'package:gu_kulupler/product/widget/event/event_cta.dart';
import 'package:gu_kulupler/product/widget/form/form_error_line.dart';
import 'package:gu_ui/gu_ui.dart';

/// MGT-05 formunun gövdesi — o anki adımın alanları (prototip
/// `screens-manage.js:104–115`). Değerleri ve hata haritasını çağıran
/// (`EventFormView`, `EventFormViewModel` durumu) verir; her değişiklik geri
/// çağrıyla döner — form durum tutmaz (yalnızca metin denetleyicileri ve
/// "Sınırsız" kapatılınca geri gelecek son kontenjan).
///
/// Dönen sütun `col gap16`'dır; kaydırma ve dış dolgu (`px16 pt8 pb24`)
/// çağırandadır.
///
/// * **[EventFormStep.basics]:** kapak (`MGT-05.cover` → SHT-31; 16:9, radius
///   16, sağ altta "Kapağı değiştir" `sm outline` — K-52) · ad
///   (`MGT-05.title`, ≤ `Limits.eventTitleMax`, sayaç) · açıklama
///   (`MGT-05.desc`, 5 satır, ≤ `Limits.eventDescMax`, sayaç) · tür çipleri
///   (`MGT-05.type.<json>`).
/// * **[EventFormStep.schedule]:** başlangıç / bitiş tarih (SHT-28) ve saat
///   (SHT-29) seçicileri (`MGT-05.startDate` / `.startTime` / `.endDate` /
///   `.endTime`; [timeLocked] iken devre dışı + kilit açıklaması — W-82) ·
///   [conflictCount] > 0 ise bilgi bandı · mekân (`MGT-05.place` → SHT-30) ·
///   kontenjan (`MGT-05.unlimited` anahtarı; sınırlıyken `GuStepper`
///   `MGT-05.capacity.minus` / `.plus`, adım [capacityStep], alt sınır
///   [minCapacity], üst sınır [capacityMax]; altında hata ya da düzenlemede
///   "Şu an N kayıtlı") · görünürlük (`MGT-05.visibility.public` /
///   `.members` + açıklama) · otomatik hatırlatıcı (`MGT-05.autoReminder`).
/// * **[EventFormStep.settings]:** "üyelere böyle görünecek" bandı ·
///   önizleme `EventCard` (yayında, kulüp satırı yok; etkileşimsiz) · özet
///   kartı (ad, tür, başlangıç, bitiş, yer, kontenjan, görünürlük).
///
/// Hata metinleri ([errors] → ARB): `required` → `auth.err.required`;
/// başlangıçta diğer her hata → `eventForm.err.future`; bitişte →
/// `eventForm.err.endAfter`; kontenjanda → `eventForm.err.capacity`
/// (`registeredCount ?? minCapacity`).
///
/// MGT-05'e özgüdür (tek çağıran); anahtarlar `MGT-05.*`.
class EventForm extends ConsumerStatefulWidget {
  /// [step] adımının alanları.
  const EventForm({
    required this.step,
    required this.title,
    required this.desc,
    required this.type,
    required this.startsAt,
    required this.endsAt,
    required this.placeId,
    required this.placeText,
    required this.capacity,
    required this.visibility,
    required this.autoReminder,
    required this.coverPalette,
    required this.coverPattern,
    required this.errors,
    required this.onTitleChanged,
    required this.onDescChanged,
    required this.onTypeChanged,
    required this.onCoverTap,
    required this.onStartDateTap,
    required this.onStartTimeTap,
    required this.onEndDateTap,
    required this.onEndTimeTap,
    required this.onPlaceTap,
    required this.onCapacityChanged,
    required this.onVisibilityChanged,
    required this.onAutoReminderChanged,
    this.coverSeed,
    this.coverPath,
    this.coverImage,
    this.isCoverUploading = false,
    this.timeLocked = false,
    this.minCapacity = 1,
    this.club,
    this.registeredCount,
    this.conflictCount = 0,
    super.key,
  });

  /// Kontenjan adımı (`screens-manage.js:112` `f.capacity ∓ 5`).
  static const int capacityStep = 5;

  /// Kontenjan üst sınırı (`screens-manage.js:112` `Math.min(1000, …)`).
  static const int capacityMax = 1000;

  /// "Sınırsız" kapatıldığında, daha önce sınırlı bir değer yoksa gelen
  /// kontenjan (prototip yeni etkinlik `capacity: 40`, `screens-manage.js:89`).
  static const int capacityDefault = 40;

  /// Gösterilen adım.
  final EventFormStep step;

  /// Etkinlik adı (≤ `Limits.eventTitleMax`; sınırda ViewModel keser).
  final String title;

  /// Açıklama (≤ `Limits.eventDescMax`).
  final String desc;

  /// Seçili tür; yoksa `null`.
  final EventType? type;

  /// Başlangıç (UTC); seçilmemişse `null`.
  final DateTime? startsAt;

  /// Bitiş (UTC); seçilmemişse `null`.
  final DateTime? endsAt;

  /// Mekân tablosu kimliği (SHT-30); serbest metinde `null`.
  final String? placeId;

  /// Serbest metin mekân; tablodan seçimde boş.
  final String placeText;

  /// Kontenjan; `null` = sınırsız.
  final int? capacity;

  /// Görünürlük.
  final EventVisibility visibility;

  /// Otomatik hatırlatıcı açık mı.
  final bool autoReminder;

  /// Şablon kapak paleti.
  final ClubPalette coverPalette;

  /// Şablon kapak deseni.
  final ClubPattern coverPattern;

  /// Şablon desen tohumu; yeni etkinlikte kimlik yokken `null`. Flutter
  /// şablon kapakları (`GuCovers`) tohumdan bağımsız çizilir.
  final String? coverSeed;

  /// Yüklenmiş özel kapağın Storage yolu (CD-47); yoksa şablon çizilir.
  final String? coverPath;

  /// Seçilmiş ama henüz yüklenmemiş özel kapak (yerel görsel); verilirse
  /// [coverPath]'in yerine çizilir (kapak ve 3. adım önizlemesi).
  final ImageProvider? coverImage;

  /// Özel kapak yükleniyor mu (önizleme üstünde gösterge).
  final bool isCoverUploading;

  /// Başlangıç / bitiş kilitli mi: yayındaki etkinlik başlamış (W-82,
  /// domain-model §2.7).
  final bool timeLocked;

  /// Kontenjanın alt sınırı: yeni etkinlikte 1, düzenlemede
  /// `max(1, goingCount)` (`capacityBelowGoing`).
  final int minCapacity;

  /// Düzenleyen kulüp: kapak şablonundaki ikon (`club.iconName`) ve 3. adım
  /// önizleme kartı; `null` → takvim ikonu.
  final ClubModel? club;

  /// Düzenlemede mevcut kayıtlı sayısı (`goingCount`): kontenjanın altında
  /// "Şu an N kayıtlı"; yeni etkinlikte `null`.
  final int? registeredCount;

  /// Aynı zaman aralığıyla çakışan yayındaki kulüp etkinliği sayısı
  /// (`screens-manage.js:92` `conflicts`); 0 → bant yok.
  final int conflictCount;

  /// Alan hataları (`EventFormState.errors`); metne çeviri formdadır.
  final Map<EventField, FormFieldError> errors;

  /// Ad değişti (`MGT-05.title`).
  final ValueChanged<String> onTitleChanged;

  /// Açıklama değişti (`MGT-05.desc`).
  final ValueChanged<String> onDescChanged;

  /// Tür çipi seçildi (`MGT-05.type.<json>`).
  final ValueChanged<EventType> onTypeChanged;

  /// Kapak önizlemesine dokunuş (`MGT-05.cover`) → SHT-31.
  final VoidCallback onCoverTap;

  /// Başlangıç tarihi (`MGT-05.startDate`) → SHT-28.
  final VoidCallback onStartDateTap;

  /// Başlangıç saati (`MGT-05.startTime`) → SHT-29.
  final VoidCallback onStartTimeTap;

  /// Bitiş tarihi (`MGT-05.endDate`) → SHT-28.
  final VoidCallback onEndDateTap;

  /// Bitiş saati (`MGT-05.endTime`) → SHT-29.
  final VoidCallback onEndTimeTap;

  /// Mekân (`MGT-05.place`) → SHT-30.
  final VoidCallback onPlaceTap;

  /// Kontenjan değişti (`MGT-05.capacity.minus` / `.plus` /
  /// `MGT-05.unlimited`); `null` = sınırsız.
  final ValueChanged<int?> onCapacityChanged;

  /// Görünürlük değişti (`MGT-05.visibility`).
  final ValueChanged<EventVisibility> onVisibilityChanged;

  /// Otomatik hatırlatıcı değişti (`MGT-05.autoReminder`).
  final ValueChanged<bool> onAutoReminderChanged;

  @override
  ConsumerState<EventForm> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<EventForm> {
  /// Saat seçicisinin genişliği.
  // ignore-hardcode: eksik token — screens-manage.js:107–108 `width:120px`
  static const double _timeFieldWidth = 120;

  /// Açıklama satır sayısı (`screens-manage.js:106` `rows=5`).
  static const int _descRows = 5;

  /// Özet kartında değerin satırda kaplayabileceği en büyük pay
  /// (`screens-manage.js:115` `max-width:60%`).
  static const double _summaryValueShare = 0.6;

  static final List<Key> _visibilityKeys = [
    GuKey.action('MGT-05.visibility.public'),
    GuKey.action('MGT-05.visibility.members'),
  ];

  late final TextEditingController _title;
  late final TextEditingController _desc;

  /// "Sınırsız" kapatılınca dönülecek kontenjan (son sınırlı değer).
  late int _lastCapacity;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.title);
    _desc = TextEditingController(text: widget.desc);
    _lastCapacity = widget.capacity ?? EventForm.capacityDefault;
  }

  @override
  void didUpdateWidget(EventForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Değerler ViewModel'den de değişir (sınırda kesme, taslak geri yükleme).
    _show(_title, widget.title);
    _show(_desc, widget.desc);
    final capacity = widget.capacity;
    if (capacity != null) _lastCapacity = capacity;
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  /// [controller] alanındaki metni [value] yapar (imleç sonda).
  static void _show(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  AppDateFormats get _formats => AppDateFormats(
    Localizations.localeOf(context),
    ref.watch(appClockProvider),
  );

  GuIcons get _coverIcon {
    final club = widget.club;
    return (club == null ? null : CoverMapper.icon(club.iconName)) ??
        EventCard.fallbackIcon;
  }

  String get _placeLabel {
    final placeId = widget.placeId;
    if (placeId != null) return StaticLabels.place(context, placeId);
    return widget.placeText;
  }

  // ── Hata metinleri ────────────────────────────────────────────────

  String? _errorText(EventField field, AppLocalizations l10n) {
    final error = widget.errors[field];
    if (error == null) return null;
    if (error == FormFieldError.required) return l10n.authErrRequired;
    return switch (field) {
      EventField.startsAt => l10n.eventFormErrFuture,
      EventField.endsAt => l10n.eventFormErrEndAfter,
      EventField.capacity => l10n.eventFormErrCapacity(
        widget.registeredCount ?? widget.minCapacity,
      ),
      EventField.title ||
      EventField.desc ||
      EventField.type ||
      EventField.place => l10n.authErrRequired,
    };
  }

  // ── 1 · Temel ─────────────────────────────────────────────────────

  Widget _cover() {
    final l10n = context.l10n;
    final image = _coverImage;
    final overlays = <Widget>[
      if (widget.isCoverUploading) const Center(child: GuSpinner()),
      Positioned(
        right: GuSpacing.s12,
        bottom: GuSpacing.s12,
        // Görsel etiket; dokunma ve semantik kapağın kendisinde (K-52).
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: GuButton(
              label: l10n.eventFormChangeCover,
              size: GuButtonSize.sm,
              variant: GuButtonVariant.outline,
              icon: GuIcons.image,
              onPressed: _noop,
            ),
          ),
        ),
      ),
    ];
    return GuActionSurface(
      key: GuKey.action('MGT-05.cover'),
      borderRadius: GuRadius.borderMd,
      semanticLabel: l10n.eventFormCover,
      onTap: widget.onCoverTap,
      builder: (context, pressed) => image != null
          ? GuCover.image(
              image: image,
              borderRadius: GuRadius.borderMd,
              overlays: overlays,
            )
          : GuCover.template(
              palette: CoverMapper.palette(widget.coverPalette),
              pattern: CoverMapper.pattern(widget.coverPattern),
              icon: _coverIcon,
              borderRadius: GuRadius.borderMd,
              overlays: overlays,
            ),
    );
  }

  static void _noop() {}

  /// Yerel (yüklenmemiş) kapak önce; yoksa Storage'daki kapak.
  ImageProvider? get _coverImage =>
      widget.coverImage ??
      ref.watch(storageImageResolverProvider)(widget.coverPath);

  Widget _typeField(AppLocalizations l10n) {
    final gu = context.gu;
    final error = _errorText(EventField.type, l10n);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s8,
      children: [
        Text(l10n.eventFormType, style: gu.text.fieldLabel),
        Wrap(
          spacing: GuSpacing.s8,
          runSpacing: GuSpacing.s8,
          children: [
            for (final type in StaticTables.eventTypes)
              GuChip(
                key: GuKey.action('MGT-05.type.${type.json}'),
                label: StaticLabels.eventType(context, type),
                selected: widget.type == type,
                onTap: () => widget.onTypeChanged(type),
              ),
          ],
        ),
        if (error != null) FormErrorLine(error),
      ],
    );
  }

  List<Widget> _basics(AppLocalizations l10n) => [
    _cover(),
    GuInput(
      controller: _title,
      label: l10n.eventFormName,
      maxLength: Limits.eventTitleMax,
      showCounter: true,
      autofocus: widget.title.isEmpty,
      errorText: _errorText(EventField.title, l10n),
      onChanged: widget.onTitleChanged,
      actionKey: GuKey.action('MGT-05.title'),
    ),
    GuInput(
      controller: _desc,
      label: l10n.eventFormDesc,
      multiline: true,
      rows: _descRows,
      maxLength: Limits.eventDescMax,
      showCounter: true,
      errorText: _errorText(EventField.desc, l10n),
      onChanged: widget.onDescChanged,
      actionKey: GuKey.action('MGT-05.desc'),
    ),
    _typeField(l10n),
  ];

  // ── 2 · Zaman ve ayrıntılar ───────────────────────────────────────

  Widget _dateTimeRow({
    required String dateLabel,
    required DateTime? value,
    required String? error,
    required Key dateKey,
    required Key timeKey,
    required VoidCallback onDateTap,
    required VoidCallback onTimeTap,
    required double timeWidth,
  }) {
    final l10n = context.l10n;
    final formats = _formats;
    final locked = widget.timeLocked;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: GuSpacing.s8,
      children: [
        Expanded(
          child: GuPickerField(
            label: dateLabel,
            icon: GuIcons.calendar,
            value: value == null ? null : formats.dateShort(value),
            placeholder: l10n.commonSelect,
            errorText: error,
            disabled: locked,
            actionKey: dateKey,
            onTap: onDateTap,
          ),
        ),
        SizedBox(
          width: timeWidth,
          child: GuPickerField(
            label: l10n.eventFormTime,
            icon: GuIcons.clock,
            value: _timeText(value),
            placeholder: l10n.commonSelect,
            semanticHint: dateLabel,
            disabled: locked,
            actionKey: timeKey,
            onTap: onTimeTap,
          ),
        ),
      ],
    );
  }

  String? _timeText(DateTime? value) =>
      value == null ? null : _formats.time(value);

  /// İki saat seçicisinin ortak genişliği: prototipte 120 px sabit
  /// (`screens-manage.js:107–108`), ama o genişlikte metin alanı 34 px'tir ve
  /// "18:00" kesilir. En az 120; iki değerden (yoksa yer tutucudan) uzun
  /// olanı o anki metin ölçeğiyle sığacak kadar genişler — iki satır hizalı
  /// kalır.
  double _timeFieldWidthFor(AppLocalizations l10n) {
    final style = context.gu.text.input;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var widest = 0.0;
    for (final text in [
      _timeText(widget.startsAt) ?? l10n.commonSelect,
      _timeText(widget.endsAt) ?? l10n.commonSelect,
    ]) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textScaler: scaler,
        textDirection: direction,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    const chrome =
        2 * (GuSizes.pickerPaddingX + GuSizes.inputBorder + GuSizes.inputGap) +
        GuSizes.inputIcon +
        GuSizes.pickerChevron;
    return math.max(_timeFieldWidth, (widest + chrome).ceilToDouble());
  }

  /// W-82: başlamış yayındaki etkinlikte tarih / saat kilidinin açıklaması
  /// (`field-help` biçimi + kilit ikonu; tasarımda karşılığı yok).
  Widget _lockedNote(AppLocalizations l10n) {
    final gu = context.gu;
    final color = gu.colors.textMuted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: GuSizes.fieldHelpGap,
      children: [
        GuIcon(GuIcons.lock, size: GuSizes.fieldHelpIcon, color: color),
        Expanded(
          child: Text(
            l10n.eventFormTimeLocked,
            style: gu.text.fieldHelp.copyWith(color: color),
          ),
        ),
      ],
    );
  }

  Widget _capacityField(AppLocalizations l10n) {
    final gu = context.gu;
    final capacity = widget.capacity;
    final error = _errorText(EventField.capacity, l10n);
    final registered = widget.registeredCount;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s8,
      children: [
        // `row between`: etiket solda, "Sınırsız" + anahtar sağda.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          spacing: GuSpacing.s8,
          children: [
            Flexible(
              child: Text(l10n.eventFormCapacity, style: gu.text.fieldLabel),
            ),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: GuSpacing.s8,
                children: [
                  Flexible(
                    child: Text(
                      l10n.eventFormUnlimited,
                      textAlign: TextAlign.end,
                      style: gu.text.bodyS.copyWith(
                        color: gu.colors.textSecondary,
                      ),
                    ),
                  ),
                  GuSwitch(
                    key: GuKey.action('MGT-05.unlimited'),
                    value: capacity == null,
                    semanticLabel: l10n.eventFormUnlimited,
                    onChanged: (unlimited) => widget.onCapacityChanged(
                      unlimited
                          ? null
                          : _lastCapacity.clamp(
                              widget.minCapacity,
                              EventForm.capacityMax,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (capacity != null) ...[
          GuStepper(
            value: capacity,
            min: widget.minCapacity,
            max: EventForm.capacityMax,
            step: EventForm.capacityStep,
            semanticLabel: l10n.eventFormCapacity,
            decreaseSemanticLabel: l10n.eventFormDecrease,
            increaseSemanticLabel: l10n.eventFormIncrease,
            minusKey: GuKey.action('MGT-05.capacity.minus'),
            plusKey: GuKey.action('MGT-05.capacity.plus'),
            onChanged: widget.onCapacityChanged,
          ),
          if (error != null)
            FormErrorLine(error)
          else if (registered != null)
            Text(
              l10n.eventFormRegisteredNow(registered),
              textAlign: TextAlign.center,
              style: gu.text.caption,
            ),
        ],
      ],
    );
  }

  Widget _visibilityField(AppLocalizations l10n) {
    final gu = context.gu;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s8,
      children: [
        Text(l10n.eventFormVisibility, style: gu.text.fieldLabel),
        GuSegmented(
          options: [
            GuSegmentOption(
              id: EventVisibility.public.json,
              label: l10n.eventVisibilityPublic,
              icon: GuIcons.globe,
            ),
            GuSegmentOption(
              id: EventVisibility.membersOnly.json,
              label: l10n.eventVisibilityMembers,
              icon: GuIcons.lock,
            ),
          ],
          value: widget.visibility.json,
          onChanged: (id) =>
              widget.onVisibilityChanged(EventVisibility.fromJson(id)),
          optionKeyBuilder: (index) => _visibilityKeys[index],
        ),
        Text(
          switch (widget.visibility) {
            EventVisibility.public => l10n.eventFormVisibilityHelpPublic,
            EventVisibility.membersOnly => l10n.eventFormVisibilityHelpMembers,
          },
          style: gu.text.caption,
        ),
      ],
    );
  }

  Widget _autoReminderRow(AppLocalizations l10n) {
    final gu = context.gu;
    return Row(
      spacing: GuSpacing.s12,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.eventFormAutoReminder, style: gu.text.bodyM),
              Text(l10n.eventFormAutoReminderHelp, style: gu.text.caption),
            ],
          ),
        ),
        GuSwitch(
          key: GuKey.action('MGT-05.autoReminder'),
          value: widget.autoReminder,
          semanticLabel: l10n.eventFormAutoReminder,
          onChanged: widget.onAutoReminderChanged,
        ),
      ],
    );
  }

  List<Widget> _schedule(AppLocalizations l10n) {
    final timeWidth = _timeFieldWidthFor(l10n);
    return [
      _dateTimeRow(
        dateLabel: l10n.eventFormStartDate,
        value: widget.startsAt,
        error: _errorText(EventField.startsAt, l10n),
        dateKey: GuKey.action('MGT-05.startDate'),
        timeKey: GuKey.action('MGT-05.startTime'),
        onDateTap: widget.onStartDateTap,
        onTimeTap: widget.onStartTimeTap,
        timeWidth: timeWidth,
      ),
      _dateTimeRow(
        dateLabel: l10n.eventFormEndDate,
        value: widget.endsAt,
        error: _errorText(EventField.endsAt, l10n),
        dateKey: GuKey.action('MGT-05.endDate'),
        timeKey: GuKey.action('MGT-05.endTime'),
        onDateTap: widget.onEndDateTap,
        onTimeTap: widget.onEndTimeTap,
        timeWidth: timeWidth,
      ),
      if (widget.timeLocked) _lockedNote(l10n),
      if (widget.conflictCount > 0)
        GuBanner(
          icon: GuIcons.calendarDays,
          text: l10n.eventFormConflict(widget.conflictCount),
          card: true,
        ),
      GuPickerField(
        label: l10n.eventFormPlace,
        icon: GuIcons.mapPin,
        value: _placeLabel,
        placeholder: l10n.commonSelect,
        errorText: _errorText(EventField.place, l10n),
        actionKey: GuKey.action('MGT-05.place'),
        onTap: widget.onPlaceTap,
      ),
      _capacityField(l10n),
      _visibilityField(l10n),
      _autoReminderRow(l10n),
    ];
  }

  // ── 3 · Önizleme ──────────────────────────────────────────────────

  /// Formdaki değerlerle yayındaki etkinlik (prototip `preview`,
  /// `screens-manage.js:98`).
  EventModel _previewEvent(AppLocalizations l10n, DateTime now) => EventModel(
    clubId: widget.club?.id ?? '',
    title: widget.title.trim().isEmpty
        ? l10n.eventFormUntitled
        : widget.title.trim(),
    desc: widget.desc,
    type: widget.type ?? EventType.social,
    startsAt: widget.startsAt ?? now,
    endsAt: widget.endsAt ?? now,
    placeId: widget.placeId,
    placeText: widget.placeId == null ? widget.placeText : null,
    capacity: widget.capacity,
    visibility: widget.visibility,
    status: EventStatus.published,
    coverPalette: widget.coverPalette,
    coverPattern: widget.coverPattern,
    coverPath: widget.coverPath,
    autoReminder: widget.autoReminder,
  );

  Widget _previewCard(AppLocalizations l10n) {
    final now = ref.watch(appClockProvider).nowUtc();
    final event = _previewEvent(l10n, now);
    final status = EventCardStatus.of(
      event: event,
      rsvp: null,
      canSeeInside: true,
      nowUtc: now,
    );
    final kind = EventCtaKind.of(status: status, event: event);
    // Önizleme yalnızca gösterir: kart ve hızlı eylem dokunulmaz.
    return IgnorePointer(
      child: EventCard(
        event: event,
        club: widget.club,
        status: status,
        registeredCount: widget.registeredCount ?? 0,
        showClub: false,
        coverImage: _coverImage,
        quickAction: kind == null
            ? null
            : EventQuickAction(kind: kind, onPressed: _noop),
        onOpen: _noop,
      ),
    );
  }

  Widget _summary(AppLocalizations l10n) {
    final gu = context.gu;
    final formats = _formats;
    String dateTime(DateTime? value) =>
        value == null ? '' : formats.dateTime(l10n, value);
    final type = widget.type;
    final capacity = widget.capacity;
    final rows = <(String, String)>[
      (l10n.eventFormName, widget.title.trim()),
      (
        l10n.eventFormType,
        type == null ? '' : StaticLabels.eventType(context, type),
      ),
      (l10n.eventFormStartDate, dateTime(widget.startsAt)),
      (l10n.eventFormEndDate, dateTime(widget.endsAt)),
      (l10n.eventFormPlace, _placeLabel),
      (
        l10n.eventFormCapacity,
        capacity == null ? l10n.eventFormUnlimited : formats.number(capacity),
      ),
      (
        l10n.eventFormVisibility,
        switch (widget.visibility) {
          EventVisibility.public => l10n.eventVisibilityPublic,
          EventVisibility.membersOnly => l10n.eventVisibilityMembers,
        },
      ),
    ];
    return GuCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, (label, value)) in rows.indexed) ...[
            if (index > 0) const GuDivider(),
            Padding(
              padding: GuInsets.sym(
                v: GuSizes.tileInCardPaddingY,
                h: GuSpacing.s16,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: GuSpacing.s8,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: gu.text.bodyS.copyWith(
                          color: gu.colors.textMuted,
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * _summaryValueShare,
                      ),
                      child: Text(
                        value,
                        textAlign: TextAlign.end,
                        style: gu.text.bodyS.copyWith(
                          color: gu.colors.textHeading,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _settings(AppLocalizations l10n) => [
    GuBanner(icon: GuIcons.eye, text: l10n.eventFormPreviewNote, card: true),
    _previewCard(l10n),
    _summary(l10n),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s16,
      children: switch (widget.step) {
        EventFormStep.basics => _basics(l10n),
        EventFormStep.schedule => _schedule(l10n),
        EventFormStep.settings => _settings(l10n),
      },
    );
  }
}
