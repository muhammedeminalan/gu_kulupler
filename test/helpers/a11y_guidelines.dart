// Erişilebilirlik yönergeleri (T-43 denetimi, D-22).
//
// `expectA11yGuidelines(tester)` ekranın o anki karesinde Flutter
// yönergelerini birlikte değerlendirir ve tüm ihlalleri tek iletide toplar:
//  * `labeledTapTargetGuideline` — dokunulabilir her düğümün etiketi / ipucu
//    olmalı,
//  * 44 × 44 dokunma hedefi (`iOSTapTargetGuideline` ölçüsü; D-22
//    `GuTapTarget`) — bağlantı (`isLink`) düğümleri yönerge gereği muaf,
//  * `textContrastGuideline` (AA 4.5 / büyük metin 3.0) — T-45'te varsayılan
//    açık ([contrast]; K-91 ile `textMuted/bgSurfaceMuted` 4.61 oldu).
//
// Tasarım gereği küçük hedefler (ör. satır içi metin bağlantısı) etiketleriyle
// [smallTargetLabels]'a, tasarım kaynaklı ya da yanlış pozitif kontrast
// bulguları [lowContrastLabels]'a gerekçeli verilir; rapor:
// `docs/reports/T-43-audit.md` (C-1 … C-3).
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// D-22 asgari dokunma hedefi (iOS 44 pt; Android 48 dp `GuTapTarget`
/// platform ölçüsüyle ayrıca sağlanır).
const Size kA11yMinTapTarget = Size(44, 44);

/// Ekranın o anki karesinde etiketli dokunma hedefi + 44 dp hedef + metin
/// kontrastı yönergelerini doğrular.
///
/// [smallTargetLabels]: tasarım gereği 44 dp altında kalabilen düğümlerin
/// semantik etiketleri (tam eşleşme; gerekçe çağrı yerinde yorumla yazılır).
/// [lowContrastLabels]: kontrast denetiminden muaf düğüm etiketleri (tam
/// eşleşme; gerekçe çağrı yerinde). [contrast] `false` → kontrast hiç
/// denetlenmez.
Future<void> expectA11yGuidelines(
  WidgetTester tester, {
  bool contrast = true,
  Set<String> smallTargetLabels = const {},
  Set<String> lowContrastLabels = const {},
}) async {
  final handle = tester.ensureSemantics();
  try {
    await tester.pump();
    final guidelines = <AccessibilityGuideline>[
      labeledTapTargetGuideline,
      _TapTargetGuideline(smallTargetLabels),
      if (contrast) _TextContrastGuideline(lowContrastLabels),
    ];
    final failures = <String>[];
    for (final guideline in guidelines) {
      final result = await guideline.evaluate(tester);
      if (!result.passed) {
        failures.add('${guideline.description}:\n${result.reason}');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  } finally {
    handle.dispose();
  }
}

/// `iOSTapTargetGuideline` + etiketle muafiyet.
final class _TapTargetGuideline extends MinimumTapTargetGuideline {
  const _TapTargetGuideline(this.exemptLabels)
    : super(
        size: kA11yMinTapTarget,
        link:
            'https://developer.apple.com/design/human-interface-guidelines/'
            'accessibility#Buttons-and-controls',
      );

  final Set<String> exemptLabels;

  @override
  bool shouldSkipNode(SemanticsNode node) {
    if (super.shouldSkipNode(node)) return true;
    final label = node.getSemanticsData().label;
    return label.isNotEmpty && exemptLabels.contains(label);
  }
}

/// `textContrastGuideline` + etiketle muafiyet.
final class _TextContrastGuideline extends MinimumTextContrastGuideline {
  const _TextContrastGuideline(this.exemptLabels);

  final Set<String> exemptLabels;

  @override
  bool shouldSkipNode(SemanticsData data) =>
      super.shouldSkipNode(data) ||
      (data.label.isNotEmpty && exemptLabels.contains(data.label));
}
