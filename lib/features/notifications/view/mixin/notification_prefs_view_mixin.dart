import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/notifications/provider/notification_prefs_state.dart';
import 'package:gu_kulupler/features/notifications/provider/notification_prefs_view_model.dart';
import 'package:gu_kulupler/features/notifications/view/notification_prefs_view.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/time_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/format/time_of_day_value.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';

/// NTF-02 davranışı: gezinme, SHT-29 / SHT-07 açma, izin dönüşü (prototip
/// `NotifPrefs`, `screens-events.js:109–120`).
///
/// * Geri (`NTF-02.back`) önceki sayfaya döner; yığın yoksa NTF-01.
/// * "Başlangıç" / "Bitiş" (`NTF-02.quietFrom` / `quietTo`) SHT-29'u o anki
///   değerle açar; seçilen saat aralığın o ucunu değiştirir.
/// * Kulüp satırı (`NTF-02.club.<id>`) SHT-07'yi açar
///   ([NotificationPrefsView.clubPrefsSheetBuilder]; kapanınca alt satır
///   yenilenir). Gövde verilmemişse CLB-03'e gidilir (kulüp bildirim
///   tercihi oradaki menüdedir).
/// * Uygulama ön plana dönünce (sistem ayarlarından) izin yeniden okunur.
mixin NotificationPrefsViewMixin on ConsumerState<NotificationPrefsView> {
  /// Ekranın ViewModel sağlayıcısı.
  NotificationPrefsViewModelProvider get provider =>
      notificationPrefsViewModelProvider;

  /// Ekranın ViewModel'i.
  NotificationPrefsViewModel get viewModel => ref.read(provider.notifier);

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(viewModel.refreshPermission()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Geri (`NTF-02.back`): önceki sayfa; yığın yoksa NTF-01.
  void goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      const NotificationsRoute().go(context);
    }
  }

  /// "Yeniden dene" (`NTF-02.retry`).
  Future<void> retry() => viewModel.fetch();

  /// Tür anahtarı / "Sessiz saatler" (`NTF-02.toggle.<ad>`, `NTF-02.quiet`).
  void toggle(NotificationPrefField field, {required bool value}) =>
      unawaited(viewModel.toggle(field, value: value));

  /// Hatırlatma zamanı dilimi (`NTF-02.reminderTime.<1h|1d>`).
  void selectReminderTime(String id) =>
      unawaited(viewModel.setReminderTime(ReminderOption.fromJson(id)));

  /// "İzni aç" (`NTF-02.permission`).
  void enablePermission() => unawaited(viewModel.enablePermission());

  /// "Başlangıç" (`NTF-02.quietFrom`) → SHT-29.
  Future<void> pickQuietFrom() async {
    final state = ref.read(provider);
    final picked = await _pickTime(state.quietFrom);
    if (picked == null || !mounted) return;
    await viewModel.setQuietRange(picked, ref.read(provider).quietTo);
  }

  /// "Bitiş" (`NTF-02.quietTo`) → SHT-29.
  Future<void> pickQuietTo() async {
    final state = ref.read(provider);
    final picked = await _pickTime(state.quietTo);
    if (picked == null || !mounted) return;
    await viewModel.setQuietRange(ref.read(provider).quietFrom, picked);
  }

  /// Kulüp satırı (`NTF-02.club.<id>`) → SHT-07 (ya da CLB-03).
  Future<void> openClub(ClubModel club) async {
    final builder = widget.clubPrefsSheetBuilder;
    if (builder == null) {
      ClubDetailRoute(clubId: club.id).go(context);
      return;
    }
    await ref
        .read(feedbackServiceProvider)
        .showSheet<void>(
          SheetId.sht07,
          builder: (_) => builder(club.id, club.name),
        );
    if (!mounted) return;
    await viewModel.refreshClubPrefs();
  }

  Future<TimeOfDayValue?> _pickTime(TimeOfDayValue initial) => ref
      .read(feedbackServiceProvider)
      .showSheet<TimeOfDayValue>(
        SheetId.sht29,
        builder: (_) => TimePickerSheet(initial: initial),
      );
}
