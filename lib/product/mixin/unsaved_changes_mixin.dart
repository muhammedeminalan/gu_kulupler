import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/unsaved_changes_dialog.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';

export 'package:gu_kulupler/product/feedback/catalogs/dialogs/unsaved_changes_dialog.dart'
    show UnsavedChangesResult;

/// DLG-25 "Değişiklikler kaydedilmedi" dialogunu [feedback] üzerinden açar —
/// **tek giriş**. Sonuç dokunulan eylemdir; scrim ve geri `null` döner
/// ("düzenlemeye devam").
///
/// Ekranlar doğrudan değil [UnsavedChangesMixin] ile kullanır. Kirli
/// sheet'ler (SHT-05, SHT-10, SHT-20, SHT-32) `hasSave` vermeden çağırır:
/// `discard` → sheet kapanır, `keep` / `null` → açık kalır.
Future<UnsavedChangesResult?> showUnsavedChangesDialog(
  FeedbackService feedback, {
  bool hasSave = false,
}) => feedback.showDialog<UnsavedChangesResult>(
  DialogId.dlg25,
  builder: (_) => UnsavedChangesDialog(hasSave: hasSave),
);

/// Kaydedilmemiş değişiklik koruması — DLG-25 "Değişiklikler kaydedilmedi"
/// (PLAN §13.8; `dialogs.js:43`): form ekranından geri / kapat ile çıkılırken
/// değişiklik varsa önce sorulur.
///
/// Kullanım (AUT-05, PRF-02, FED-03, MGT-05, MGT-09, ADM-03, SET-05):
///
/// ```dart
/// class _EditProfileViewState extends ConsumerState<EditProfileView>
///     with UnsavedChangesMixin {
///   @override
///   bool get isDirty => ref.watch(editProfileViewModelProvider).isDirty;
///
///   @override
///   Future<bool> Function()? get onSaveRequested => _save; // "Kaydet"
///
///   @override
///   Widget build(BuildContext context) => buildUnsavedGuard(
///     child: Scaffold(appBar: GuAppBar(onBack: confirmLeave), …),
///   );
/// }
/// ```
///
/// * Sistem geri tuşu / geri hareketi [buildUnsavedGuard] ile yakalanır
///   (`PopScope(canPop: !isDirty)`); uygulama çubuğundaki geri / kapat
///   düğmesi [confirmLeave] çağırır. İkisi de aynı akışı çalıştırır.
/// * [isDirty] `false` ise soru sorulmaz, ekran doğrudan kapanır.
/// * "Kaydet" yalnızca [onSaveRequested] verildiyse çizilir.
///
/// Design: DLG-25
mixin UnsavedChangesMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  bool _isAsking = false;

  /// Formda kaydedilmemiş değişiklik var mı (çoğunlukla `state.isDirty`)?
  /// `build` içinde okunur: değişince koruma yeniden kurulmalıdır
  /// (`ref.watch`).
  bool get isDirty;

  /// DLG-25 "Kaydet" eylemi: kaydeder ve başarıyı döndürür (`true` → ekran
  /// kapanır, `false` → açık kalır). `null` (varsayılan) → düğme çizilmez
  /// (AUT-05, ADM-03).
  Future<bool> Function()? get onSaveRequested => null;

  /// Ekranı kapatır. Varsayılan `context.pop()`; yığında geri dönülecek
  /// sayfa yoksa etkisizdir — `go` ile açılan kök ekranlar (AUT-05) bunu ya
  /// da [onDiscardConfirmed]'ı ezer.
  void leaveScreen() {
    if (context.canPop()) context.pop();
  }

  /// "Kaydetmeden çık" seçildi. Varsayılan [leaveScreen]; AUT-05 oturumu
  /// kapatır (`screens-auth.js:141`).
  Future<void> onDiscardConfirmed() async => leaveScreen();

  /// [child] ağacını sistem geri tuşuna / geri hareketine karşı korur.
  Widget buildUnsavedGuard({required Widget child}) => PopScope<Object?>(
    canPop: !isDirty,
    onPopInvokedWithResult: onPopInvoked,
    child: child,
  );

  /// Geri / kapat düğmesi: değişiklik yoksa ekranı kapatır, varsa DLG-25
  /// sorar.
  Future<void> confirmLeave() async {
    if (!isDirty) {
      leaveScreen();
      return;
    }
    await _askAndApply();
  }

  /// `PopScope` geri çağrısı: geri engellendiyse (`didPop == false`) DLG-25
  /// sorar.
  @protected
  Future<void> onPopInvoked(bool didPop, Object? result) async {
    if (didPop) return;
    await _askAndApply();
  }

  Future<void> _askAndApply() async {
    // Açık bir soru varken ikinci geri isteği yeni dialog açmaz.
    if (_isAsking) return;
    _isAsking = true;
    try {
      final save = onSaveRequested;
      final result = await showUnsavedChangesDialog(
        ref.read(feedbackServiceProvider),
        hasSave: save != null,
      );
      if (!mounted) return;
      switch (result) {
        case UnsavedChangesResult.save:
          if (save != null && await save() && mounted) leaveScreen();
        case UnsavedChangesResult.discard:
          await onDiscardConfirmed();
        case UnsavedChangesResult.keep || null:
          break;
      }
    } finally {
      _isAsking = false;
    }
  }
}
