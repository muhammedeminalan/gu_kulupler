// ADM-04 testlerinin ortak verisi: tasarım yakalamasındaki görünüm —
// `u_admin` (süper admin): demo verinin 5 açık şikayet grubu (yorum cm24
// "Taciz veya zorbalık" · gönderi p24 "Uygunsuz içerik" · gönderi p17
// "Spam" 3 şikayet · kullanıcı u077 Nisa Yıldırım "Diğer" · kulüp c10
// E-Spor Kulübü "Yanlış bilgi") ve 3 çözülmüş grup. Zamanlar, satırlar
// tasarımdaki göreli zamanları ("10 saat önce" … "3 gün önce") göstersin
// diye [kReportsDemoNow] ile kaydırılır (`FakeAppClock` varsayılan anı).
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/admin/provider/admin_reports_state.dart';
import 'package:gu_kulupler/features/admin/provider/report_group.dart';
import 'package:gu_kulupler/features/admin/provider/report_target_preview.dart';
import 'package:gu_kulupler/product/navigation/admin_reports_tab.dart';

import '../../fakes/fake_admin_repository.dart';
import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_comment_repository.dart';
import '../../fakes/fake_post_repository.dart';
import '../../fakes/fake_user_repository.dart';
import '../../fixtures/club_model_fixtures.dart';
import '../../fixtures/comment_model_fixtures.dart';
import '../../fixtures/demo_data.dart';
import '../../fixtures/post_model_fixtures.dart';
import '../../fixtures/user_model_fixtures.dart';

/// Demo veri dönüşümünün "şimdi"si: yorum cm24'ün şikayeti
/// `kDefaultFakeNowUtc` − 10 sa olur (tasarım "10 saat önce").
final DateTime kReportsDemoNow = DateTime.utc(2026, 10, 11, 21, 21, 18);

/// Tasarımdaki açık grupların sırası (son şikayet en yeni üstte).
const List<String> kOpenGroupKeys = [
  'comment_cm24',
  'post_p24',
  'post_p17',
  'user_u077',
  'club_c10',
];

/// Çözülmüş demo grupları.
const List<String> kResolvedGroupKeys = [
  'post_p13',
  'comment_cm12',
  'user_u007',
];

/// Demo verinin şikayet belgeleri (şikayetçi başına bir belge).
List<ReportModel> demoReports() => [
  for (final id in DemoDataFixture.ids(
    FirestoreCollections.reports,
    now: kReportsDemoNow,
  ))
    ReportModel.fromJson(
      DemoDataFixture.toFirestoreJson(
        FirestoreCollections.reports,
        id,
        now: kReportsDemoNow,
      ),
      id: id,
    ),
];

/// [status] durumundaki demo şikayetler.
List<ReportModel> demoReportsWith(ReportStatus status) => [
  for (final report in demoReports())
    if (report.status == status) report,
];

/// Satır önizlemeleri (ViewModel'in okuyacağı hedefler).
Map<String, ReportTargetPreview> demoPreviews() => {
  'comment_cm24': ReportTargetPreview(
    comment: CommentModelFixtures.byId('cm24'),
  ),
  'post_p24': ReportTargetPreview(post: PostModelFixtures.byId('p24')),
  'post_p17': ReportTargetPreview(post: PostModelFixtures.byId('p17')),
  'user_u077': ReportTargetPreview(user: UserModelFixtures.byId('u077')),
  'club_c10': ReportTargetPreview(club: ClubModelFixtures.byId('c10')),
};

/// Tasarımdaki dolu görünüm (ViewModel'in üreteceği biçimde).
AdminReportsState loadedAdminReportsState({
  AdminReportsTab tab = AdminReportsTab.open,
}) => AdminReportsState(
  tab: tab,
  openReports: demoReportsWith(ReportStatus.open),
  resolvedReports: demoReportsWith(ReportStatus.resolved),
  loadedTabs: AdminReportsTab.values.toSet(),
  previews: demoPreviews(),
);

/// Demo açık grubu [key].
ReportGroup demoGroup(String key) => ReportGroup.groupOf(
  demoReports(),
).firstWhere((group) => group.key == key);

/// Kayıtlı fake'lere şikayetleri ve hedef belgelerini yazar (yorum hedefleri
/// cm24 · cm12 — `CommentRepository.getComment`, W-103).
void seedAdminReports() {
  final admin = GetIt.I<AdminRepository>() as FakeAdminRepository;
  for (final report in demoReports()) {
    admin.reports[report.id] = report;
  }
  final posts = GetIt.I<PostRepository>() as FakePostRepository;
  for (final id in ['p13', 'p17', 'p24']) {
    posts.posts[id] = PostModelFixtures.byId(id);
  }
  final comments = GetIt.I<CommentRepository>() as FakeCommentRepository;
  for (final id in ['cm24', 'cm12']) {
    comments.put(CommentModelFixtures.byId(id));
  }
  final users = (GetIt.I<UserRepository>() as FakeUserRepository).users;
  for (final id in ['u077', 'u007', 'u044', 'u051', 'u052', 'u053']) {
    users[id] = UserModelFixtures.byId(id);
  }
  (GetIt.I<ClubRepository>() as FakeClubRepository).clubs['c10'] =
      ClubModelFixtures.byId('c10');
}
