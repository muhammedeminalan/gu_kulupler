import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/init/app_gate_view_model.dart';

/// Kök kapı katmanı (`GuApp.builder` zinciri; navigation.md §4, architecture
/// §6): `AppGateState` bayraklarını **rota olmayan** iki kök dialoga çevirir.
///
/// * `isUpdateRequired` → DLG-26 "Güncelleme gerekli". Kapatılamaz;
///   "Güncelle" mağazayı açar ve kapı kalkmadıkça dialog yeniden gösterilir.
/// * `isSessionExpired` → DLG-27 "Oturumun sona erdi". "Giriş yap" oturumu
///   kapatır ve bayrağı indirir; `/login`'e geçişi router yapar (R3). Oturum
///   kapatılamazsa bayrak inmez ve dialog yeniden gösterilir (kullanıcı ölü
///   oturumla uygulamada bırakılmaz).
///
/// İkisi birden açıksa önce güncelleme gösterilir. Dialoglar
/// `FeedbackService` ile kök gezgine itilir; alttaki sayfa değişip dialog
/// rotasını düşürürse (yönlendirme) kapı hâlâ açıkken yeniden gösterilir.
///
/// Design: DLG-26, DLG-27
class AppGate extends ConsumerStatefulWidget {
  /// Kapı katmanı; [child] uygulama gövdesidir (gezgin).
  const AppGate({required this.child, super.key});

  /// Kapıların üstüne açıldığı içerik.
  final Widget child;

  @override
  ConsumerState<AppGate> createState() => _AppGateState();
}

class _AppGateState extends ConsumerState<AppGate> {
  /// Ekrandaki kapı dialogu; yoksa `null`.
  DialogId? _open;

  @override
  void initState() {
    super.initState();
    _syncAfterFrame();
  }

  @override
  void didUpdateWidget(AppGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Üst katman her yeniden kurulduğunda (rota değişimi) bekleyen kapı
    // yeniden denenir: ilk denemede gezgin hazır olmayabilir.
    _syncAfterFrame();
  }

  void _syncAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  /// Açık kapı varsa ve ekranda dialog yoksa ilgili dialogu gösterir.
  void _sync() {
    if (!mounted || _open != null) return;
    final gate = ref.read(appGateViewModelProvider);
    if (gate.isUpdateRequired) {
      unawaited(_show(DialogId.dlg26));
    } else if (gate.isSessionExpired) {
      unawaited(_show(DialogId.dlg27));
    }
  }

  Future<void> _show(DialogId id) async {
    _open = id;
    // Dialog bir kare bile çizilmeden `null` döndüyse gezgin hazır değildir:
    // yeniden deneme bir sonraki tetikleyiciye (durum / rota değişimi) kalır.
    var frameDrawn = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => frameDrawn = true);
    final confirmed = await ref
        .read(feedbackServiceProvider)
        .showDialog<bool>(id);
    _open = null;
    if (!mounted) return;
    if (confirmed ?? false) {
      await _confirm(id);
    } else if (!frameDrawn) {
      return;
    }
    if (!mounted) return;
    // Kapı hâlâ açıksa (güncelleme yapılmadı; rota dialogu düşürdü) yeniden.
    _syncAfterFrame();
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _confirm(DialogId id) async {
    final gate = ref.read(appGateViewModelProvider.notifier);
    if (id == DialogId.dlg26) {
      await gate.openStore();
      return;
    }
    final signedOut = await ref
        .read(sessionViewModelProvider.notifier)
        .signOut();
    // Başarısızsa kapı açık kalır: `_show` DLG-27'yi yeniden gösterir.
    if (signedOut) gate.acknowledgeSessionExpired();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      appGateViewModelProvider.select(
        (gate) => (gate.isUpdateRequired, gate.isSessionExpired),
      ),
      (_, _) => _sync(),
    );
    return widget.child;
  }
}
