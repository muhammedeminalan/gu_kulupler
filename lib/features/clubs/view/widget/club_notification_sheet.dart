import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/clubs/provider/club_notification_prefs_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_notification_prefs_view_model.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-07 "Kulüp bildirimleri" — tek kulübün bildirim tercihleri (prototip
/// `SHEETS['SHT-07']`, `sheets.js:37–38`). SHT-06 "Bildirimleri yönet" açar.
///
/// * Gövde: kulüp adı ([clubName]), üç tür anahtarı (duyurular, yeni
///   etkinlikler, yeni gönderiler), ayraç, "Tümünü sessize al".
/// * Her dokunuş `ClubNotificationPrefsViewModel.toggle`'a gider (iyimser;
///   başarı TST-38, çevrimdışı / ağ hatası TST-24 + geri alma). Kaydet
///   düğmesi yoktur.
/// * "Tümünü sessize al" açıkken üç tür kapalı ve devre dışı görünür;
///   dokunmak TST-X16'yı gösterir.
/// * Tercihler okunurken iskelet, okunamazsa hata + "Yeniden dene" çizilir;
///   yazım sunucuda reddedilirse listenin altında hata satırı çıkar.
/// * Anahtarlar `SHT-07.toggle.announcements`, `.toggle.events`,
///   `.toggle.posts`, `.toggle.muted`, `SHT-07.close` (+ `SHT-07.scrim`,
///   `FeedbackService`; hata durumunda `SHT-07.retry`).
///
/// ```dart
/// feedback.showSheet<void>(
///   SheetId.sht07,
///   builder: (_) =>
///       ClubNotificationSheet(clubId: club.id, clubName: club.name),
/// );
/// ```
///
/// Design: SHT-07
class ClubNotificationSheet extends ConsumerWidget {
  /// [clubId] kulübünün bildirim tercihleri; üst satırda [clubName].
  const ClubNotificationSheet({
    required this.clubId,
    this.clubName,
    super.key,
  });

  /// Tercihleri düzenlenen kulübün kimliği
  /// (`ClubNotificationPrefsViewModel` ailesi).
  final String clubId;

  /// Başlığın altında gösterilen kulüp adı; verilmezse satır çizilmez.
  final String? clubName;

  /// [key] anahtarının görünen adı.
  static String labelOf(AppLocalizations l10n, ClubPrefKey key) =>
      switch (key) {
        ClubPrefKey.announcements => l10n.sht07Announcements,
        ClubPrefKey.events => l10n.sht07Events,
        ClubPrefKey.posts => l10n.sht07Posts,
        ClubPrefKey.muted => l10n.sht07MuteAll,
      };

  /// [key] satırının ikonu (`sheets.js:38`).
  static GuIcons iconOf(ClubPrefKey key) => switch (key) {
    ClubPrefKey.announcements => GuIcons.megaphone,
    ClubPrefKey.events => GuIcons.calendarPlus,
    ClubPrefKey.posts => GuIcons.fileText,
    ClubPrefKey.muted => GuIcons.bellOff,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gu = context.gu;
    final l10n = context.l10n;
    final colors = gu.colors;
    final provider = clubNotificationPrefsViewModelProvider(clubId);
    final state = ref.watch(provider);
    final viewModel = ref.read(provider.notifier);
    final name = clubName;

    // `.tile.is-plain` + satır içi `padding-left:0;padding-right:0`
    // (sheets.js:38): gövde `flush`, satır kendi yatay dolgusunu (16) taşır →
    // içerik gövde dolgulu sayfadakiyle aynı hizadadır.
    Widget row(ClubPrefKey key) {
      final value = state.valueOf(key);
      final label = labelOf(l10n, key);
      return GuTile(
        title: label,
        leading: GuIcon(
          iconOf(key),
          size: GuSizes.icon20,
          color: key == ClubPrefKey.muted
              ? colors.stateDanger
              : colors.textMuted,
        ),
        trailing: GuSwitch(
          key: GuKey.action('SHT-07.toggle.${key.name}'),
          value: value,
          semanticLabel: label,
          disabled: state.isLocked(key),
          onChanged: (next) => viewModel.toggle(key, value: next),
          onDisabledPressed: () => viewModel.toggle(key, value: !value),
        ),
      );
    }

    final Widget content;
    if (!state.isLoaded && state.isError) {
      content = GuErrorState(
        title: l10n.sysErrorTitle,
        description: l10n.sysErrorDesc,
        retryLabel: l10n.commonRetry,
        retryActionKey: GuKey.action('SHT-07.retry'),
        inline: true,
        onRetry: viewModel.load,
      );
    } else if (!state.isLoaded) {
      content = GuSkeletonList(semanticLabel: l10n.commonLoading);
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(ClubPrefKey.announcements),
          row(ClubPrefKey.events),
          row(ClubPrefKey.posts),
          GuDivider(margin: GuInsets.sym(h: GuSizes.sheetBodyPaddingX)),
          row(ClubPrefKey.muted),
          if (state.isError)
            Padding(
              padding: GuInsets.sym(h: GuSizes.sheetBodyPaddingX),
              child: GuField(
                errorText: l10n.sysErrorTitle,
                child: const SizedBox.shrink(),
              ),
            ),
        ],
      );
    }

    return GuSheetFrame(
      title: l10n.sht07Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: GuKey.action('SHT-07.close'),
      flush: true,
      body: Padding(
        // `flush` alt dolgusu 8; `.sheet-body` 16 ister.
        padding: GuInsets.only(
          bottom:
              GuSizes.sheetBodyPaddingBottom -
              GuSizes.sheetBodyFlushPaddingBottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (name != null)
              // `<p class="t-caption pb16">` (sheets.js:38).
              Padding(
                padding: GuInsets.only(
                  left: GuSizes.sheetBodyPaddingX,
                  right: GuSizes.sheetBodyPaddingX,
                  bottom: GuSpacing.s16,
                ),
                child: Text(name, style: gu.text.caption),
              ),
            content,
          ],
        ),
      ),
    );
  }
}
