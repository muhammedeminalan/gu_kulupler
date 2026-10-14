import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/l10n/reject_reason_labels.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_kulupler/product/widget/member/user_row.dart';
import 'package:gu_ui/gu_ui.dart';

/// Başvuru satırı — prototip `ApplicationRow` (`cards.js:170–178`) ve
/// "Onaylanan" / "Reddedilen" sekmelerinin satırı (`screens-manage.js:57`).
/// MGT-02 kullanır (widget-catalog P3).
///
/// * **Beklemede** ([MembershipModel.status] `pending`; K-31 — `GuTile`
///   değil): dolgu 6 / 8 / 6 / 16, en az 64; avatar 44 + metin sütunu (ad
///   `labelL` + `priorCount > 0` ise "Daha önce başvurdu" rozeti (`history`),
///   bölüm · sınıf, başvuru notu önizlemesi (italik, tek satır) ya da
///   "Not yok", [timeLabel]) + sonda tonlu onay / ret düğmeleri (44, K-32).
/// * **Karar verilmiş** (`active` / `rejected` …): `UserRow` (avatar 40) —
///   alt satır "bölüm · sınıf · [timeLabel]" (karar tarihi), reddedilende
///   üçüncü satır ret nedeni, sonda durum rozeti (onaylandı / reddedildi).
/// * Ad, bölüm · sınıf ve avatar [application]'ın `applicant` anlık
///   görüntüsünden gelir (D-29); [user] verilirse (güncel belge) o kullanılır.
/// * [note] başvuru notudur (`private/contact`, CD-137 — yalnızca yöneticiye
///   okunur); `null` / boş → "Not yok". [timeLabel] beklemede başvuru
///   zamanının göreli metni, karar verilmişte karar tarihidir (çağıran
///   biçimlendirir — `ActivityRow` kalıbı).
/// * [readOnly] (danışman) iken onay / ret düğmeleri devre dışı görünür,
///   dokunuş [onReadOnlyTap]'e (TST-26) gider. [selecting] kipinde başta
///   onay kutusu çizilir, düğmeler gizlenir; uzun basış seçim kipini başlatır
///   ([onSelect] `true`).
/// * Başvuranın hesabı silinmişse ([isDeletedApplicant]; W-92) satır
///   "Silinmiş kullanıcı" olarak **etkisiz** çizilir: avatar `?`, alt satır
///   ve not yok, düğmeler / onay kutusu devre dışı, satır dokunulmaz (M5 / M6
///   Rules bu başvuruyu zaten reddeder — W-89 a).
/// * Anahtarları çağıran verir (D-18, CD-86): [actionKey]
///   `MGT-02.row.<userId>`, [approveActionKey] `MGT-02.approve.<userId>`,
///   [rejectActionKey] `MGT-02.reject.<userId>`, [selectActionKey]
///   `MGT-02.select.<userId>`.
///
/// ```dart
/// ApplicationRow(
///   application: m,
///   timeLabel: relative(m.appliedAt),
///   actionKey: GuKey.action('MGT-02.row.${m.userId}'),
///   approveActionKey: GuKey.action('MGT-02.approve.${m.userId}'),
///   rejectActionKey: GuKey.action('MGT-02.reject.${m.userId}'),
///   selectActionKey: GuKey.action('MGT-02.select.${m.userId}'),
///   onOpen: () => openDetail(m.userId),
///   onApprove: () => approve(m.userId),
///   onReject: () => reject(m.userId),
///   onSelect: (_) => toggleSelect(m.userId),
/// )
/// ```
class ApplicationRow extends StatelessWidget {
  /// [application] başvurusunun satırı.
  const ApplicationRow({
    required this.application,
    required this.timeLabel,
    required this.actionKey,
    required this.onOpen,
    this.user,
    this.avatarImage,
    this.note,
    this.selecting = false,
    this.selected = false,
    this.onSelect,
    this.selectActionKey,
    this.onApprove,
    this.approveActionKey,
    this.onReject,
    this.rejectActionKey,
    this.readOnly = false,
    this.onReadOnlyTap,
    super.key,
  });

  /// Başvuru (üyelik belgesi: `applicant` anlık görüntüsü, `priorCount`,
  /// `appliedAt`, `status`, `rejectReason`).
  final MembershipModel application;

  /// Beklemede: başvuru zamanının göreli metni ("3 saat önce"); karar
  /// verilmiş: karar tarihi.
  final String timeLabel;

  /// Satırın (detay → SHT-19) aksiyon anahtarı; çağıran verir.
  final Key actionKey;

  /// Satıra dokunma → SHT-19 başvuru detayı (seçim kipinde çağıran seçimi
  /// değiştirir).
  final VoidCallback onOpen;

  /// Güncel kullanıcı belgesi; `null` → `applicant` anlık görüntüsü.
  final UserModel? user;

  /// Profil fotoğrafı (çağıran `ref.userAvatarImage(user)` ile çözer);
  /// `null` → baş harfler.
  final ImageProvider? avatarImage;

  /// Başvuru notu (`private/contact.note`); `null` / boş → "Not yok".
  final String? note;

  /// Çoklu seçim kipi (onay kutusu görünür, onay / ret düğmeleri gizli).
  final bool selecting;

  /// Seçim kipinde satır seçili mi.
  final bool selected;

  /// Seçim değişimi (onay kutusu; uzun basış `true` ile seçim kipini açar).
  final ValueChanged<bool>? onSelect;

  /// Onay kutusunun aksiyon anahtarı; çağıran verir.
  final Key? selectActionKey;

  /// Tek dokunuş onay.
  final VoidCallback? onApprove;

  /// Onay düğmesinin aksiyon anahtarı; çağıran verir.
  final Key? approveActionKey;

  /// Tek dokunuş ret (→ SHT-20).
  final VoidCallback? onReject;

  /// Ret düğmesinin aksiyon anahtarı; çağıran verir.
  final Key? rejectActionKey;

  /// Salt okunur (danışman, Q-09): onay / ret düğmeleri devre dışı görünür.
  final bool readOnly;

  /// Salt okunurken düğme dokunuşu (TST-26).
  final VoidCallback? onReadOnlyTap;

  /// Silinmiş kullanıcının avatar metni ve renk tohumu (`art.js:44`).
  static const String _unknown = '?';

  /// Ad satırında rozetin alabileceği en geniş pay; ad kalan genişliğe
  /// sığar ya da kesilir (`cards.js:175` `row gap6` — rozet alt satıra inmez).
  static const double _badgeMaxShare = 0.75;

  /// Başvuranın hesabı silinmiş mi (W-92): güncel belge silinmiş /
  /// anonimleştirilmiş ya da anlık görüntü anonimleştirilmiş
  /// (`Anonymization.applicantPayload` — ad Rules'un beklediği literal).
  static bool isDeletedApplicant(MembershipModel application, UserModel? user) {
    if (user != null && (user.isDeleted || user.isAnonymized)) return true;
    return application.applicant.name == Anonymization.deletedUserName;
  }

  /// Gösterilen ad: silinmişse "Silinmiş kullanıcı", değilse güncel belge ya
  /// da anlık görüntü.
  static String displayName(
    AppLocalizations l10n,
    MembershipModel application,
    UserModel? user,
  ) => isDeletedApplicant(application, user)
      ? l10n.commonDeletedUser
      : user?.name ?? application.applicant.name;

  @override
  Widget build(BuildContext context) {
    final deleted = isDeletedApplicant(application, user);
    return application.status == MembershipStatus.pending
        ? _pending(context, deleted: deleted)
        : _decided(context, deleted: deleted);
  }

  /// "Bölüm · N. sınıf" (güncel belge ya da anlık görüntü).
  String _departmentAndYear(BuildContext context) {
    final user = this.user;
    final applicant = application.applicant;
    return MemberRow.departmentAndYear(
      context,
      department: user == null ? applicant.department : user.department,
      year: user == null ? applicant.year : user.year,
    );
  }

  /// Avatar renk tohumu: belge / anlık görüntü tohumu, boşsa kullanıcı
  /// kimliği.
  String get _seed {
    final seed = user?.avatarSeed ?? application.applicant.avatarSeed;
    return seed.isEmpty ? application.userId : seed;
  }

  Widget _pending(BuildContext context, {required bool deleted}) {
    final gu = context.gu;
    final l10n = context.l10n;
    final name = displayName(l10n, application, user);
    final sub = deleted ? '' : _departmentAndYear(context);
    final shownNote = note?.trim() ?? '';
    final onSelect = this.onSelect;
    final avatar = GuAvatar(
      initials: deleted ? _unknown : name.initials,
      seed: deleted ? _unknown : _seed,
      size: GuSizes.applicationRowAvatar,
      image: deleted ? null : avatarImage,
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: GuSpacing.s2,
      children: [
        _NameLine(
          name: name,
          badge: !deleted && application.priorCount > 0
              ? GuBadge(label: l10n.applicationsPrior, icon: GuIcons.history)
              : null,
        ),
        if (sub.isNotEmpty)
          Text(
            sub,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: gu.text.bodyS.copyWith(color: gu.colors.textMuted),
          ),
        if (!deleted)
          shownNote.isEmpty
              ? Text(l10n.applicationsNoNote, style: gu.text.caption)
              : Text(
                  l10n.appliedNoteQuote(shownNote),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: gu.text.bodyS.copyWith(
                    color: gu.colors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
        if (timeLabel.isNotEmpty) Text(timeLabel, style: gu.text.caption),
      ],
    );
    final canSelect = !deleted && onSelect != null;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: GuSizes.applicationRowMinHeight,
      ),
      child: Padding(
        // `padding:6px 8px 6px 16px` (cards.js:172; K-31).
        padding: GuInsets.only(
          left: GuSpacing.s16,
          top: GuSpacing.s6,
          right: GuSpacing.s8,
          bottom: GuSpacing.s6,
        ),
        child: Row(
          spacing: GuSpacing.s8,
          children: [
            if (selecting)
              GuCheckbox(
                key: selectActionKey,
                value: selected,
                semanticLabel: name,
                disabled: !canSelect,
                onChanged: (value) => onSelect?.call(value),
              ),
            Expanded(
              child: GuTapTarget(
                key: actionKey,
                enabled: !deleted,
                onTap: onOpen,
                onLongPress: canSelect && !selected
                    ? () => onSelect(true)
                    : null,
                child: Padding(
                  // `.row.gap12.flex1.start` `padding:4px 0` (cards.js:174).
                  padding: GuInsets.sym(v: GuSpacing.s4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: GuSpacing.s12,
                    children: [
                      ExcludeSemantics(child: avatar),
                      Expanded(child: text),
                    ],
                  ),
                ),
              ),
            ),
            if (!selecting)
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: GuSpacing.s2,
                children: [
                  GuIconButton(
                    key: approveActionKey,
                    icon: GuIcons.check,
                    tone: GuIconButtonTone.success,
                    semanticLabel: l10n.applicationsApprove,
                    disabled: readOnly || deleted,
                    onPressed: onApprove,
                    onDisabledPressed: deleted ? null : onReadOnlyTap,
                  ),
                  GuIconButton(
                    key: rejectActionKey,
                    icon: GuIcons.x,
                    tone: GuIconButtonTone.danger,
                    semanticLabel: l10n.applicationsReject,
                    disabled: readOnly || deleted,
                    onPressed: onReject,
                    onDisabledPressed: deleted ? null : onReadOnlyTap,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// "Onaylanan" / "Reddedilen" sekmesi satırı (`screens-manage.js:57`):
  /// `Tile` avatar 40, alt satır bölüm · sınıf · karar tarihi, üçüncü satır
  /// ret nedeni, sonda `StatusBadge`.
  Widget _decided(BuildContext context, {required bool deleted}) {
    final l10n = context.l10n;
    final sub = [
      if (!deleted) _departmentAndYear(context),
      timeLabel,
    ].where((part) => part.isNotEmpty).join(_separator);
    final reason = application.status == MembershipStatus.rejected
        ? application.rejectReason
        : null;
    final sub2 = reason == null
        ? null
        : Text(RejectReasonLabels.of(l10n, reason));
    final badge = switch (application.status) {
      MembershipStatus.active => GuStatusBadge(
        kind: GuStatusBadgeKind.approved,
        label: l10n.statusApproved,
      ),
      MembershipStatus.rejected => GuStatusBadge(
        kind: GuStatusBadgeKind.rejected,
        label: l10n.statusRejected,
      ),
      _ => null,
    };
    if (deleted) {
      return UserRow(
        user: null,
        sub: sub,
        sub2: sub2,
        trailing: badge,
        actionKey: actionKey,
      );
    }
    return UserRow.named(
      name: user?.name ?? application.applicant.name,
      avatarSeed: _seed,
      avatarImage: avatarImage,
      sub: sub,
      sub2: sub2,
      trailing: badge,
      actionKey: actionKey,
      onTap: onOpen,
    );
  }

  /// Alt satır ayracı (`cards.js:8` `' · '`).
  static const String _separator = ' · ';
}

/// Ad + "Daha önce başvurdu" rozeti (`row gap6`, cards.js:175): rozet
/// satırın en çok [ApplicationRow._badgeMaxShare] payını alır (kendi
/// metnini keser), ad kalan genişliğe sığar ya da üç noktayla kesilir.
class _NameLine extends StatelessWidget {
  const _NameLine({required this.name, this.badge});

  final String name;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final nameText = Text(
      name,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: gu.text.labelL.copyWith(color: gu.colors.textHeading),
    );
    final badge = this.badge;
    if (badge == null) return nameText;
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        spacing: GuSpacing.s6,
        children: [
          Flexible(child: nameText),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth * ApplicationRow._badgeMaxShare,
            ),
            child: badge,
          ),
        ],
      ),
    );
  }
}
