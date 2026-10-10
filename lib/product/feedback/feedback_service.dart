import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/spec_dialog.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/menu_id.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_ui/gu_ui.dart';

/// Sheet / dialog / açılır menü / toast için **tek giriş** (CLAUDE.md §7,
/// CD-113). View ve ViewModel `showGuSheet` / `showGuDialog` /
/// `showGuPopMenu` primitiflerini doğrudan çağırmaz (`check_hardcode` HC12c).
///
/// `BuildContext` almaz: ViewModel'ler `feedback.showToast(ToastId.tst24)`
/// yazabilir. View tarafında erişim `ref.read(feedbackServiceProvider)`
/// (CD-93).
abstract interface class FeedbackService {
  /// [id] alt sayfasını açar; [builder] bir `GuSheetFrame` döndürür. Sonuç,
  /// sayfanın `pop` değeridir (scrim / sürükleme / geri → `null`).
  ///
  /// Scrim anahtarı `<ID>.scrim`. [isDismissible] `false` → scrim kapatmaz;
  /// [enableDrag] `false` → sürükleyerek kapanmaz.
  Future<T?> showSheet<T>(
    SheetId id, {
    required WidgetBuilder builder,
    bool isDismissible = true,
    bool enableDrag = true,
  });

  /// [id] dialogunu açar.
  ///
  /// * [builder] verilirse içerik odur (bir `GuDialogFrame` döndürür); sonuç
  ///   `pop` değeridir.
  /// * Verilmezse `DialogCatalog` kaydı [params] ile çizilir; birincil düğme
  ///   `true`, ikincil `false`, scrim / geri `null` döndürür (`T` = `bool`).
  ///   Kaydı olmayan kimlik `StateError` atar.
  ///
  /// Scrim anahtarı `<ID>.scrim`. [barrierDismissible] `false` → scrim ve
  /// Esc kapatmaz.
  Future<T?> showDialog<T>(
    DialogId id, {
    WidgetBuilder? builder,
    DialogParams params = const <String, Object>{},
    bool barrierDismissible = true,
  });

  /// [id] toastını gösterir; ekrandaki toast varsa yerini alır (en çok 1).
  ///
  /// Eylem düğmesi yalnızca katalog kaydında eylem etiketi **ve** [onAction]
  /// varsa çizilir; o zaman süre 6 sn (`GuMotion.toastUndo`), değilse 4 sn
  /// (`GuMotion.toastDefault`). Eylem dokunuşu toastı kapatır, sonra
  /// [onAction]'ı çağırır.
  void showToast(
    ToastId id, {
    ToastParams params = const ToastParams(),
    VoidCallback? onAction,
  });

  /// Açılır menüyü sabit sağ üst konumda açar (CD-83); [items]
  /// `GuPopMenuItem` listesidir. Sonuç dokunulan öğenin `value`'su (scrim /
  /// geri → `null`).
  ///
  /// [id] kayıtlı menüler için (`registry.json#menus`); satır içi menülerde
  /// `null`. [scrimKey] çağırandan gelir (`EVT-02.scrim`, `SHT-01.scrim` …).
  Future<T?> showMenu<T>({
    required Key scrimKey,
    required List<Widget> items,
    MenuId? id,
  });

  /// Ekrandaki toastı kapatır (yoksa etkisiz).
  void closeToast();
}

/// [FeedbackService]'in uygulaması: overlay'leri [navigatorKey]'in
/// gezginine iter, toastları [toastController] üzerinden `GuToastHost`'a
/// verir.
///
/// * Bağlam ve yerelleştirme her çağrıda [navigatorKey]'den okunur (dil
///   değişimi sonraki çağrıda geçerli olur).
/// * Gezgin ağaca bağlı değilse (uygulama kökü kurulmadan ya da söküldükten
///   sonra) çağrı yok sayılır; overlay çağrıları `null` döner.
/// * Kayıt kompozisyon kökünde (`ProjectDependency`, T-11):
///   `rootNavigatorKey` + `GuApp.builder`'daki `GuToastHost` denetleyicisi.
final class AppFeedbackService implements FeedbackService {
  const AppFeedbackService({
    required this.navigatorKey,
    required this.toastController,
    this.dialogSpecOf = DialogCatalog.of,
  });

  /// Overlay'lerin itildiği gezgin (kök gezgin).
  final GlobalKey<NavigatorState> navigatorKey;

  /// `GuToastHost` ile paylaşılan toast kuyruğu.
  final GuToastController toastController;

  /// Katalog kipinde dialog kaydını veren arama (varsayılan
  /// `DialogCatalog.of`).
  final DialogSpec? Function(DialogId id) dialogSpecOf;

  @override
  Future<T?> showSheet<T>(
    SheetId id, {
    required WidgetBuilder builder,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    final context = navigatorKey.currentContext;
    if (context == null) return Future<T?>.value();
    return showGuSheet<T>(
      context,
      builder: builder,
      useRootNavigator: false,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      barrierLabel: AppLocalizations.of(context).a11yClose,
      scrimKey: FeedbackKeys.of(id.designId, _scrim),
    );
  }

  @override
  Future<T?> showDialog<T>(
    DialogId id, {
    WidgetBuilder? builder,
    DialogParams params = const <String, Object>{},
    bool barrierDismissible = true,
  }) {
    final context = navigatorKey.currentContext;
    if (context == null) return Future<T?>.value();
    var content = builder;
    var dismissible = barrierDismissible;
    if (content == null) {
      final spec = dialogSpecOf(id);
      if (spec == null) {
        throw StateError(
          '${id.designId}: DialogCatalog kaydı yok; showDialog(builder:) ver.',
        );
      }
      content = (_) => SpecDialog(id: id, spec: spec, params: params);
      dismissible = barrierDismissible && spec.dismissible;
    }
    return showGuDialog<T>(
      context,
      builder: content,
      barrierDismissible: dismissible,
      useRootNavigator: false,
      barrierLabel: AppLocalizations.of(context).a11yClose,
      scrimKey: FeedbackKeys.of(id.designId, _scrim),
    );
  }

  @override
  void showToast(
    ToastId id, {
    ToastParams params = const ToastParams(),
    VoidCallback? onAction,
  }) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    final l10n = AppLocalizations.of(context);
    final spec = ToastCatalog.of(id);
    assert(
      onAction == null || spec.actionLabel != null,
      '${id.designId}: katalog kaydında eylem etiketi yok, onAction çizilmez.',
    );
    final actionLabel = onAction == null ? null : spec.actionLabel?.call(l10n);
    toastController.show(
      GuToastEntry(
        kind: spec.kind,
        text: spec.text(l10n, params),
        closeSemanticLabel: l10n.a11yClose,
        actionLabel: actionLabel,
        onAction: actionLabel == null ? null : onAction,
        duration: actionLabel == null
            ? ToastDurationKind.standard.duration
            : spec.durationKind.duration,
        persistent: spec.persistent,
        toastKey: ValueKey<ToastId>(id),
        actionKey: FeedbackKeys.of(id.designId, spec.actionKeyName),
        closeKey: FeedbackKeys.of(id.designId, _close),
      ),
    );
  }

  @override
  Future<T?> showMenu<T>({
    required Key scrimKey,
    required List<Widget> items,
    MenuId? id,
  }) {
    final context = navigatorKey.currentContext;
    if (context == null) return Future<T?>.value();
    return showGuPopMenu<T>(
      context,
      items: items,
      scrimKey: scrimKey,
      barrierLabel: AppLocalizations.of(context).a11yClose,
      useRootNavigator: false,
    );
  }

  @override
  void closeToast() => toastController.hide();

  static const String _scrim = 'scrim';
  static const String _close = 'close';
}
