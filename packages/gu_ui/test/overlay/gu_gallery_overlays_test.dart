// T-07 · overlay çerçeveleri galeri golden'ı
// (`gu_gallery_overlays__default__*.png`): GuSheetFrame (standart + footer),
// GuDialogFrame (normal + danger), GuPopMenu.
// Referans: `ds_overlays.webp` (SHT-05 footer'lı sheet, DLG-08 danger dialog),
// `sheets/SHT-01` (flush seçenek listesi), `dialogs/DLG-25` (marka ikonu + üç
// eylem); menü için yakalama yok → css:279–280 (CD-83).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/overlay/gu_dialog_frame.dart';
import 'package:gu_ui/src/overlay/gu_pop_menu.dart';
import 'package:gu_ui/src/overlay/gu_sheet_frame.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/widgets/inputs/gu_option_row.dart';
import 'package:gu_ui/src/widgets/primitives/gu_button.dart';

import '../helpers/golden_helper.dart';

void _noop() {}

class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s16,
      children: [
        // SHT-01: standart + flush gövde.
        const GuSheetFrame(
          title: 'Dil',
          closeSemanticLabel: 'Kapat',
          flush: true,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GuOptionRow(
                label: 'Türkçe',
                sub: 'TR',
                selected: true,
                onTap: _noop,
              ),
              GuOptionRow(
                label: 'English',
                sub: 'EN',
                selected: false,
                onTap: _noop,
              ),
            ],
          ),
        ),
        // ds_overlays / SHT-05: gövde + footer.
        GuSheetFrame(
          title: 'Katılma başvurusu',
          closeSemanticLabel: 'Kapat',
          footer: const [GuButton(label: 'Başvuruyu gönder', onPressed: _noop)],
          body: Text(
            'Adın, bölümün ve sınıfın kulüp yönetimiyle paylaşılır.',
            style: gu.text.bodyS.copyWith(color: gu.colors.textSecondary),
          ),
        ),
        // DLG-25: marka ikonu + üç eylem.
        const GuDialogFrame(
          title: 'Değişiklikler kaydedilmedi',
          body: 'Çıkarsan yaptığın değişiklikler kaybolacak.',
          icon: GuIcons.triangleAlert,
          actions: [
            GuButton(label: 'Kaydet', onPressed: _noop),
            GuButton(
              label: 'Kaydetmeden çık',
              variant: GuButtonVariant.dangerOutline,
              onPressed: _noop,
            ),
            GuButton(
              label: 'Düzenlemeye devam et',
              variant: GuButtonVariant.text,
              onPressed: _noop,
            ),
          ],
        ),
        // ds_overlays / DLG-08: danger.
        const GuDialogFrame(
          title: 'Kulüpten ayrıl?',
          body:
              'Doğa Sporları üyeliğin sona erecek ve gönderileri '
              'göremeyeceksin. Tekrar katılmak için yeniden başvurman '
              'gerekebilir.',
          icon: GuIcons.logOut,
          danger: true,
          actions: [
            GuButton(
              label: 'Kulüpten ayrıl',
              variant: GuButtonVariant.danger,
              onPressed: _noop,
            ),
            GuButton(
              label: 'Vazgeç',
              variant: GuButtonVariant.text,
              onPressed: _noop,
            ),
          ],
        ),
        // EVT-MENU (sheets.js:12) + durumlar: seçili, devre dışı, danger.
        const Align(
          alignment: Alignment.centerRight,
          child: GuPopMenu(
            items: [
              GuPopMenuItem(
                label: 'Hatırlatıcı',
                icon: GuIcons.bellRing,
                onTap: _noop,
              ),
              GuPopMenuItem(
                label: 'Takvime ekle',
                icon: GuIcons.calendarPlus,
                selected: true,
                onTap: _noop,
              ),
              GuPopMenuItem(
                label: 'Paylaş',
                icon: GuIcons.share2,
                disabled: true,
                onTap: _noop,
              ),
              GuPopMenuItem(
                label: 'Şikâyet et',
                icon: GuIcons.flag,
                danger: true,
                onTap: _noop,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

void main() {
  testWidgets('T-07 · overlay çerçeveleri · galeri golden (açık + koyu)', (
    tester,
  ) async {
    // 390 dp içerik genişliği (çerçeve dolgusu 2 × 16): sheet 390, dialog 320.
    await goldenForWidget(tester, 'gu_gallery_overlays', {
      'default': const _Gallery(),
    }, size: const Size(422, 1400));
  });
}
