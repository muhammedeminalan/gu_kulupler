import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/management/provider/manage_content_state.dart';
import 'package:gu_kulupler/features/management/provider/manage_content_view_model.dart';
import 'package:gu_kulupler/features/management/view/manage_content_view.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/managed_club_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/post_menu.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/mixin/post_actions_mixin.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_ui/gu_ui.dart';

/// MGT-08 davranışı: sekmeler (açılış [ManageContentView.tab]), arama,
/// satır → FED-02, "⋮" → açılır menü (`PopMenu id="MGT-08"`: sabitle /
/// düzenle / sil — yazım ViewModel'deki ortak `PostActionsMixin`'de; view
/// yalnızca gezinir), "Gönderi" FAB → FED-03 (seçili sekmenin türüyle —
/// W-97 `?type=`), sayfalama tetikleyicisi, kulüp değiştir ve geri.
mixin ManageContentViewMixin on ConsumerState<ManageContentView> {
  /// Satır menüsünün saydam scrim'i (`MGT-08.scrim`, `ui.js:191`).
  static final Key scrimKey = GuKey.action('MGT-08.scrim');

  /// Listenin kaydırma denetleyicisi.
  final ScrollController scrollController = ScrollController();

  /// Arama alanının denetleyicisi.
  final TextEditingController searchController = TextEditingController();

  ProviderSubscription<ManageContentState>? _stateSubscription;

  /// Ekranın ViewModel'i.
  ManageContentViewModel get viewModel =>
      ref.read(manageContentViewModelProvider(widget.clubId).notifier);

  ManageContentState get _state =>
      ref.read(manageContentViewModelProvider(widget.clubId));

  FeedbackService get _feedback => ref.read(feedbackServiceProvider);

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_loadMoreIfNearEnd);
    // Sekme / arama listeyi kısaltırsa ya da yeni sayfa ekranı doldurmazsa
    // sonraki sayfa kendiliğinden istenir (sekmeler istemcide süzülür).
    _stateSubscription = ref.listenManual(
      manageContentViewModelProvider(widget.clubId),
      (previous, next) {
        final changed =
            previous == null ||
            previous.cursor != next.cursor ||
            previous.tab != next.tab ||
            previous.query != next.query ||
            previous.isFetching != next.isFetching;
        if (!changed || !next.wantsMore) return;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _loadMoreIfNearEnd(),
        );
      },
    );
    _applyRouteTab();
  }

  @override
  void didUpdateWidget(covariant ManageContentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab != widget.tab) _applyRouteTab();
  }

  @override
  void dispose() {
    _stateSubscription?.close();
    scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  /// Açılış sekmesi ilk karenin ardından seçilir: sağlayıcı ağaç kurulurken
  /// değiştirilemez.
  void _applyRouteTab() {
    final tab = widget.tab;
    if (tab == null) return;
    unawaited(
      Future<void>.microtask(() {
        if (mounted) viewModel.setTab(tab);
      }),
    );
  }

  /// Geri (`MGT-08.back`) → panel (MGT-01). `pop` değil `go`: `?tab=` ile
  /// açılan ekrandan `pop` sorguyu panelin adresine taşır (FED-03 `?type=`
  /// ile aynı — T-36); MGT-08'in tek girişi paneldir.
  void goBack() => ManageRoute(clubId: widget.clubId).go(context);

  /// Kulüp değiştir (`MGT-08.switchClub`): SHT-18 → seçilen kulübün
  /// içeriği.
  Future<void> switchClub() => _feedback.showSheet<String>(
    SheetId.sht18,
    builder: (_) => ManagedClubPickerSheet(
      selectedClubId: widget.clubId,
      onSelect: _openClub,
    ),
  );

  void _openClub(String clubId) {
    if (!mounted || clubId == widget.clubId) return;
    ManageContentRoute(clubId: clubId).go(context);
  }

  /// "Yeniden dene" (`MGT-08.retry`).
  Future<void> retry() => viewModel.fetch();

  /// Çek-yenile.
  Future<void> refresh() => viewModel.refresh();

  /// Sekme (`MGT-08.tab.<posts|announcements|polls>`).
  void selectTab(String name) => viewModel.setTab(PostType.values.byName(name));

  /// Arama alanı (`MGT-08.search`).
  void onQueryChanged(String query) => viewModel.setQuery(query);

  /// Satır (`MGT-08.row.<id>`) → FED-02.
  void openPost(String postId) =>
      PostDetailRoute(clubId: widget.clubId, postId: postId).go(context);

  /// "Gönderi" FAB (`MGT-08.create`) → FED-03; seçili sekmenin türü ön
  /// seçilir (danışman → TST-26).
  void create() {
    if (!viewModel.ensureWritable()) return;
    ComposeRoute(clubId: widget.clubId, type: _state.tab).go(context);
  }

  /// "⋮" (`MGT-08.menu.<id>`): açılır menü — "Sabitle" / "Sabitlemeyi
  /// kaldır" (`MGT-08.pin.<id>`), "Düzenle" (`MGT-08.edit.<id>`; yalnızca
  /// yazara açık), "Sil" (`MGT-08.delete.<id>`, yıkıcı). Danışmanda satırlar
  /// devre dışıdır (`screens-manage.js:167`). Düzenle → FED-03 düzenleme
  /// kipi.
  Future<void> openMenu(PostModel post) async {
    final l10n = context.l10n;
    final state = _state;
    final readOnly = state.isReadOnly;
    final action = await _feedback.showMenu<PostMenuAction>(
      scrimKey: scrimKey,
      items: [
        GuPopMenuItem(
          key: GuKey.action('MGT-08.pin.${post.id}'),
          label: post.pinned ? l10n.postUnpin : l10n.postPin,
          icon: post.pinned ? GuIcons.pinOff : GuIcons.pin,
          disabled: readOnly,
          value: post.pinned ? PostMenuAction.unpin : PostMenuAction.pin,
        ),
        GuPopMenuItem(
          key: GuKey.action('MGT-08.edit.${post.id}'),
          label: l10n.commonEdit,
          icon: GuIcons.pencil,
          disabled: !state.canEdit(post),
          value: PostMenuAction.edit,
        ),
        GuPopMenuItem(
          key: GuKey.action('MGT-08.delete.${post.id}'),
          label: l10n.commonDelete,
          icon: GuIcons.trash2,
          danger: true,
          disabled: readOnly,
          value: PostMenuAction.remove,
        ),
      ],
    );
    if (action == null || !mounted) return;
    final outcome = await viewModel.runMenu(
      action,
      post.id,
      removedLabel: l10n.feedTypePost,
    );
    if (outcome != PostMenuOutcome.edit || !mounted) return;
    ComposeRoute(clubId: widget.clubId, edit: post.id).go(context);
  }

  void _loadMoreIfNearEnd() {
    if (!mounted || !scrollController.hasClients || !_state.wantsMore) return;
    final position = scrollController.position;
    if (position.extentAfter < position.viewportDimension) {
      unawaited(viewModel.loadMore());
    }
  }
}
