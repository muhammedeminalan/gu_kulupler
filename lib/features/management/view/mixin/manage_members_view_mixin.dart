import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/constants/app_durations.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/management/provider/manage_members_state.dart';
import 'package:gu_kulupler/features/management/provider/manage_members_view_model.dart';
import 'package:gu_kulupler/features/management/view/manage_members_view.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/managed_club_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_kulupler/product/mixin/manage_member_actions_mixin.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_ui/gu_ui.dart';

/// MGT-03 açılır menülerinde seçilen öğe (`⋮` → dışa aktar).
enum ManageMembersMenuAction {
  /// "Üye listesini dışa aktar (CSV)" (`MGT-03.export`).
  export,
}

/// MGT-03 davranışı: arama, rol çipleri, sıralama ve "⋮" açılır menüleri,
/// satır menüsü (SHT-21 → profil · SHT-22 → DLG-20 · DLG-19), başkanlık
/// devri (SHT-25 → DLG-21), CSV dışa aktarma, sayfalama tetikleyicisi,
/// açılış parametresi ve gezinme.
///
/// * Üye işlemleri ve devir ViewModel'deki ortak
///   `ManageMemberActionsMixin`'dedir (CLB-06 / CLB-07 / SET-03 ile aynı);
///   view yalnızca gezinir. Dışa aktarma ve devir önce `ensureWritable`
///   (danışman → TST-26).
/// * [ManageMembersView.openTransfer] (W-14, W-34): açılıştan
///   `AppDurations.postNavigationSheetDelay` sonra devir akışı.
/// * Sayfalama: liste sonuna bir ekran boyundan az kalınca sonraki sayfa
///   (CLB-06 kalıbı).
mixin ManageMembersViewMixin on ConsumerState<ManageMembersView> {
  /// Açılır menülerin saydam scrim'i (`MGT-03.scrim`, `ui.js:191`).
  static final Key scrimKey = GuKey.action('MGT-03.scrim');

  /// "Dışa aktar" menü öğesinin anahtarı (`MGT-03.export`).
  static final Key exportKey = GuKey.action('MGT-03.export');

  /// [sort] menü öğesinin anahtarı (`MGT-03.sort.<id>`).
  static Key sortKeyOf(MemberSort sort) => switch (sort) {
    MemberSort.name => GuKey.action('MGT-03.sort.name'),
    MemberSort.joined => GuKey.action('MGT-03.sort.joined'),
    MemberSort.role => GuKey.action('MGT-03.sort.role'),
  };

  /// [sort] seçeneğinin adı (düğme etiketi + menü satırı).
  static String sortLabel(AppLocalizations l10n, MemberSort sort) =>
      switch (sort) {
        MemberSort.name => l10n.mgtMembersSortName,
        MemberSort.joined => l10n.mgtMembersSortJoined,
        MemberSort.role => l10n.mgtMembersSortRole,
      };

  /// Listenin kaydırma denetleyicisi.
  final ScrollController scrollController = ScrollController();

  /// Arama alanının denetleyicisi.
  final TextEditingController searchController = TextEditingController();

  Timer? _transferTimer;

  ProviderSubscription<ManageMembersState>? _stateSubscription;

  /// Ekranın ViewModel'i.
  ManageMembersViewModel get viewModel =>
      ref.read(manageMembersViewModelProvider(widget.clubId).notifier);

  ManageMembersState get _state =>
      ref.read(manageMembersViewModelProvider(widget.clubId));

  FeedbackService get _feedback => ref.read(feedbackServiceProvider);

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_loadMoreIfNearEnd);
    _stateSubscription = ref.listenManual(
      manageMembersViewModelProvider(widget.clubId),
      (previous, next) {
        final changed =
            previous == null ||
            previous.cursor != next.cursor ||
            previous.roleFilter != next.roleFilter ||
            previous.query != next.query;
        if (!changed || !next.wantsMore) return;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _loadMoreIfNearEnd(),
        );
      },
    );
    if (widget.openTransfer) {
      _transferTimer = Timer(
        AppDurations.postNavigationSheetDelay,
        () => unawaited(openTransfer()),
      );
    }
  }

  @override
  void dispose() {
    _transferTimer?.cancel();
    _stateSubscription?.close();
    scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  /// Geri (`MGT-03.back`): önceki sayfa; yığın yoksa panel (MGT-01).
  void goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      ManageRoute(clubId: widget.clubId).go(context);
    }
  }

  /// Kulüp değiştir (`MGT-03.switchClub`): SHT-18 → seçilen kulübün üyeleri.
  Future<void> switchClub() => _feedback.showSheet<String>(
    SheetId.sht18,
    builder: (_) => ManagedClubPickerSheet(
      selectedClubId: widget.clubId,
      onSelect: _openClub,
    ),
  );

  void _openClub(String clubId) {
    if (!mounted || clubId == widget.clubId) return;
    ManageMembersRoute(clubId: clubId).go(context);
  }

  /// "Yeniden dene" (`MGT-03.retry`).
  Future<void> retry() => viewModel.fetch();

  /// Çek-yenile.
  Future<void> refresh() => viewModel.refresh();

  /// Rol çipi (`MGT-03.filter.<id>`).
  void selectFilter(ManageRoleFilter filter) => viewModel.setRoleFilter(filter);

  /// Arama alanı (`MGT-03.search`).
  void onQueryChanged(String query) => viewModel.setQuery(query);

  /// Danışman bakışında devre dışı yazma eylemi → TST-26.
  void onReadOnly() => viewModel.onReadOnlyTap();

  /// Satır (`MGT-03.member.<id>`) ve SHT-21 "Profili gör" → CLB-07.
  void openProfile(String userId) => ClubDetailUserProfileRoute(
    clubId: widget.clubId,
    userId: userId,
  ).go(context);

  /// Sıralama (`MGT-03.sort`): açılır menü → seçilen sıralama.
  Future<void> openSort() async {
    final l10n = context.l10n;
    final current = _state.sort;
    final sort = await _feedback.showMenu<MemberSort>(
      scrimKey: scrimKey,
      items: [
        for (final option in MemberSort.values)
          GuPopMenuItem(
            key: sortKeyOf(option),
            label: sortLabel(l10n, option),
            selected: option == current,
            value: option,
          ),
      ],
    );
    if (sort != null && mounted) viewModel.setSort(sort);
  }

  /// "⋮" (`MGT-03.menu`): açılır menü → "Üye listesini dışa aktar (CSV)".
  Future<void> openMenu() async {
    final action = await _feedback.showMenu<ManageMembersMenuAction>(
      scrimKey: scrimKey,
      items: [
        GuPopMenuItem(
          key: exportKey,
          label: context.l10n.mgtMembersExport,
          icon: GuIcons.download,
          value: ManageMembersMenuAction.export,
        ),
      ],
    );
    if (action != ManageMembersMenuAction.export || !mounted) return;
    await exportCsv();
  }

  /// CSV dışa aktarma → paylaşım → TST-29 (danışman → TST-26).
  Future<bool> exportCsv() {
    final l10n = context.l10n;
    return viewModel.exportCsv((
      role: (role) => MemberRow.roleBadge(l10n, role).label,
      department: (code) =>
          mounted ? StaticLabels.department(context, code) : code,
      year: (year) => mounted ? StaticLabels.year(context, year) : year.name,
    ));
  }

  /// Satır menüsü (`MGT-03.menu.<id>`): SHT-21 → rol / çıkarma ViewModel'de
  /// (`ManageMemberActionsMixin`); "Profili gör" → CLB-07.
  Future<void> openMemberMenu(MembershipModel membership) async {
    final outcome = await viewModel.openMemberMenu(membership);
    if (!mounted || outcome != MemberMenuOutcome.viewProfile) return;
    openProfile(membership.userId);
  }

  /// "Başkanlığı devret" (`MGT-03.transfer`; W-14 / W-34 açılışı): SHT-25
  /// (etkin üye / yönetim kurulu adayları) → DLG-21 ("DEVRET") → yazım →
  /// TST-49.
  Future<void> openTransfer() async {
    if (!mounted) return;
    await viewModel.startTransfer();
  }

  void _loadMoreIfNearEnd() {
    if (!mounted || !scrollController.hasClients || !_state.wantsMore) return;
    final position = scrollController.position;
    if (position.extentAfter < position.viewportDimension) {
      unawaited(viewModel.loadMore());
    }
  }
}
