import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_ui/gu_ui.dart';

/// AUT-02 yasal onay satırı — onay kutusu + "KVKK Aydınlatma Metni ve
/// Gizlilik Politikası metinlerini okudum, kabul ediyorum." cümlesi
/// (`screens-auth.js:101`).
///
/// Tek kutu iki metni birlikte kabul eder; metin adları AUT-06'yı açan
/// bağlantılardır (`GuLinkText`: alt alta düşen bağlantılar birbirinin
/// dokunuşunu çalmaz). Kutu cümlenin ilk satırına 2 px üst boşlukla hizalanır,
/// aralık 12; [errorText] verilirse altında alan hatası satırı çizilir
/// (aralık 6, `GuField`).
///
/// Anahtarlar çağıran ekrandan gelir (CD-111).
class RegisterLegalConsent extends StatelessWidget {
  /// Yasal onay satırı.
  const RegisterLegalConsent({
    required this.value,
    required this.onChanged,
    required this.onOpenKvkk,
    required this.onOpenPrivacy,
    required this.checkboxKey,
    required this.kvkkKey,
    required this.privacyKey,
    this.errorText,
    super.key,
  });

  /// Onay verildi mi.
  final bool value;

  /// Kutuya dokunuldu (yeni değerle).
  final ValueChanged<bool> onChanged;

  /// "KVKK Aydınlatma Metni" bağlantısı.
  final VoidCallback onOpenKvkk;

  /// "Gizlilik Politikası" bağlantısı.
  final VoidCallback onOpenPrivacy;

  /// Onay kutusunun aksiyon anahtarı.
  final Key checkboxKey;

  /// KVKK bağlantısının aksiyon anahtarı.
  final Key kvkkKey;

  /// Gizlilik bağlantısının aksiyon anahtarı.
  final Key privacyKey;

  /// Onay verilmeden gönderim denendiğinde gösterilen hata.
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    return GuField(
      errorText: errorText,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: GuSpacing.s12,
        children: [
          Padding(
            padding: GuInsets.only(top: GuSpacing.s2),
            child: GuCheckbox(
              key: checkboxKey,
              value: value,
              onChanged: onChanged,
              semanticLabel: l10n.authLegalCheck,
            ),
          ),
          Expanded(
            child: GuLinkText(
              style: gu.text.bodyS.copyWith(color: gu.colors.textSecondary),
              spans: [
                GuLinkSpan.link(
                  l10n.legalKvkkTitle,
                  actionKey: kvkkKey,
                  onTap: onOpenKvkk,
                ),
                GuLinkSpan.text(' ${l10n.commonAnd} '),
                GuLinkSpan.link(
                  l10n.legalGizlilikTitle,
                  actionKey: privacyKey,
                  onTap: onOpenPrivacy,
                ),
                GuLinkSpan.text(' ${l10n.authLegalCheck}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
