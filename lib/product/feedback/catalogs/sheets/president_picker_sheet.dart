import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/media/user_avatar_image.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_kulupler/product/widget/member/user_row.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-25'in kipi: başlık ve aday havuzu (`sheets.js:118`).
enum PresidentPickerMode {
  /// "Başkanlığı devret" — kulübün aktif `member` / `board` üyeleri (MGT-03,
  /// DLG-09, SET-03). Seçimden sonra DLG-21 ("DEVRET" onayı) açılır.
  transfer,

  /// "Başkan ata" — etkin, personel olmayan kullanıcılar (ADM-02 / ADM-03,
  /// T-37).
  assign,
}

/// SHT-25 aday satırı — üyelik ya da kullanıcı belgesinden türetilir.
final class PresidentCandidate extends Equatable {
  /// [userId] adayı; ad, avatar tohumu, bölüm ve sınıf satırda çizilir.
  const PresidentCandidate({
    required this.userId,
    required this.name,
    required this.avatarSeed,
    this.department,
    this.year,
    this.user,
  });

  /// Aktif üyelikten aday (devir kipi; `applicant` anlık görüntüsü).
  PresidentCandidate.fromMembership(MembershipModel membership)
    : this(
        userId: membership.userId,
        name: membership.applicant.name,
        avatarSeed: membership.applicant.avatarSeed,
        department: membership.applicant.department,
        year: membership.applicant.year,
      );

  /// Kullanıcı belgesinden aday (atama kipi).
  PresidentCandidate.fromUser(UserModel user)
    : this(
        userId: user.uid,
        name: user.name,
        avatarSeed: user.avatarSeed,
        department: user.department,
        year: user.year,
        user: user,
      );

  /// Adayın kullanıcı kimliği (`pop` değeri).
  final String userId;

  /// Görünen ad.
  final String name;

  /// Avatar tohumu (baş harfler / renk).
  final String avatarSeed;

  /// Bölüm kodu; yoksa `null`.
  final String? department;

  /// Sınıf; yoksa `null`.
  final YearLevel? year;

  /// Adayın kullanıcı belgesi (atama kipi, [PresidentCandidate.fromUser]):
  /// fotoğraf doğrudan bundan çizilir. `null` (devir kipi — üyelik anlık
  /// görüntüsü) → fotoğraf yolu avatar dizininden toplu okunur.
  final UserModel? user;

  @override
  List<Object?> get props => [
    userId,
    name,
    avatarSeed,
    department,
    year,
    user,
  ];
}

/// SHT-25 "Başkanlığı devret" / "Başkan ata" — kişi arama ve seçme sayfası
/// (prototip `SHEETS['SHT-25']`, `sheets.js:117–119`; tam yükseklik, flush).
/// MGT-03 "Başkanlığı devret", DLG-09 (W-14), SET-03 (W-34) devir kipinde;
/// ADM-02 / ADM-03 atama kipinde açar.
///
/// * Arama (`SHT-25.search`, otomatik odak): ada göre süzer (Türkçe küçük
///   harf); liste ada göre sıralıdır, en çok [maxRows] satır.
/// * Satır (`UserRow`, "bölüm · sınıf", chevron) → adayın `userId`'si ile
///   `pop`. Eşleşme yoksa "Eşleşen üye yok". X / scrim / geri → `null`.
/// * "DEVRET" yazma onayı bu sayfada değil, seçimden sonra açılan DLG-21'dedir
///   (`dialogs.js:37–38`, TST-X20); yazmayı çağıran yürütür.
/// * Anahtarlar `SHT-25.search`, `SHT-25.select.<userId>`, `SHT-25.close`
///   (+ `SHT-25.scrim`).
///
/// ```dart
/// final userId = await feedback.showSheet<String>(
///   SheetId.sht25,
///   builder: (_) => PresidentPickerSheet(
///     candidates: PresidentPickerSheet.transferCandidates(state.members),
///   ),
/// );
/// ```
///
/// Design: SHT-25
class PresidentPickerSheet extends ConsumerStatefulWidget {
  /// [candidates] arasından seçtirir; başlık [mode]'a göre.
  const PresidentPickerSheet({
    required this.candidates,
    this.mode = PresidentPickerMode.transfer,
    super.key,
  });

  /// Aday havuzu (çağıran süzer; devirde [transferCandidates]).
  final List<PresidentCandidate> candidates;

  /// Başlık ve bağlam.
  final PresidentPickerMode mode;

  /// En çok çizilen satır (`slice(0, 40)`).
  static const int maxRows = 40;

  /// Arama alanının anahtarı (`SHT-25.search`).
  static final Key searchKey = GuKey.action('SHT-25.search');

  /// [userId] satırının anahtarı (`SHT-25.select.<userId>`).
  static Key selectKey(String userId) => GuKey.action('SHT-25.select.$userId');

  /// Devir adayları: aktif `member` / `board` üyeler (başkan ve danışman
  /// hariç — `RolePolicy.canTransfer` hedef kümesi). [candidateOf] satırı
  /// kurar (varsayılan: üyelikteki anlık görüntü; güncel kullanıcı belgesi
  /// okunduysa çağıran onu verir — D-29).
  static List<PresidentCandidate> transferCandidates(
    Iterable<MembershipModel> members, {
    PresidentCandidate Function(MembershipModel membership)? candidateOf,
  }) => [
    for (final m in members)
      if (m.status == MembershipStatus.active &&
          (m.role == ClubRole.member || m.role == ClubRole.board))
        (candidateOf ?? PresidentCandidate.fromMembership)(m),
  ];

  /// [query]'ye uyan adaylar, ada göre sıralı, en çok [maxRows].
  static List<PresidentCandidate> filter(
    List<PresidentCandidate> candidates,
    String query,
  ) {
    final q = query.trim().trLower();
    final list = [
      for (final c in candidates)
        if (q.isEmpty || c.name.trLower().contains(q)) c,
    ]..sort((a, b) => a.name.trCompareTo(b.name));
    return list.take(maxRows).toList();
  }

  @override
  ConsumerState<PresidentPickerSheet> createState() =>
      _PresidentPickerSheetState();
}

class _PresidentPickerSheetState extends ConsumerState<PresidentPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final list = PresidentPickerSheet.filter(widget.candidates, _query);
    return GuSheetFrame(
      title: widget.mode == PresidentPickerMode.transfer
          ? l10n.sht25Transfer
          : l10n.sht25Assign,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: GuKey.action('SHT-25.close'),
      full: true,
      flush: true,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // `px16 pb8`: `pb8` CSS'te tanımsız → alt dolgu yok (K-42, CD-99).
          Padding(
            padding: GuInsets.sym(h: GuSpacing.s16),
            child: GuInput(
              icon: GuIcons.search,
              placeholder: l10n.adminUsersSearch,
              semanticLabel: l10n.commonSearch,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() => _query = v),
              actionKey: PresidentPickerSheet.searchKey,
            ),
          ),
          for (final c in list)
            UserRow.named(
              name: c.name,
              avatarSeed: c.avatarSeed,
              // Atama kipinde belge elde (okuma yok); devir kipinde görünen
              // adayların fotoğrafları tek toplu okumada çözülür.
              avatarImage: c.user != null
                  ? ref.userAvatarImage(c.user, displaySize: GuSizes.avatar)
                  : ref.userAvatarImageOf(
                      c.userId,
                      displaySize: GuSizes.avatar,
                    ),
              sub: MemberRow.departmentAndYear(
                context,
                department: c.department,
                year: c.year,
              ),
              chevron: true,
              actionKey: PresidentPickerSheet.selectKey(c.userId),
              onTap: () => Navigator.of(context).pop(c.userId),
            ),
          if (list.isEmpty)
            Padding(
              padding: GuInsets.all16,
              child: Text(
                l10n.membersNoResults,
                textAlign: TextAlign.center,
                style: gu.text.bodyS.copyWith(color: gu.colors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}
