// T-05 · seçim grubu galeri golden'ı (`gu_gallery_selection__default__*.png`):
// GuCheckbox, GuRadio, GuSwitch, GuOptionRow, GuOptionCard.
// Referans: `ds_selection.webp` (üst sıra: onay kutusu açık / kapalı /
// disabled, radyo açık / kapalı, anahtar açık / kapalı / disabled),
// `sheets/SHT-04` + `SHT-01` (seçenek satırları), `sheets/SHT-22` (rol
// kartları), `sheets/SHT-17` (tema kartları).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/golden_helper.dart';

void _noop() {}

void _noopBool(bool _) {}

class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final colors = gu.colors;

    Widget roleCard({
      required bool selected,
      required GuRoleBadgeKind kind,
      required String label,
      required String description,
    }) => GuOptionCard(
      selected: selected,
      onTap: _noop,
      leading: ExcludeSemantics(
        child: GuRadio(
          selected: selected,
          onSelected: null,
          semanticLabel: label,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: GuSpacing.s4,
        children: [
          GuRoleBadge(kind: kind, label: label),
          Text(
            description,
            style: gu.text.bodyS.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );

    Widget themeCard({required bool selected, required String label}) =>
        Expanded(
          child: GuOptionCard(
            selected: selected,
            onTap: _noop,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: GuSpacing.s8,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.bgCanvas,
                    borderRadius: GuRadius.borderSkeleton,
                    border: Border.all(color: colors.borderDefault),
                  ),
                  child: const SizedBox(height: GuSpacing.s48),
                ),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: gu.text.labelM.copyWith(color: colors.textHeading),
                ),
              ],
            ),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s12,
      children: [
        // ds_selection üst sıra (aralık 16).
        const Wrap(
          spacing: GuSpacing.s16,
          runSpacing: GuSpacing.s16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            GuCheckbox(value: true, semanticLabel: 'on', onChanged: _noopBool),
            GuCheckbox(
              value: false,
              semanticLabel: 'off',
              onChanged: _noopBool,
            ),
            GuCheckbox(
              value: true,
              disabled: true,
              semanticLabel: 'disabled',
              onChanged: _noopBool,
            ),
            GuRadio(selected: true, semanticLabel: 'on', onSelected: _noop),
            GuRadio(selected: false, semanticLabel: 'off', onSelected: _noop),
            GuSwitch(value: true, semanticLabel: 'on', onChanged: _noopBool),
            GuSwitch(value: false, semanticLabel: 'off', onChanged: _noopBool),
            GuSwitch(
              value: true,
              disabled: true,
              semanticLabel: 'disabled',
              onChanged: _noopBool,
            ),
          ],
        ),
        // SHT-04 "Sırala" + SHT-01 (sub) + SHT-30 (leading) + onay kutulu +
        // disabled; sheet zemini bg.surfaceRaised.
        ColoredBox(
          color: colors.bgSurfaceRaised,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GuOptionRow(label: 'Popüler', selected: true, onTap: _noop),
              GuOptionRow(label: 'Yeni eklenen', selected: false, onTap: _noop),
              GuOptionRow(
                label: 'Türkçe',
                sub: 'TR',
                selected: true,
                onTap: _noop,
              ),
              GuOptionRow(
                label: 'Merkez Kampüs Konferans Salonu',
                selected: false,
                leading: GuIcon(GuIcons.mapPin, size: GuSizes.icon18),
                onTap: _noop,
              ),
              GuOptionRow(
                label: 'Teknoloji',
                selected: true,
                control: GuOptionControl.checkbox,
                onTap: _noop,
              ),
              GuOptionRow(
                label: 'Başvurular kapalı',
                selected: false,
                disabled: true,
                onTap: _noop,
              ),
            ],
          ),
        ),
        // SHT-22 rol kartları (aralık 8).
        roleCard(
          selected: true,
          kind: GuRoleBadgeKind.member,
          label: 'Üye',
          description: 'Gönderileri görür, yorum yapar, etkinliklere katılır.',
        ),
        roleCard(
          selected: false,
          kind: GuRoleBadgeKind.board,
          label: 'Yönetim Kurulu',
          description:
              'Gönderi ve etkinlik oluşturur, başvuruları onaylar, duyuru '
              'gönderir.',
        ),
        // SHT-17 tema kartları (3'lü ızgara, aralık 8).
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: GuSpacing.s8,
            children: [
              themeCard(selected: false, label: 'Sistem'),
              themeCard(selected: true, label: 'Açık'),
              themeCard(selected: false, label: 'Koyu'),
            ],
          ),
        ),
      ],
    );
  }
}

void main() {
  testWidgets('T-05 · seçim galerisi · golden (açık + koyu)', (tester) async {
    await goldenForWidget(tester, 'gu_gallery_selection', {
      'default': const _Gallery(),
    });
    expect(tester.takeException(), isNull);
  });
}
