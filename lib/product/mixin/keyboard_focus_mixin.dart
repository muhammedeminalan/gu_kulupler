import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Form ekranlarında klavye odağı (design-analysis §G; prototip `Input
/// onEnter` `ui.js:24`, ilk hatalı alana odak `screens-auth.js:89`).
///
/// * [focusOrder] klavyeyle gezilen alanların sırasıdır; her alanın odak
///   düğümü ilk okumada kurulur ([focusNodeOf]) ve `dispose`'da kapatılır.
/// * Klavye eylem tuşu son alanda "bitti", diğerlerinde "sonraki"dir
///   ([actionFor]); [focusNext] sıradaki alana geçer.
/// * Gönderim reddedilince [focusFirstError] odağı sıradaki ilk hatalı alana
///   taşır.
///
/// `GuInput(focusNode:, textInputAction:, onSubmitted:)` ile bağlanır:
///
/// ```dart
/// mixin LoginViewMixin on KeyboardFocusMixin<LoginView, LoginField> {
///   @override
///   List<LoginField> get focusOrder => LoginField.values;
///
///   void onFieldSubmitted(LoginField field) {
///     if (!focusNext(field)) unawaited(submit());
///   }
/// }
/// ```
mixin KeyboardFocusMixin<T extends ConsumerStatefulWidget, F extends Enum>
    on ConsumerState<T> {
  final Map<F, FocusNode> _focusNodes = <F, FocusNode>{};

  /// Klavyeyle sırayla gezilen alanlar (ekrandaki sırayla).
  List<F> get focusOrder;

  /// [field] alanının odak düğümü (ilk okumada kurulur).
  FocusNode focusNodeOf(F field) =>
      _focusNodes[field] ??= FocusNode(debugLabel: '$T.${field.name}');

  /// [field] için klavye eylem tuşu: son alanda "bitti", diğerlerinde
  /// "sonraki".
  TextInputAction actionFor(F field) =>
      field == focusOrder.last ? TextInputAction.done : TextInputAction.next;

  /// Odağı [current]'tan sonraki alana taşır ve `true` döner. [current] son
  /// alansa (ya da sırada değilse) odak değişmez, `false` döner: çağıran
  /// formu gönderir.
  bool focusNext(F current) {
    final index = focusOrder.indexOf(current);
    if (index < 0 || index >= focusOrder.length - 1) return false;
    focusNodeOf(focusOrder[index + 1]).requestFocus();
    return true;
  }

  /// Odağı [focusOrder] sırasındaki ilk hatalı alana taşır ve o alanı
  /// döndürür (odaklanan metin alanı kendini görünür alana kaydırır).
  /// [errors] içinde sıradaki alanlardan hiçbiri yoksa odak değişmez, `null`
  /// döner.
  F? focusFirstError(Map<F, Object?> errors) {
    for (final field in focusOrder) {
      if (!errors.containsKey(field)) continue;
      focusNodeOf(field).requestFocus();
      return field;
    }
    return null;
  }

  /// Klavyeyi kapatır (odaktaki alanın odağını bırakır).
  void unfocusAll() => FocusManager.instance.primaryFocus?.unfocus();

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _focusNodes.clear();
    super.dispose();
  }
}
