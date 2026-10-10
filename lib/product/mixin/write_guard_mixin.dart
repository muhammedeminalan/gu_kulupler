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
mixin WriteGuardMixin on ProjectDependencyMixin {
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
}
