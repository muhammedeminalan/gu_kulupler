import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/system/view/widget/system_screen_scaffold.dart';
import 'package:gu_ui/gu_ui.dart';

/// "İçerik yok" ekranı — prototip `NotFound` (`screens-auth.js:40`):
/// bilinmeyen yol, silinmiş / gizlenmiş içerik ve geçersiz yol parametresi
/// (K-06) burada biter.
///
/// "Geri" (çubuk ve düğme): yığında sayfa varsa geri, yoksa ana sayfa.
/// "Ana sayfaya dön": ana sayfa.
///
/// Design: SYS-04
class NotFoundView extends ConsumerWidget {
  /// "İçerik yok" ekranı.
  const NotFoundView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SystemScreenScaffold(
      backActionKey: GuKey.action('SYS-04.back'),
      child: GuEmptyState.body(
        illustration: GuIllustrations.locked,
        title: l10n.sysNotFoundTitle,
        description: l10n.sysNotFoundDesc,
        actions: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: GuSpacing.s8,
          runSpacing: GuSpacing.s8,
          children: [
            GuButton(
              key: GuKey.action('SYS-04.back'),
              label: l10n.commonBack,
              variant: GuButtonVariant.outline,
              onPressed: () => SystemScreenScaffold.leave(context),
            ),
            GuButton(
              key: GuKey.action('SYS-04.home'),
              label: l10n.sysErrorHome,
              onPressed: () => SystemScreenScaffold.goHome(context),
            ),
          ],
        ),
      ),
    );
  }
}
