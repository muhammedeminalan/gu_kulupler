import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/features/management/provider/event_form_state.dart';
import 'package:gu_kulupler/features/management/provider/event_form_view_model.dart';
import 'package:gu_kulupler/features/management/view/event_form_view.dart';
import 'package:gu_kulupler/features/management/view/widget/place_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/cover_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/date_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/time_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialogs/publish_event_dialog.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/format/time_of_day_value.dart';
import 'package:gu_kulupler/product/mixin/unsaved_changes_mixin.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/widget/calendar/app_calendar.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';

/// MGT-05 davranışı: kapatma (DLG-25), seçici sayfalar (SHT-28 / SHT-29 /
/// SHT-30 / SHT-31), taslak ve yayın (DLG-22) sonrası gezinme (prototip
/// `S['MGT-05']`, `screens-manage.js:95–100`).
///
/// * **Kapat** (`MGT-05.close`) ve sistem geri tuşu: değişiklik varsa DLG-25
///   — "Kaydet" içeriği kaydeder (`saveChanges`: TST-13 / TST-21) ve çıkar;
///   "Kaydetmeden çık" çıkar. Gönderim sürerken kapat etkisizdir.
/// * **Tarih / saat** (`MGT-05.startDate` …): SHT-28 / SHT-29; yeni
///   etkinlikte başlangıç günü bugünden, bitiş günü başlangıç gününden önce
///   seçilemez (prototip `min`).
/// * **Kapak** (`MGT-05.cover`): SHT-31 → şablon ya da SHT-16 kaynağı.
/// * **Mekân** (`MGT-05.place`): SHT-30.
/// * **"Taslak olarak kaydet"** (`MGT-05.saveDraft`): başarıda MGT-04
///   "Taslaklar" sekmesine dönülür.
/// * **"Yayınla"** (`MGT-05.publish`): form geçerliyse DLG-22 (bildirim
///   seçeneği) → yayın → MGT-04; TST-30 "Görüntüle" EVT-02'yi açar (toast
///   ekran kapandıktan sonra da durur — gezinme router üzerindendir).
///   Yayındaki etkinlikte "Kaydet": DLG-22 sorulmaz.
mixin EventFormViewMixin on UnsavedChangesMixin<EventFormView> {
  /// Ekranın ViewModel sağlayıcısı (kulüp + düzenlenen etkinlik ailesi).
  EventFormViewModelProvider get provider => eventFormViewModelProvider(
    clubId: widget.clubId,
    editEventId: widget.eventId,
  );

  /// Ekranın ViewModel'i.
  EventFormViewModel get viewModel => ref.read(provider.notifier);

  FeedbackService get _feedback => ref.read(feedbackServiceProvider);

  EventFormState get _state => ref.read(provider);

  /// DLG-22 tahmini / onayı sürüyor (çift dokunmada ikinci dialog açılmaz).
  bool _isConfirming = false;

  @override
  bool get isDirty => ref.watch(provider.select((state) => state.isDirty));

  /// DLG-25 "Kaydet" = içeriği kaydet (durum değişmez).
  @override
  Future<bool> Function()? get onSaveRequested => _saveChanges;

  Future<bool> _saveChanges() async =>
      await viewModel.saveChanges() == EventFormOutcome.saved;

  /// Önceki sayfa; yığın yoksa kulübün etkinlik yönetimi (MGT-04).
  @override
  void leaveScreen() {
    if (context.canPop()) {
      context.pop();
    } else {
      ManageEventsRoute(clubId: widget.clubId).go(context);
    }
  }

  /// Kapat (`MGT-05.close`); gönderim sürerken etkisizdir.
  void onClose() {
    if (_state.isSubmitting) return;
    unawaited(confirmLeave());
  }

  /// "Yeniden dene" (`MGT-05.retry`): düzenlenecek etkinlik yeniden okunur.
  Future<void> retry() => viewModel.loadForEdit();

  /// Kapak (`MGT-05.cover`) → SHT-31: şablon ya da özel kapak kaynağı.
  Future<void> openCover() async {
    final state = _state;
    final club = state.club;
    final result = await _feedback.showSheet<CoverPickerResult>(
      SheetId.sht31,
      builder: (_) => CoverPickerContent(
        palette: state.coverPalette,
        pattern: state.coverPattern,
        seed: state.original?.coverSeed ?? widget.clubId,
        icon: club == null ? null : CoverMapper.icon(club.iconName),
      ),
    );
    if (!mounted) return;
    switch (result) {
      case CoverTemplatePicked(:final palette, :final pattern):
        viewModel.setCoverTemplate(palette, pattern);
      case CoverUploadPicked(:final source):
        await viewModel.pickCover(source);
      case null:
        break;
    }
  }

  /// Başlangıç tarihi (`MGT-05.startDate`) → SHT-28.
  Future<void> openStartDate() async {
    final startsAt = _state.startsAt;
    final day = await _pickDay(
      startsAt,
      firstDate: widget.isEdit
          ? null
          : AppCalendar.todayOf(ref.read(appClockProvider)),
    );
    if (day != null && mounted) viewModel.setStartDate(day);
  }

  /// Başlangıç saati (`MGT-05.startTime`) → SHT-29.
  Future<void> openStartTime() async {
    final time = await _pickTime(_state.startsAt);
    if (time != null && mounted) viewModel.setStartTime(time);
  }

  /// Bitiş tarihi (`MGT-05.endDate`) → SHT-28; başlangıç gününden önce
  /// seçilemez.
  Future<void> openEndDate() async {
    final startsAt = _state.startsAt;
    final day = await _pickDay(
      _state.endsAt,
      firstDate: startsAt == null ? null : AppCalendar.dayOf(startsAt),
    );
    if (day != null && mounted) viewModel.setEndDate(day);
  }

  /// Bitiş saati (`MGT-05.endTime`) → SHT-29.
  Future<void> openEndTime() async {
    final time = await _pickTime(_state.endsAt);
    if (time != null && mounted) viewModel.setEndTime(time);
  }

  /// Mekân (`MGT-05.place`) → SHT-30.
  Future<void> openPlace() async {
    final state = _state;
    final text = state.placeText;
    final result = await _feedback.showSheet<PlacePickerResult>(
      SheetId.sht30,
      builder: (_) => PlacePickerSheet(
        placeId: state.placeId,
        placeText: text.isEmpty ? null : text,
      ),
    );
    if (result == null || !mounted) return;
    viewModel.setPlace(placeId: result.placeId, placeText: result.placeText);
  }

  /// "Taslak olarak kaydet" (`MGT-05.saveDraft`): başarıda MGT-04
  /// "Taslaklar".
  Future<void> saveDraft() async {
    final outcome = await viewModel.saveDraft();
    if (!mounted) return;
    switch (outcome) {
      case EventFormOutcome.saved || EventFormOutcome.unpublished:
        _goToEvents(_state.isPublished ? null : ManageEventsTab.draft);
      case _:
        break;
    }
  }

  /// "Yayınla" / "Kaydet" (`MGT-05.publish`).
  Future<void> publish() async {
    // TST-30 "Görüntüle" ekran kapandıktan sonra gelir: bağlam yerine router.
    final router = GoRouter.of(context);
    final EventFormOutcome outcome;
    if (_state.isPublished) {
      outcome = await viewModel.publish(notify: false);
    } else {
      if (_isConfirming ||
          _state.isSubmitting ||
          !viewModel.validate(forPublish: true)) {
        return;
      }
      _isConfirming = true;
      final bool? notify;
      try {
        final count = await viewModel.estimateRecipients();
        if (!mounted) return;
        notify = await PublishEventDialog.show(_feedback, count: count);
      } finally {
        _isConfirming = false;
      }
      if (notify == null || !mounted) return;
      outcome = await viewModel.publish(
        notify: notify,
        onView: (eventId) =>
            router.go(EventDetailRoute(eventId: eventId).location),
      );
    }
    if (!mounted) return;
    if (outcome case EventFormOutcome.saved || EventFormOutcome.published) {
      _goToEvents(null);
    }
  }

  void _goToEvents(ManageEventsTab? tab) =>
      ManageEventsRoute(clubId: widget.clubId, tab: tab).go(context);

  Future<DateTime?> _pickDay(DateTime? current, {DateTime? firstDate}) {
    final clock = ref.read(appClockProvider);
    return _feedback.showSheet<DateTime>(
      SheetId.sht28,
      builder: (_) => DatePickerSheet(
        initial: AppCalendar.dayOf(current ?? clock.nowUtc()),
        firstDate: firstDate,
      ),
    );
  }

  Future<TimeOfDayValue?> _pickTime(DateTime? current) {
    if (current == null) return Future<TimeOfDayValue?>.value();
    final day = AppCalendar.dayOf(current);
    final wall = current.difference(AppCalendar.instantOf(day));
    return _feedback.showSheet<TimeOfDayValue>(
      SheetId.sht29,
      builder: (_) => TimePickerSheet(
        initial: TimeOfDayValue(
          wall.inHours,
          wall.inMinutes % TimeOfDayValue.minutesPerHour,
        ),
      ),
    );
  }
}
