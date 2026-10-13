import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';

/// Çevrimdışı yazma engeli — **tek mekanizma** (Q-12, D-16).
///
/// Yazan her ViewModel metodu ilk satırda çağırır:
///
/// ```dart
/// Future<void> like() async {
///   if (!ensureOnline()) return;
///   …
/// }
/// ```
///
/// Yazım sunucudan hatayla dönerse ortak bildirim [showWriteFailureToast]:
/// ağ → TST-24, yetki yok → TST-X18.
mixin WriteGuardMixin on ProjectDependencyMixin {
  /// Bağlantı kaynaklı yazma hataları (→ TST-24).
  static const Set<FirestoreError> networkErrors = {
    FirestoreError.offline,
    FirestoreError.unavailable,
    FirestoreError.timeout,
  };

  /// Çevrimiçiyse `true`. Çevrimdışıysa TST-24 gösterir ve `false` döner;
  /// çağıran hiçbir şey yazmadan çıkar.
  bool ensureOnline() {
    final result = connectivityGate.requireOnline();
    if (result case FirebaseFailure(error: FirestoreError.offline)) {
      feedback.showToast(ToastId.tst24);
      return false;
    }
    return true;
  }

  /// Yazma hatasının bildirimi: ağ → TST-24, yetki yok → TST-X18. Toast
  /// gösterildiyse `true`; başka hatada `false` (çağıran günlüğe yazar ve
  /// gerekiyorsa ekranı yeniler).
  bool showWriteFailureToast(FirestoreError error) {
    if (networkErrors.contains(error)) {
      feedback.showToast(ToastId.tst24);
      return true;
    }
    if (error == FirestoreError.permissionDenied) {
      feedback.showToast(ToastId.tstX18);
      return true;
    }
    return false;
  }
}
