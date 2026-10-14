import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/management/provider/manage_state.dart';
import 'package:gu_kulupler/features/management/provider/manage_view_model.dart';
import 'package:gu_kulupler/features/management/view/manage_view.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/managed_club_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/share_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';

/// MGT-01 davranışı: gezinme (geri, kulüp değiştir, göstergeler, hızlı
/// işlemler, "Tümü" bağlantıları, etkinlik kartı, faaliyet satırı),
/// paylaşım ve çek-yenile.
///
/// * Danışman (Q-09) yazan hızlı işlemlerde ("Gönderi yaz", "Duyuru yap",
///   "Etkinlik oluştur") TST-26 alır (`ManageViewModel.ensureWritable`).
/// * Henüz yazılmamış yönetim ekranları (MGT-02…09) bağlama borcudur:
///   W-36 (T-32), W-37 (T-33), W-38 (T-34), W-39 (T-35), W-40 (T-36);
///   faaliyet satırı başvuru → MGT-02 W-95, ayar → MGT-09 W-96.
mixin ManageViewMixin on ConsumerState<ManageView> {
  /// Başvuru türleri (satır → MGT-02).
  static const Set<ActivityKind> _applicationKinds = {
    ActivityKind.applicationReceived,
    ActivityKind.applicationApproved,
    ActivityKind.applicationRejected,
  };

  /// Ekranın ViewModel'i.
  ManageViewModel get viewModel =>
      ref.read(manageViewModelProvider(widget.clubId).notifier);

  ManageState get _state => ref.read(manageViewModelProvider(widget.clubId));

  FeedbackService get _feedback => ref.read(feedbackServiceProvider);

  /// Geri (`MGT-01.back`): önceki sayfa; yığın yoksa kulüp sayfası (CLB-03).
  void goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      ClubDetailRoute(clubId: widget.clubId).go(context);
    }
  }

  /// "Yeniden dene" (`MGT-01.retry`).
  Future<void> retry() => viewModel.fetch();

  /// Çek-yenile.
  Future<void> refresh() => viewModel.refresh();

  /// Kulüp değiştir (`MGT-01.switchClub`): SHT-18 → seçilen kulübün paneli.
  Future<void> switchClub() => _feedback.showSheet<String>(
    SheetId.sht18,
    builder: (_) => ManagedClubPickerSheet(
      selectedClubId: widget.clubId,
      onSelect: _openPanel,
    ),
  );

  void _openPanel(String clubId) {
    if (!mounted || clubId == widget.clubId) return;
    ManageRoute(clubId: clubId).go(context);
  }

  /// "Henüz üyen yok" → Paylaş (`MGT-01.share`): SHT-15 → seçilen yol.
  Future<void> share() async {
    final club = _state.club;
    if (club == null) return;
    final choice = await _feedback.showSheet<ShareChoice>(
      SheetId.sht15,
      builder: (_) => ShareSheet(title: club.name, url: viewModel.shareUrl()),
    );
    if (choice == null || !mounted) return;
    await viewModel.share(choice);
  }

  /// "Toplam üye" (`MGT-01.kpi.members`) / "Üyeler"
  /// (`MGT-01.quick.members`) → MGT-03.
  void openMembers() {
    // TODO(T-33): `ManageMembersRoute(clubId:).go` (MGT-03; W-37).
  }

  /// "Bekleyen başvuru" (`MGT-01.kpi.pending`) → MGT-02.
  void openApplications() {
    // TODO(T-32): `ManageApplicationsRoute(clubId:).go` (MGT-02; W-36).
  }

  /// "Yaklaşan etkinlik" (`MGT-01.kpi.events`) / "Tümü"
  /// (`MGT-01.eventsAll`) → MGT-04.
  void openEvents() {
    // TODO(T-34): `ManageEventsRoute(clubId:).go` (MGT-04; W-38).
  }

  /// "Bu ay duyuru" (`MGT-01.kpi.announcements`) → MGT-08 duyurular sekmesi.
  void openAnnouncements() {
    // TODO(T-36): `ManageContentRoute(clubId:)` duyurular sekmesi (MGT-08;
    // W-40).
  }

  /// "Kulüp ayarları" (`MGT-01.quick.settings`) → MGT-09.
  void openSettings() {
    // TODO(T-36): `ClubSettingsRoute(clubId:).go` (MGT-09; W-40).
  }

  /// "Gönderi yaz" (`MGT-01.quick.post`) → FED-03.
  void composePost() {
    if (!viewModel.ensureWritable()) return;
    ComposeRoute(clubId: widget.clubId).go(context);
  }

  /// "Duyuru yap" (`MGT-01.quick.announce`) → FED-03.
  void composeAnnouncement() {
    if (!viewModel.ensureWritable()) return;
    // TODO(T-36): FED-03 rotası tür taşımaz (`ComposeRoute({clubId, edit})`);
    // duyuru türü ön seçimi rota parametresi ister (W-97).
    ComposeRoute(clubId: widget.clubId).go(context);
  }

  /// "Etkinlik oluştur" (`MGT-01.quick.event`) → MGT-05.
  void createEvent() {
    if (!viewModel.ensureWritable()) return;
    // TODO(T-34): `EventFormRoute(clubId:).go` (MGT-05; W-38).
  }

  /// "Yoklama al" (`MGT-01.quick.attendance`) → MGT-06; etkinlik yoksa
  /// TST-X12.
  void takeAttendance() {
    final eventId = viewModel.nextAttendanceEventId();
    if (eventId == null) return;
    openAttendance(eventId);
  }

  /// Yaklaşan etkinlik kartı (`MGT-01.event.<id>`) → MGT-06.
  void openAttendance(String eventId) {
    // TODO(T-35): `AttendanceRoute(clubId:, eventId:).go` (MGT-06; W-39).
  }

  /// "Tümü" (`MGT-01.activityAll`) → MGT-10.
  void openActivityLog() => ActivityLogRoute(clubId: widget.clubId).go(context);

  /// Faaliyet satırı (`MGT-01.row.<id>`) — prototip `ActivityRow.go`
  /// (`screens-manage.js:37`): etkinlik → EVT-02 · gönderi → FED-02 ·
  /// başvuru → MGT-02 · hedef kullanıcı → CLB-07 · diğer → MGT-09.
  void openActivity(ActivityModel activity) {
    final refs = activity.refs;
    final eventId = refs.eventId;
    final postId = refs.postId;
    final userId = refs.userId;
    if (eventId != null && !_state.lookups.missing.contains(eventId)) {
      EventDetailRoute(eventId: eventId).go(context);
    } else if (postId != null) {
      PostDetailRoute(clubId: widget.clubId, postId: postId).go(context);
    } else if (_applicationKinds.contains(activity.kind)) {
      openApplications();
    } else if (userId != null) {
      ClubUserProfileRoute(userId: userId, clubId: widget.clubId).go(context);
    } else {
      openSettings();
    }
  }

  /// Danışman bakışında devre dışı yazma eylemi → TST-26.
  void onReadOnly() => viewModel.onReadOnlyTap();
}
