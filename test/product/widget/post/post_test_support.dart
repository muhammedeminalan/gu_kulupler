// T-20 · gönderi widget'ı testlerinin ortak düzeneği: demo `c01` gönderileri
// (duyuru `p01`, görselli `p02`, anket `p04`), yazarları, anket sayıları,
// görsel listesi ve saat ezmesi.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fixtures/club_model_fixtures.dart';
import '../../../fixtures/demo_data.dart';
import '../../../fixtures/post_model_fixtures.dart';
import '../../../fixtures/user_model_fixtures.dart';
import '../../../helpers/fake_app_clock.dart';
import '../../../helpers/pump_app.dart';

const Locale kTr = Locale('tr');
const Locale kEn = Locale('en');

/// Demo `c01` — Yazılım ve Yapay Zekâ Topluluğu (kırmızı palet).
final ClubModel kClub = ClubModelFixtures.c01;

/// `p01` — sabitlenmiş, bildirimi gönderilmiş duyuru (46 beğeni, 3 yorum).
final PostModel kAnnouncement = PostModelFixtures.p01;

/// `p02` — iki görselli gönderi.
final PostModel kImagePost = PostModelFixtures.p02;

/// `p04` — dört seçenekli anket (`o1`…`o4`), oy verince sonuç gösterir.
final PostModel kPollPost = PostModelFixtures.p04;

/// `p04` anketi.
final PollModel kPoll = kPollPost.poll!;

/// `p04` oy sayıları (demo veri): 41 oy → %24, %22, %17, %37.
const Map<String, int> kPollResults = {'o1': 10, 'o2': 9, 'o3': 7, 'o4': 15};

/// Fixture'ların kurulduğu an (demo verinin "bugün"ü): anket açık.
final DateTime kPostNow = DemoDataFixture.today;

/// [post] gönderisinin yazarı (demo veri).
UserModel authorOf(PostModel post) => UserModelFixtures.byId(post.authorId);

/// [count] görsellik liste.
List<PostImageModel> imagesOf(int count) => [
  for (var index = 0; index < count; index++)
    PostImageModel(path: 'posts/p99/img$index.jpg', w: 800, h: 800),
];

/// Saati [now] anına sabitler.
Override clockAt(DateTime now) =>
    appClockProvider.overrideWithValue(FakeAppClock(now));

/// [child]'ı 16 dp dolgulu, kaydırılabilir bir sayfada çizer; saat
/// varsayılan olarak [kPostNow]'dır.
Future<void> pumpPost(
  WidgetTester tester,
  Widget child, {
  Locale locale = kTr,
  ThemeMode theme = ThemeMode.light,
  Size size = const Size(390, 844),
  double textScale = 1,
  DateTime? now,
}) => tester.pumpApp(
  Scaffold(
    body: SingleChildScrollView(
      padding: GuInsets.all16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [child],
      ),
    ),
  ),
  locale: locale,
  theme: theme,
  size: size,
  textScale: textScale,
  overrides: [clockAt(now ?? kPostNow)],
);
