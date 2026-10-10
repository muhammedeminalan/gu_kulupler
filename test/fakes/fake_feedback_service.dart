// `FeedbackService` fake'i (PLAN §16.3): overlay açmaz, çağrıları kaydeder.
//
//   final feedback = FakeFeedbackService()..nextDialogResult = true;
//   await viewModel.leave();
//   expect(feedback.dialogs, [DialogId.dlg08]);
//   expect(feedback.toasts, [ToastId.tst39]);
import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/menu_id.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';

import 'fake_base.dart';

final class FakeFeedbackService extends FakeBase implements FeedbackService {
  /// Gösterilen toastlar (sırayla).
  final List<ToastId> toasts = <ToastId>[];

  /// [toasts] ile aynı sırada toast değişkenleri.
  final List<ToastParams> toastParams = <ToastParams>[];

  /// Açılan alt sayfalar.
  final List<SheetId> sheets = <SheetId>[];

  /// Açılan dialoglar.
  final List<DialogId> dialogs = <DialogId>[];

  /// [dialogs] ile aynı sırada dialog değişkenleri.
  final List<DialogParams> dialogParams = <DialogParams>[];

  /// Açılan menüler (satır içi menü → `null`).
  final List<MenuId?> menus = <MenuId?>[];

  /// Son `showMenu` çağrısının öğeleri.
  List<Widget> lastMenuItems = const <Widget>[];

  /// Son `showSheet` içerik kurucusu (içeriği ayrıca çizmek için).
  WidgetBuilder? lastSheetBuilder;

  /// Son `showDialog` içerik kurucusu; katalog kipinde `null`.
  WidgetBuilder? lastDialogBuilder;

  /// Bir sonraki `showSheet` sonucu (tek seferlik; varsayılan `null` =
  /// kapatıldı).
  Object? nextSheetResult;

  /// Bir sonraki `showDialog` sonucu (tek seferlik; varsayılan `null`).
  Object? nextDialogResult;

  /// Bir sonraki `showMenu` sonucu (tek seferlik; varsayılan `null`).
  Object? nextMenuResult;

  /// Ekranda sayılan toast (son gösterilen; `closeToast` / eylem sonrası
  /// `null`).
  ToastId? visibleToast;

  VoidCallback? _toastAction;

  /// Son toastın eylemi var mı (`onAction` verildi mi).
  bool get hasToastAction => _toastAction != null;

  /// Son toastın eylem düğmesine dokunur: toast kapanır, sonra `onAction`
  /// çağrılır (gerçek servisle aynı sıra). Eylem yoksa `StateError`.
  void tapToastAction() {
    final action = _toastAction;
    if (action == null) throw StateError('Son toastın eylemi yok.');
    visibleToast = null;
    _toastAction = null;
    action();
  }

  @override
  Future<T?> showSheet<T>(
    SheetId id, {
    required WidgetBuilder builder,
    bool isDismissible = true,
    bool enableDrag = true,
  }) async {
    record('showSheet', [id]);
    sheets.add(id);
    lastSheetBuilder = builder;
    final result = nextSheetResult;
    nextSheetResult = null;
    return result as T?;
  }

  @override
  Future<T?> showDialog<T>(
    DialogId id, {
    WidgetBuilder? builder,
    DialogParams params = const <String, Object>{},
    bool barrierDismissible = true,
  }) async {
    record('showDialog', [id, params]);
    dialogs.add(id);
    dialogParams.add(params);
    lastDialogBuilder = builder;
    final result = nextDialogResult;
    nextDialogResult = null;
    return result as T?;
  }

  @override
  void showToast(
    ToastId id, {
    ToastParams params = const ToastParams(),
    VoidCallback? onAction,
  }) {
    record('showToast', [id, params]);
    toasts.add(id);
    toastParams.add(params);
    visibleToast = id;
    _toastAction = onAction;
  }

  @override
  Future<T?> showMenu<T>({
    required Key scrimKey,
    required List<Widget> items,
    MenuId? id,
  }) async {
    record('showMenu', [id, scrimKey]);
    menus.add(id);
    lastMenuItems = items;
    final result = nextMenuResult;
    nextMenuResult = null;
    return result as T?;
  }

  @override
  void closeToast() {
    record('closeToast');
    visibleToast = null;
    _toastAction = null;
  }

  @override
  void resetFake() {
    super.resetFake();
    toasts.clear();
    toastParams.clear();
    sheets.clear();
    dialogs.clear();
    dialogParams.clear();
    menus.clear();
    lastMenuItems = const <Widget>[];
    lastSheetBuilder = null;
    lastDialogBuilder = null;
    nextSheetResult = null;
    nextDialogResult = null;
    nextMenuResult = null;
    visibleToast = null;
    _toastAction = null;
  }
}
