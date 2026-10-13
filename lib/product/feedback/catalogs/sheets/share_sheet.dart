import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-15'te seçilen paylaşım yolu — sayfanın `pop` değeri.
enum ShareChoice {
  /// "Bağlantıyı kopyala" (`SHT-15.copyLink`): çağıran bağlantıyı panoya
  /// kopyalar (`ShareService.copyText`) ve TST-35 gösterir.
  copyLink('copyLink'),

  /// "WhatsApp" (`SHT-15.whatsapp`): çağıran [ShareLinks.whatsApp] adresini
  /// harici bağlantı onayıyla (DLG-32) açar.
  whatsapp('whatsapp'),

  /// "E-posta" (`SHT-15.email`): çağıran [ShareLinks.email] adresini harici
  /// bağlantı onayıyla (DLG-32) açar.
  email('email'),

  /// "Diğer…" (`SHT-15.other`): çağıran sistem paylaşım menüsünü açar
  /// (`ShareService.shareText`; prototipteki TST-58 demo toast'ı uygulanmaz —
  /// K-02).
  other('other');

  const ShareChoice(this.action);

  /// Aksiyon adı (`SHT-15.<action>`).
  final String action;
}

/// SHT-15 hedeflerinin harici adresleri (prototip `sheets.js:76`).
abstract final class ShareLinks {
  static const String _httpsScheme = 'https';
  static const String _mailScheme = 'mailto';
  static const String _whatsAppHost = 'wa.me';
  static const String _textParameter = 'text';
  static const String _subjectParameter = 'subject';

  /// WhatsApp'ta [url] bağlantısını ileti metni olarak açan adres
  /// (`https://wa.me/?text=<url>`).
  static Uri whatsApp(String url) => Uri(
    scheme: _httpsScheme,
    host: _whatsAppHost,
    path: '/',
    query: '$_textParameter=${Uri.encodeComponent(url)}',
  );

  /// Konusu [subject] olan boş e-posta taslağını açan adres
  /// (`mailto:?subject=<başlık>`).
  static Uri email(String subject) => Uri(
    scheme: _mailScheme,
    query: '$_subjectParameter=${Uri.encodeComponent(subject)}',
  );

  /// [url]'in şemasız, ekranda gösterilen biçimi
  /// (`kulupler.gumushane.edu.tr/clubs/c01`).
  static String display(String url) {
    final scheme = Uri.tryParse(url)?.scheme ?? '';
    final prefix = '$scheme$_schemeSeparator';
    return scheme.isNotEmpty && url.startsWith(prefix)
        ? url.substring(prefix.length)
        : url;
  }

  static const String _schemeSeparator = '://';
}

/// SHT-15 "Paylaş" — paylaşılan öğenin özeti + dört paylaşım yolu (prototip
/// `SHEETS['SHT-15']`, `sheets.js:74–76`). CLB-03 (kulüp), EVT-02 (etkinlik),
/// gönderi kartı ve SHT-34 açar.
///
/// * Çerçeve menü biçimindedir (`menu`, `flush`). Üstte 16 dp iç boşluklu
///   soluk kart: [title] (`labelL`, `text.heading`, en çok iki satır) ve
///   şemasız [url] (`caption`, tek satır, `…`).
/// * Satırlar `GuTile` + 22 dp ikon: "Bağlantıyı kopyala" (`link`),
///   "WhatsApp" (`message-circle`), "E-posta" (`mail`), "Diğer…"
///   (`more-horizontal`).
/// * Dokunma sayfayı seçimle kapatır (`pop(ShareChoice)`); X / scrim /
///   sürükleme / geri → `null`. Kopyalama, harici bağlantı onayı (DLG-32),
///   sistem paylaşımı ve TST-35 çağıranın (ViewModel) işidir.
/// * Anahtarlar `SHT-15.copyLink`, `SHT-15.whatsapp`, `SHT-15.email`,
///   `SHT-15.other`, `SHT-15.close` (+ `SHT-15.scrim`, `FeedbackService`).
///
/// ```dart
/// final choice = await feedback.showSheet<ShareChoice>(
///   SheetId.sht15,
///   builder: (_) => ShareSheet(title: club.name, url: viewModel.shareUrl()),
/// );
/// ```
///
/// Design: SHT-15
class ShareSheet extends StatelessWidget {
  /// [title] başlıklı öğenin [url] bağlantısını paylaşma menüsü.
  const ShareSheet({required this.title, required this.url, super.key});

  /// Paylaşılan öğenin adı (kulüp adı, etkinlik başlığı, gönderi metni).
  final String title;

  /// Paylaşılan tam bağlantı (`AppConstants.shareBaseUrl` + yol).
  final String url;

  /// Marka adı — çevrilmez (prototip `sheets.js:76` düz metin).
  static const String whatsAppLabel = 'WhatsApp';

  /// [choice] satırının anahtarı (`SHT-15.<action>`).
  static Key keyOf(ShareChoice choice) =>
      FeedbackKeys.of(SheetId.sht15.designId, choice.action);

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final colors = gu.colors;

    Widget row(
      ShareChoice choice, {
      required GuIcons icon,
      required String label,
    }) => GuTile(
      key: keyOf(choice),
      title: label,
      leading: GuIcon(icon, size: GuSizes.icon22, color: colors.textHeading),
      onTap: () => Navigator.of(context).pop(choice),
    );

    return GuSheetFrame(
      title: l10n.sht15Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: FeedbackKeys.of(SheetId.sht15.designId, 'close'),
      menu: true,
      flush: true,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // `.px16.pb16` + `Card muted .card-body.col.gap4` (sheets.js:76).
          Padding(
            padding: GuInsets.only(
              left: GuSpacing.s16,
              right: GuSpacing.s16,
              bottom: GuSpacing.s16,
            ),
            child: GuCard(
              muted: true,
              padding: GuCard.bodyPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: GuSpacing.s4,
                children: [
                  Text(
                    title,
                    style: gu.text.labelL.copyWith(color: colors.textHeading),
                    maxLines: _titleMaxLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    ShareLinks.display(url),
                    style: gu.text.caption,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          row(
            ShareChoice.copyLink,
            icon: GuIcons.link,
            label: l10n.sht08CopyLink,
          ),
          row(
            ShareChoice.whatsapp,
            icon: GuIcons.messageCircle,
            label: whatsAppLabel,
          ),
          row(ShareChoice.email, icon: GuIcons.mail, label: l10n.authEmail),
          row(
            ShareChoice.other,
            icon: GuIcons.moreHorizontal,
            label: l10n.sht15Other,
          ),
        ],
      ),
    );
  }

  /// `.clamp2` (css:104).
  static const int _titleMaxLines = 2;
}
