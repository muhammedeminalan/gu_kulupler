// K-93 · Formlu kaydırmalarda klavye (gerçek cihaz turu, kullanıcı kararı —
// madde 3): kaydırma sürüklenince klavye kapanır (`GuFormScrollView` —
// yalnızca sayfanın kendi kaydırması; çok satırlı alanın iç kaydırması
// kapatmaz, `gu_form_scroll_view_test.dart`). Alanın dışına dokunma
// `GuInput`'ta sınanır (`gu_input_keyboard_test.dart`); burada sürükleme
// alanın üstünden başlar (alan içi dokunma odağı bırakmaz → kapanmayı yalnız
// sürükleme açıklar).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/features/auth/view/login_view.dart';
import 'package:gu_kulupler/features/auth/view/register_view.dart';
import 'package:gu_kulupler/features/auth/view/reset_password_view.dart';
import 'package:gu_ui/gu_ui.dart';

import '../helpers/pump_app.dart';

/// Dar, kısa yüzey + büyük metin: içerik taşar, kaydırılabilir.
const double _width = 320;
const double _scale = 1.6;

/// Metin alanı içeren form kaydırmaları (`GuFormScrollView`).
const List<String> _formViews = [
  'lib/features/admin/view/admin_club_form_view.dart',
  'lib/features/auth/view/login_view.dart',
  'lib/features/auth/view/register_view.dart',
  'lib/features/auth/view/reset_password_view.dart',
  'lib/features/clubs/view/club_application_view.dart',
  'lib/features/feed/view/compose_view.dart',
  'lib/features/management/view/club_settings_view.dart',
  'lib/features/management/view/event_form_view.dart',
  'lib/features/profile/view/edit_profile_view.dart',
  'lib/features/settings/view/delete_account_view.dart',
  'lib/features/settings/view/support_view.dart',
];

FocusNode _focusOf(WidgetTester tester, Key key) => tester
    .widget<EditableText>(
      find.descendant(of: find.byKey(key), matching: find.byType(EditableText)),
    )
    .focusNode;

void main() {
  group('K-93 · form kaydırması · sürükleme klavyeyi kapatır', () {
    // (ekran, alan, yükseklik): içerik taşsın, alan ilk karede görünsün.
    final screens = <String, (Widget, Key, double)>{
      'AUT-01': (const LoginView(), GuKey.action('AUT-01.email'), 480),
      'AUT-02': (const RegisterView(), GuKey.action('AUT-02.email'), 480),
      'AUT-04': (
        const ResetPasswordView(),
        GuKey.action('AUT-04.email'),
        320,
      ),
    };
    for (final MapEntry(key: id, value: (view, field, height))
        in screens.entries) {
      testWidgets('$id: alanın üstünden sürükleme → odak kalkar', (
        tester,
      ) async {
        await tester.pumpApp(
          view,
          size: Size(_width, height),
          textScale: _scale,
        );
        await tester.pump();
        // Kaydırma başta (0); içerik taşar → yukarı sürükleme kaydırır.
        final scroll = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(GuFormScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(scroll.position.pixels, 0);
        expect(scroll.position.maxScrollExtent, greaterThan(0));
        await tester.tap(find.byKey(field));
        await tester.pump();
        expect(_focusOf(tester, field).hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);

        await tester.drag(find.byKey(field), const Offset(0, -120));
        await tester.pump();
        expect(scroll.position.pixels, greaterThan(0));
        expect(_focusOf(tester, field).hasFocus, isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
        expect(tester.takeException(), isNull);
      });
    }

    test('metin alanlı form kaydırmaları GuFormScrollView ile kurulur', () {
      for (final path in _formViews) {
        final source = File(path).readAsStringSync();
        expect(source, contains('GuFormScrollView('), reason: path);
        // Flutter `onDrag` iç kaydırmada (çok satırlı alan) klavyeyi
        // kapatır — kullanılmaz.
        expect(
          source,
          isNot(contains('ScrollViewKeyboardDismissBehavior.onDrag')),
          reason: path,
        );
      }
    });
  });
}
