import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/format/time_of_day_value.dart';
import 'package:gu_ui/gu_ui.dart';

/// NTF-02 sessiz saat aralığı — "Sessiz saatler" açıkken kartın altında
/// ayırıcı + `row gap12 p16` iki `Picker` ("Başlangıç" / "Bitiş", `clock`
/// ikonu; `screens-events.js:117`). Dokunma SHT-29 açar (çağıran,
/// `FeedbackService`).
///
/// Anahtarlar çağırandan: [fromKey] (`NTF-02.quietFrom`), [toKey]
/// (`NTF-02.quietTo`).
class QuietHoursPicker extends StatelessWidget {
  /// [from]–[to] aralığı.
  const QuietHoursPicker({
    required this.from,
    required this.to,
    required this.onPickFrom,
    required this.onPickTo,
    required this.fromKey,
    required this.toKey,
    super.key,
  });

  /// Başlangıç (`settings.quietFrom`).
  final TimeOfDayValue from;

  /// Bitiş (`settings.quietTo`).
  final TimeOfDayValue to;

  /// "Başlangıç" seçicisine dokunma (SHT-29).
  final VoidCallback onPickFrom;

  /// "Bitiş" seçicisine dokunma (SHT-29).
  final VoidCallback onPickTo;

  /// "Başlangıç" anahtarı.
  final Key fromKey;

  /// "Bitiş" anahtarı.
  final Key toKey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // `<div class="divider" /><div class="row gap12 p16">` + iki `flex1`
    // `Picker` (screens-events.js:117).
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GuDivider(),
        Padding(
          padding: GuInsets.all16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: GuSpacing.s12,
            children: [
              Expanded(
                child: GuPickerField(
                  actionKey: fromKey,
                  label: l10n.notifPrefsQuietFrom,
                  value: from.hhmm,
                  icon: GuIcons.clock,
                  onTap: onPickFrom,
                ),
              ),
              Expanded(
                child: GuPickerField(
                  actionKey: toKey,
                  label: l10n.notifPrefsQuietTo,
                  value: to.hhmm,
                  icon: GuIcons.clock,
                  onTap: onPickTo,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
