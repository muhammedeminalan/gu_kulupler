import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/managed_club_picker_view_model.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-18'de bir kulüp seçilince çağrılır: seçilen kulübün kimliğiyle.
typedef ManagedClubSelect = void Function(String clubId);

/// SHT-18 "Yönetilen kulüp seç" — kullanıcının yönettiği kulüpler arasında
/// geçiş (prototip `SHEETS['SHT-18']`, `sheets.js:87–88`). FED-03
/// (`FED-03.switchClub`), MGT-01…MGT-10 başlığı (`<ID>.switchClub`) ve PRF-01
/// açar.
///
/// * Satırlar oturumdan gelir ([managedOf]: `SessionState.memberships`
///   içinde **aktif** ve rolü yönetim kurulu / başkan / danışman olan
///   üyelikler), oturum sırasıyla. Satır: amblem (44, kulüp ikonu 20) · kulüp
///   adı · rol rozeti (+ danışmanda "Salt okunur" rozeti) · sonda
///   `chevron-right`. Kulüp adı ve ikonu belgeden okunur
///   (`ManagedClubPickerViewModel`); belgesi olmayan / silinmiş kulübün
///   satırı çizilmez.
/// * Durum sırası: hata ("Yeniden dene", `SHT-18.retry`) → yükleniyor (satır
///   iskeleti, yönetilen kulüp sayısı kadar) → boş ("Yönettiğin kulüp yok.")
///   → satırlar.
/// * [selectedClubId] o an açık olan kulüptür: satırı seçili çizilir (sonda
///   `chevron-right` yerine `check`).
/// * Dokunma sayfayı seçilen kulübün kimliğiyle kapatır (`pop(String)`); X /
///   scrim / sürükleme / geri → `null`.
/// * [onSelect] verilirse sayfa kapanırken seçilen kimlikle çağrılır
///   (FED-03: `ComposeRoute(clubId: id).go`). Verilmezse varsayılan davranış
///   seçilen kulübün yönetim paneline gitmektir (MGT-01) — `ManageRoute`
///   T-31'de gelir (W-26); o zamana kadar sayfa yalnızca kimliği döner.
/// * Anahtarlar `SHT-18.select.<clubId>`, `SHT-18.close`, `SHT-18.retry`
///   (+ `SHT-18.scrim`, `FeedbackService`).
///
/// ```dart
/// final clubId = await feedback.showSheet<String>(
///   SheetId.sht18,
///   builder: (_) => ManagedClubPickerSheet(selectedClubId: widget.clubId),
/// );
/// ```
///
/// Design: SHT-18
class ManagedClubPickerSheet extends ConsumerWidget {
  /// Yönetilen kulüp seçici; [selectedClubId] o an açık olan kulüp.
  const ManagedClubPickerSheet({
    this.selectedClubId,
    this.onSelect,
    super.key,
  });

  /// O an açık olan (seçili çizilen) kulübün kimliği; yoksa `null`.
  final String? selectedClubId;

  /// Seçimde, sayfa kapanırken çağrılır; `null` → varsayılan davranış
  /// (MGT-01 — W-26, T-31).
  final ManagedClubSelect? onSelect;

  /// Kayıtta olmayan ikon adında amblemin yedeği (`ClubCard` ile aynı).
  static const GuIcons _fallbackIcon = GuIcons.users;

  /// [clubId] satırının anahtarı (`SHT-18.select.<clubId>`).
  static Key keyOf(String clubId) =>
      FeedbackKeys.of(SheetId.sht18.designId, 'select.$clubId');

  /// [session] kullanıcısının yönettiği kulüplerin üyelikleri: **aktif** ve
  /// rolü yönetim kurulu / başkan (yazabilir) ya da danışman (salt okunur).
  /// Sıra `SessionState.memberships` sırasıdır. Çağıranlar "kulüp değiştir"
  /// düğmesini yalnızca birden çok satır varken gösterir.
  static List<MembershipModel> managedOf(SessionState session) =>
      ManagedClubPickerViewModel.managedOf(session);

  /// Satıra dokunuldu: sayfa [clubId] ile kapanır, sonra [onSelect].
  void _select(BuildContext context, String clubId) {
    Navigator.of(context).pop(clubId);
    // TODO(T-31): `onSelect == null` iken varsayılan davranış —
    // `ManageRoute(clubId: clubId).go` (MGT-01; bağlama borcu W-26). O zamana
    // kadar sayfa yalnızca kimliği döner.
    onSelect?.call(clubId);
  }

  /// [membership] satırı: amblem · ad · rol rozeti (+ salt okunur) · ok.
  Widget _row(
    BuildContext context,
    MembershipModel membership,
    ClubModel club,
  ) {
    final l10n = context.l10n;
    final isSelected = club.id == selectedClubId;
    return GuTile(
      key: keyOf(club.id),
      title: club.name,
      leading: GuEmblem(
        icon: CoverMapper.icon(club.iconName) ?? _fallbackIcon,
      ),
      // `<span class="row gap6">` (sheets.js:88); dar ekranda rozetler alt
      // satıra iner.
      sub2Widget: Wrap(
        spacing: GuSpacing.s6,
        runSpacing: GuSpacing.s4,
        children: [
          MemberRow.roleBadge(l10n, membership.role),
          if (membership.role == ClubRole.advisor)
            GuBadge(label: l10n.commonReadOnly, icon: GuIcons.eye),
        ],
      ),
      chevron: !isSelected,
      // Seçili işareti satırın düğme düğümüne "seçili" olarak karışır.
      trailing: isSelected
          ? Semantics(
              selected: true,
              child: GuIcon(
                GuIcons.check,
                size: GuSizes.icon18,
                color: context.gu.colors.brandPrimary,
              ),
            )
          : null,
      onTap: () => _select(context, club.id),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final managed = ref.watch(sessionViewModelProvider.select(managedOf));
    final state = ref.watch(managedClubPickerViewModelProvider);
    final rows = [
      for (final membership in managed)
        if (state.clubs[membership.clubId] case final club?)
          _row(context, membership, club),
    ];

    // Sıra: hata → yükleniyor → boş → satırlar. Satırlar varken gelen hata /
    // yeniden okuma onları silmez.
    final Widget body;
    if (rows.isNotEmpty) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      );
    } else if (state.isError) {
      body = GuErrorState(
        title: l10n.sysErrorTitle,
        description: l10n.sysErrorDesc,
        retryLabel: l10n.commonRetry,
        retryActionKey: FeedbackKeys.of(SheetId.sht18.designId, 'retry'),
        inline: true,
        onRetry: ref.read(managedClubPickerViewModelProvider.notifier).fetch,
      );
    } else if (state.isFetching) {
      body = GuSkeletonList(
        semanticLabel: l10n.commonLoading,
        count: managed.length,
      );
    } else {
      body = Padding(
        padding: GuInsets.all16,
        child: Text(
          l10n.sht18Empty,
          textAlign: TextAlign.center,
          style: context.gu.text.bodyS.copyWith(
            color: context.gu.colors.textMuted,
          ),
        ),
      );
    }

    return GuSheetFrame(
      title: l10n.sht18Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: FeedbackKeys.of(SheetId.sht18.designId, 'close'),
      menu: true,
      flush: true,
      body: body,
    );
  }
}
