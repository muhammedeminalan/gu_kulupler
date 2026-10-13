import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-08'de seçilen öğe — sayfanın `pop` değeri. Sıra tasarımdaki satır
/// sırasıdır (`sheets.js:41–43`).
enum PostMenuAction {
  /// "Kaydet" (`SHT-08.save`) → TST-11.
  save('save', GuIcons.bookmark),

  /// "Kaydı kaldır" (aynı satır, `SHT-08.save`; gönderi kayıtlıyken) →
  /// TST-11.
  unsave('save', GuIcons.bookmark),

  /// "Paylaş" (`SHT-08.share`) → SHT-15.
  share('share', GuIcons.share2),

  /// "Bağlantıyı kopyala" (`SHT-08.copyLink`) → TST-35.
  copyLink('copyLink', GuIcons.link),

  /// "Şikayet et" (`SHT-08.report`) → SHT-10.
  report('report', GuIcons.flag),

  /// "Kullanıcıyı engelle" (`SHT-08.block`) → DLG-13.
  blockAuthor('block', GuIcons.ban),

  /// "Düzenle" (`SHT-08.edit`) → FED-03 düzenleme kipi (W-25, T-21).
  edit('edit', GuIcons.pencil),

  /// "Sabitle" (`SHT-08.pin`) → TST-53.
  pin('pin', GuIcons.pin),

  /// "Sabitlemeyi kaldır" (aynı satır, `SHT-08.pin`; gönderi sabitken) →
  /// TST-53.
  unpin('pin', GuIcons.pinOff),

  /// "Sil" (`SHT-08.delete`) → DLG-10.
  remove('delete', GuIcons.trash2);

  const PostMenuAction(this.action, this.icon);

  /// Aksiyon adı (`SHT-08.<action>`).
  final String action;

  /// Satırın ikonu.
  final GuIcons icon;

  /// Yıkıcı satır mı (kırmızı ikon + metin): yalnızca "Sil".
  bool get isDanger => this == remove;

  /// Yönetim satırı mı ("Düzenle", "Sabitle", "Sil"): ilkinin üstünde ayraç
  /// çizilir (`sheets.js:43` `.divider`).
  bool get isManagement =>
      this == edit || this == pin || this == unpin || this == remove;
}

/// "Gönderi" menüsü — prototip `SHEETS['SHT-08']` (`sheets.js:40–43`).
/// FED-01, FED-02 (ve MGT-08) `PostCard` "…" düğmesinden açılır.
///
/// * Satırlar [actionsFor] ile süzülür: "Şikayet et" ve "Kullanıcıyı engelle"
///   yalnızca başkasının gönderisinde; "Sabitle" ve "Sil" yalnızca içerik
///   yönetebilen (yönetim / süper admin) için; "Düzenle" yalnızca gönderinin
///   **yazarı olan** yönetici için (CD-141 (5): düzenleme `yazar &&
///   yönetici`).
/// * Sayfa hiçbir şey yürütmez: dokunulan satır [PostMenuAction] olarak döner
///   (`pop`); eylemi çağıran başlatır (`PostActionsMixin.handlePostMenu`).
///   X / scrim / sürükleme / geri → `null`.
/// * Anahtarlar `SHT-08.save`, `.share`, `.copyLink`, `.report`, `.block`,
///   `.edit`, `.pin`, `.delete`, `SHT-08.close` (+ `SHT-08.scrim`,
///   `FeedbackService`).
/// * Görünüm: menü çerçevesi (`menu` + `flush`); satır `GuTile` + 22'lik
///   ikon; yönetim satırlarının üstünde ayraç; "Sil" yıkıcı renkte.
///
/// ```dart
/// final action = await feedback.showSheet<PostMenuAction>(
///   SheetId.sht08,
///   builder: (_) => PostMenu(
///     isOwn: post.authorId == uid,
///     canManage: canManagePosts(post.clubId),
///     isSaved: isPostSaved(post.id),
///     isPinned: post.pinned,
///   ),
/// );
/// ```
///
/// Design: SHT-08
class PostMenu extends StatelessWidget {
  /// Gönderi menüsü: [isOwn] kullanıcının kendi gönderisi, [canManage] içerik
  /// yönetebiliyor, [isSaved] kayıtlı, [isPinned] sabit.
  const PostMenu({
    required this.isOwn,
    required this.canManage,
    required this.isSaved,
    required this.isPinned,
    super.key,
  });

  /// Gönderi oturumdaki kullanıcının mı?
  final bool isOwn;

  /// Kullanıcı kulübün içeriğini yönetebiliyor mu (yönetim / süper admin)?
  final bool canManage;

  /// Gönderi kullanıcının kaydedilenlerinde mi?
  final bool isSaved;

  /// Gönderi sabit mi?
  final bool isPinned;

  /// [action] satırının anahtarı (`SHT-08.<action>`).
  static Key keyOf(PostMenuAction action) =>
      FeedbackKeys.of(SheetId.sht08.designId, action.action);

  /// Görünen satırlar, tasarım sırasıyla (`sheets.js:41–43`).
  static List<PostMenuAction> actionsFor({
    required bool isOwn,
    required bool canManage,
    required bool isSaved,
    required bool isPinned,
  }) => [
    if (isSaved) PostMenuAction.unsave else PostMenuAction.save,
    PostMenuAction.share,
    PostMenuAction.copyLink,
    if (!isOwn) ...[PostMenuAction.report, PostMenuAction.blockAuthor],
    if (canManage) ...[
      if (isOwn) PostMenuAction.edit,
      if (isPinned) PostMenuAction.unpin else PostMenuAction.pin,
      PostMenuAction.remove,
    ],
  ];

  /// [action] satırının görünen adı.
  static String labelOf(AppLocalizations l10n, PostMenuAction action) =>
      switch (action) {
        PostMenuAction.save => l10n.feedSave,
        PostMenuAction.unsave => l10n.feedUnsave,
        PostMenuAction.share => l10n.commonShare,
        PostMenuAction.copyLink => l10n.sht08CopyLink,
        PostMenuAction.report => l10n.sht06Report,
        PostMenuAction.blockAuthor => l10n.sht08BlockUser,
        PostMenuAction.edit => l10n.commonEdit,
        PostMenuAction.pin => l10n.postPin,
        PostMenuAction.unpin => l10n.postUnpin,
        PostMenuAction.remove => l10n.commonDelete,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.gu.colors;
    final actions = actionsFor(
      isOwn: isOwn,
      canManage: canManage,
      isSaved: isSaved,
      isPinned: isPinned,
    );
    return GuSheetFrame(
      title: l10n.sht08Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: FeedbackKeys.of(SheetId.sht08.designId, 'close'),
      menu: true,
      flush: true,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, action) in actions.indexed) ...[
            // Yönetim bölümünün başı (`sheets.js:43` `.divider`).
            if (action.isManagement &&
                (index == 0 || !actions[index - 1].isManagement))
              const GuDivider(),
            GuTile(
              key: keyOf(action),
              title: labelOf(l10n, action),
              danger: action.isDanger,
              leading: GuIcon(
                action.icon,
                size: GuSizes.icon22,
                color: action.isDanger
                    ? colors.stateDanger
                    : colors.textHeading,
              ),
              onTap: () => Navigator.of(context).pop(action),
            ),
          ],
        ],
      ),
    );
  }
}
