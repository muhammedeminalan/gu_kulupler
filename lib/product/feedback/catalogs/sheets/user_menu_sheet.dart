import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-27'de seçilen öğe — sayfanın `pop` değeri. Sıra tasarımdaki satır
/// sırasıdır (`sheets.js:132`).
enum UserMenuAction {
  /// "Profili gör" (`SHT-27.profile`) → CLB-07.
  viewProfile('profile', GuIcons.user),

  /// "Yorumu sil" (`SHT-27.deleteComment`) → DLG-11 (T-20).
  removeComment('deleteComment', GuIcons.trash2),

  /// "Yorumu şikayet et" (`SHT-27.reportComment`) → SHT-10 (T-20).
  reportComment('reportComment', GuIcons.flag),

  /// "Engelle" (`SHT-27.block`) → DLG-13.
  block('block', GuIcons.ban),

  /// "Engeli kaldır" (aynı satır, `SHT-27.block`; kullanıcı engelliyken) →
  /// TST-09.
  unblock('block', GuIcons.ban),

  /// "Kullanıcıyı şikayet et" (`SHT-27.report`) → SHT-10.
  report('report', GuIcons.flag);

  const UserMenuAction(this.action, this.icon);

  /// Aksiyon adı (`SHT-27.<action>`).
  final String action;

  /// Satırın ikonu.
  final GuIcons icon;

  /// Yıkıcı satır mı (kırmızı ikon + metin): "Yorumu sil" ve "Engelle".
  /// "Engeli kaldır" olağan renktedir (`danger=${!blocked}`,
  /// `sheets.js:132`).
  bool get isDanger => this == removeComment || this == block;
}

/// SHT-27 "Kullanıcı" — bir kişinin menüsü (prototip `SHEETS['SHT-27']`,
/// `sheets.js:130–132`). CLB-06, CLB-07, SHT-09 (yorum satırı) ve ADM-05
/// açar.
///
/// * Başlık kişinin adıdır ([userName]); verilmezse "Kullanıcı".
/// * Gövde menü satırlarıdır (`GuTile`, ikon 22): "Profili gör" ·
///   "Yorumu sil" · "Yorumu şikayet et" · "Engelle" / "Engeli kaldır" ·
///   "Kullanıcıyı şikayet et". "Yorumu sil" ve "Engelle" yıkıcıdır
///   (kırmızı); "Engeli kaldır" olağan renktedir.
/// * Satırlar [actionsFor] ile süzülür: kendi menüsünde engelle / şikayet
///   yoktur; yorum satırları yalnızca [commentId] verildiyse çizilir.
///   Oturumdaki kullanıcı oturumdan okunur (`SessionState.uid`). Engel
///   durumu da oturumdan gelir (`SessionState.isBlocked`); çağıran daha
///   güncel bir değer biliyorsa (iyimser güncelleme) [isBlocked] ile verir.
/// * Sayfa hiçbir şey yürütmez: dokunulan satır [UserMenuAction] olarak döner
///   (`pop`), eylemi çağıran başlatır. X / scrim / sürükleme / geri → `null`.
/// * Anahtarlar `SHT-27.profile`, `.deleteComment`, `.reportComment`,
///   `.block`, `.report`, `SHT-27.close` (+ `SHT-27.scrim`,
///   `FeedbackService`).
///
/// ```dart
/// final action = await feedback.showSheet<UserMenuAction>(
///   SheetId.sht27,
///   builder: (_) => UserMenuSheet(userId: user.uid, userName: user.name),
/// );
/// ```
///
/// Design: SHT-27
class UserMenuSheet extends ConsumerWidget {
  /// [userId] kullanıcısının menüsü; başlık [userName].
  const UserMenuSheet({
    required this.userId,
    this.userName,
    this.commentId,
    this.canDeleteComment = false,
    this.isBlocked,
    super.key,
  });

  /// Menüsü açılan kullanıcının kimliği.
  final String userId;

  /// Başlıkta gösterilen ad; verilmezse genel başlık ("Kullanıcı").
  final String? userName;

  /// Menü bir yorum satırından açıldıysa yorumun kimliği (SHT-09, T-20).
  final String? commentId;

  /// "Yorumu sil" çizilsin mi (yorum sahibi / yönetici; [commentId] ile).
  final bool canDeleteComment;

  /// Kullanıcı engelli mi; `null` → oturumdan okunur
  /// (`SessionState.isBlocked`).
  final bool? isBlocked;

  /// [action] satırının anahtarı (`SHT-27.<action>`).
  static Key keyOf(UserMenuAction action) =>
      FeedbackKeys.of(SheetId.sht27.designId, action.action);

  /// Görünen satırlar, tasarım sırasıyla (`sheets.js:132`).
  static List<UserMenuAction> actionsFor({
    required bool isSelf,
    required bool isBlocked,
    bool hasComment = false,
    bool canDeleteComment = false,
  }) => [
    UserMenuAction.viewProfile,
    // TODO(T-20): yorum satırlarını SHT-09 açar ve yürütür (W-21) — "Yorumu
    // sil" → DLG-11, "Yorumu şikayet et" → SHT-10 (`ReportTargetType.comment`).
    if (hasComment && canDeleteComment) UserMenuAction.removeComment,
    if (hasComment) UserMenuAction.reportComment,
    if (!isSelf) ...[
      if (isBlocked) UserMenuAction.unblock else UserMenuAction.block,
      UserMenuAction.report,
    ],
  ];

  /// [action] satırının görünen adı.
  static String labelOf(AppLocalizations l10n, UserMenuAction action) =>
      switch (action) {
        UserMenuAction.viewProfile => l10n.userprofileView,
        UserMenuAction.removeComment => l10n.sht27DeleteComment,
        UserMenuAction.reportComment => l10n.sht27ReportComment,
        UserMenuAction.block => l10n.sht27Block,
        UserMenuAction.unblock => l10n.userprofileUnblock,
        UserMenuAction.report => l10n.sht27ReportUser,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.gu.colors;
    final isSelf = ref.watch(
      sessionViewModelProvider.select((session) => session.uid == userId),
    );
    final isBlockedInSession = ref.watch(
      sessionViewModelProvider.select((session) => session.isBlocked(userId)),
    );
    final actions = actionsFor(
      isSelf: isSelf,
      isBlocked: isBlocked ?? isBlockedInSession,
      hasComment: commentId != null,
      canDeleteComment: canDeleteComment,
    );
    return GuSheetFrame(
      title: userName ?? l10n.sht27Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: FeedbackKeys.of(SheetId.sht27.designId, 'close'),
      menu: true,
      flush: true,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final action in actions)
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
      ),
    );
  }
}
