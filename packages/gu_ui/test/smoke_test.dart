import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('T-00 · gu_ui workspace', () {
    testWidgets('flutter_svg bağımlılığı çözülür (SvgPicture)', (tester) async {
      const svg =
          '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>';
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SvgPicture.string(svg),
        ),
      );
      expect(find.byType(SvgPicture), findsOneWidget);
    });
  });
}
