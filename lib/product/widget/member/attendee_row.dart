import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/widget/member/user_row.dart';
import 'package:gu_ui/gu_ui.dart';

/// Katılımcı satırı (MGT-06) — prototip satır içi `.tile.is-plain`
/// (`screens-manage.js:134–135`): `UserRow` (avatar 40 · ad · bölüm · sınıf)
/// + durum rozeti + "Katıldı" anahtarı (CD-27 kompozisyonu; widget-catalog
/// P4).
///
/// * **Kayıtlı / katıldı** (`going` / `attended`): rozet [attended] ise
///   "Katıldın" (`attended`), değilse "Kayıtlı" (`going`); [absent] (etkinlik
///   bitti, okutulmadı) → "Gelmedi" (`absent`). Rozet ile anahtar arası 12
///   (satır `gap`). [attended] anahtarın gösterdiği değerdir (iyimser
///   güncellemede State'in değeri); [rsvp] kimlik ve bağlamdır.
/// * **Bekleme listesi** (`waitlist`, `screens-manage.js:135`): sıra pili
///   ([waitlistPosition], `.badge-count` `text.muted`) + avatar 36 + ad +
///   alt satır + "Kayıtlıya al" (`sm` tonal). Kontenjan dolu ([capacityFull])
///   ya da [readOnly] iken düğme devre dışıdır; dokunuş [readOnly] ise
///   [onDisabledTap]'e (TST-26), değilse [onCapacityFullTap]'e (TST-X14)
///   gider. [promoting] düğmeyi meşgul çizer.
/// * **İptal** (`cancelled`): yalnızca "İptal" rozeti; anahtar yok.
/// * [scannedAtLabel] (okutulma saati, çağıran biçimlendirir) katılmış
///   satırda üçüncü satırda "Okutuldu: …" olarak çizilir.
/// * [isSelf] (yöneticinin kendi kaydı — T-30: kendi yoklamasını
///   işaretleyemez) → anahtar devre dışı + üçüncü satırda ipucu.
/// * [onToggle] `null` → etkileşimsiz; [readOnly] (danışman) → devre dışı
///   görünüm, dokunuş [onDisabledTap] (TST-26).
/// * Ad ve alt satır çağırandan gelir ([name], [sub]); avatar tohumu
///   [avatarSeed] (yoksa [rsvp]'nin `userId`'si), fotoğraf [avatarImage].
/// * Anahtarları çağıran verir (D-18, CD-86): [actionKey]
///   `MGT-06.attended.<userId>` (anahtarın kendisinde), [promoteKey]
///   `MGT-06.promote.<userId>`.
///
/// ```dart
/// AttendeeRow(
///   rsvp: rsvp,
///   name: state.names[rsvp.userId] ?? '',
///   attended: rsvp.status == RsvpStatus.attended,
///   onToggle: (value) => viewModel.setAttended(rsvp.userId, value),
///   actionKey: GuKey.action('MGT-06.attended.${rsvp.userId}'),
/// )
/// ```
class AttendeeRow extends StatelessWidget {
  /// [rsvp] katılımcısının satırı.
  const AttendeeRow({
    required this.rsvp,
    required this.name,
    required this.attended,
    required this.onToggle,
    this.sub,
    this.avatarImage,
    this.avatarSeed,
    this.actionKey,
    this.readOnly = false,
    this.onDisabledTap,
    this.absent = false,
    this.isSelf = false,
    this.scannedAtLabel,
    this.waitlistPosition,
    this.onPromote,
    this.promoteKey,
    this.capacityFull = false,
    this.onCapacityFullTap,
    this.promoting = false,
    super.key,
  });

  /// Katılım kaydı (`going` / `attended` / `waitlist` / `cancelled`).
  final RsvpModel rsvp;

  /// Görünen ad.
  final String name;

  /// Alt satır (bölüm · sınıf); `null` ya da boş → çizilmez.
  final String? sub;

  /// Profil fotoğrafı; `null` → baş harfler.
  final ImageProvider? avatarImage;

  /// Avatar renk tohumu (`UserModel.avatarSeed`); `null` ya da boş → [rsvp]
  /// `userId` (`MemberRow` ile aynı kural).
  final String? avatarSeed;

  String get _seed {
    final seed = avatarSeed;
    return seed == null || seed.isEmpty ? rsvp.userId : seed;
  }

  /// Anahtarın değeri (katıldı mı).
  final bool attended;

  /// Anahtar değişince yeni değerle çağrılır; `null` → etkileşimsiz.
  final ValueChanged<bool>? onToggle;

  /// Anahtarın aksiyon anahtarı (`GuKey.action`); çağıran verir.
  final Key? actionKey;

  /// Salt okunur (danışman): anahtar ve "Kayıtlıya al" devre dışı görünür.
  final bool readOnly;

  /// Salt okunurken devre dışı denetime dokunma (TST-26).
  final VoidCallback? onDisabledTap;

  /// Etkinlik bitti ve okutulmadı: rozet "Gelmedi" ([attended] `false` iken).
  final bool absent;

  /// Yöneticinin kendi kaydı: anahtar devre dışı + ipucu.
  final bool isSelf;

  /// Okutulma saati (çağıran biçimlendirir); katılmış satırda üçüncü satır.
  final String? scannedAtLabel;

  /// Bekleme sırası (1'den); `null` → sıra pili çizilmez.
  final int? waitlistPosition;

  /// "Kayıtlıya al" (bekleme satırı); `null` → devre dışı.
  final VoidCallback? onPromote;

  /// "Kayıtlıya al" düğmesinin aksiyon anahtarı; çağıran verir.
  final Key? promoteKey;

  /// Kontenjan dolu: "Kayıtlıya al" devre dışı.
  final bool capacityFull;

  /// Kontenjan doluyken "Kayıtlıya al"a dokunma (TST-X14).
  final VoidCallback? onCapacityFullTap;

  /// Terfi sürüyor: "Kayıtlıya al" meşgul.
  final bool promoting;

  @override
  Widget build(BuildContext context) => switch (rsvp.status) {
    RsvpStatus.waitlist => _waitlist(context),
    RsvpStatus.cancelled => _row(
      context,
      trailing: GuStatusBadge(
        kind: GuStatusBadgeKind.cancelled,
        label: context.l10n.statusCancelled,
      ),
    ),
    RsvpStatus.going || RsvpStatus.attended => _registered(context),
  };

  Widget _registered(BuildContext context) {
    final l10n = context.l10n;
    final (kind, label) = attended
        ? (GuStatusBadgeKind.attended, l10n.statusAttended)
        : absent
        ? (GuStatusBadgeKind.absent, l10n.attendanceAbsent)
        : (GuStatusBadgeKind.going, l10n.attendanceRegisteredOne);
    final scanned = scannedAtLabel;
    final notes = [
      if (attended && scanned != null && scanned.isNotEmpty)
        l10n.ticketScannedAt(scanned),
      if (isSelf) l10n.attendanceSelfHint,
    ];
    return _row(
      context,
      notes: notes,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: GuSpacing.s12,
        children: [
          GuStatusBadge(kind: kind, label: label),
          GuSwitch(
            key: actionKey,
            value: attended,
            onChanged: onToggle,
            semanticLabel: l10n.statusAttended,
            disabled: readOnly || isSelf,
            onDisabledPressed: readOnly ? onDisabledTap : null,
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required Widget trailing,
    List<String> notes = const [],
  }) => UserRow.named(
    name: name,
    avatarSeed: _seed,
    sub: sub,
    avatarImage: avatarImage,
    sub2: notes.isEmpty
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final note in notes) Text(note)],
          ),
    trailing: trailing,
  );

  /// Bekleme satırı (`screens-manage.js:135`): sıra pili + avatar 36 + ad +
  /// alt satır + "Kayıtlıya al".
  Widget _waitlist(BuildContext context) {
    final position = waitlistPosition;
    final blocked = readOnly || capacityFull;
    return GuTile(
      title: name,
      // `UserRow` ile aynı: tek satır + üç nokta (K-29).
      titleWidget: Text(
        name,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: (sub?.isEmpty ?? true) ? null : sub,
      plain: true,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: GuSpacing.s12,
        children: [
          if (position != null)
            GuCountBadge(
              label: '$position',
              size: GuCountBadgeSize.md,
              tone: GuCountBadgeTone.muted,
            ),
          GuAvatar(
            initials: name.initials,
            seed: _seed,
            size: waitlistAvatarSize,
            image: avatarImage,
          ),
        ],
      ),
      trailing: GuButton(
        key: promoteKey,
        label: context.l10n.attendancePromote,
        variant: GuButtonVariant.tonal,
        size: GuButtonSize.sm,
        loading: promoting,
        disabled: blocked,
        onPressed: onPromote,
        onDisabledPressed: readOnly ? onDisabledTap : onCapacityFullTap,
      ),
    );
  }

  /// Bekleme listesi satırının avatarı: `Avatar size=${36}`
  /// (`screens-manage.js:135`). Çağıran fotoğrafı bu boyutta çözer.
  static final double waitlistAvatarSize = GuSizes.avatarSizes[2];
}
