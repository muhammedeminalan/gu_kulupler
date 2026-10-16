// T-27 · profil fotoğrafı çözümü: `users.avatarPath` → görsel; silinmiş /
// anonimleştirilmiş kullanıcı ya da fotoğrafsız kullanıcı → `null` (baş
// harfler). `UserRow` görseli avatara geçirir.
//
// Tasarım hataları turu · madde 5: fotoğrafı olan kullanıcının fotoğrafı her
// avatar yerinde (gönderi kartı, yorum, üye / katılımcı / başvuru satırı,
// kimlikten çözülen CLB-03 önizlemesi), olmayanda baş harfler; kimlikten
// çözülen liste tek toplu okuma yapar; oturumdaki kullanıcının avatarı
// önbellekteki eski belge yerine oturumun güncel belgesinden gelir.
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_members_tab.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/president_picker_sheet.dart';
import 'package:gu_kulupler/product/media/image_url_cache.dart';
import 'package:gu_kulupler/product/media/post_image_resolver.dart';
import 'package:gu_kulupler/product/media/user_avatar_image.dart';
import 'package:gu_kulupler/product/widget/member/application_row.dart';
import 'package:gu_kulupler/product/widget/member/attendee_row.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_kulupler/product/widget/member/user_row.dart';
import 'package:gu_kulupler/product/widget/post/comment_row.dart';
import 'package:gu_kulupler/product/widget/post/post_card.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_user_repository.dart';
import '../../fixtures/comment_model_fixtures.dart';
import '../../fixtures/membership_model_fixtures.dart';
import '../../fixtures/post_model_fixtures.dart';
import '../../fixtures/rsvp_model_fixtures.dart';
import '../../fixtures/user_model_fixtures.dart';
import '../../helpers/fake_app_clock.dart';
import '../../helpers/pump_app.dart';

final ImageProvider _image = MemoryImage(Uint8List(0));

final Uint8List _onePixelPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Ağ ve disk önbelleği olmadan çizilen avatar: Storage yolunu taşır.
final class _AvatarImage extends MemoryImage {
  _AvatarImage(this.path) : super(_onePixelPng);

  final String path;
}

/// İndirme adresi her yol için hemen gelir; görsel [_AvatarImage]'dır.
final List<Override> _imageOverrides = [
  imageUrlCacheProvider.overrideWith((ref) {
    final cache = ImageUrlCache(
      fetch: (path) async => FirebaseSuccess('https://img.test/$path'),
      clock: FakeAppClock(DateTime.utc(2026, 10, 16)),
    );
    ref.onDispose(cache.dispose);
    return cache;
  }),
  storageImageFactoryProvider.overrideWithValue(
    (url, path, {coverEdgePx}) => _AvatarImage(path),
  ),
];

/// Çocuktan önce (ilk karede, toplu okuma mikro görevinden önce) sahte
/// depoya kullanıcı yazar: `pumpApp` GetIt'i çizimden hemen önce kurar.
class _Seed extends StatelessWidget {
  const _Seed({required this.users, required this.child});

  final List<UserModel> users;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final repository = GetIt.I<UserRepository>() as FakeUserRepository;
    for (final user in users) {
      repository.users[user.uid] = user;
    }
    return child;
  }
}

FakeUserRepository _users() => GetIt.I<UserRepository>() as FakeUserRepository;

/// [of] altındaki avatarların fotoğraf yolları (`null` → baş harfler).
List<String?> _avatarPaths(WidgetTester tester, Finder of) => [
  for (final avatar in tester.widgetList<GuAvatar>(
    find.descendant(of: of, matching: find.byType(GuAvatar)),
  ))
    switch (avatar.image) {
      final _AvatarImage image => image.path,
      null => null,
      final other => fail('beklenmeyen görsel: $other'),
    },
];

void main() {
  final requested = <String?>[];
  ImageProvider? resolve(String? path, {int? coverEdgePx}) {
    requested.add(path);
    return path == null ? null : _image;
  }

  setUp(requested.clear);

  final resolver = resolve;
  final withPhoto = UserModelFixtures.ayse.copyWith(
    avatarPath: 'users/u_ayse/a.jpg',
  );

  test('fotoğraflı kullanıcı → çözücünün görseli (avatarPath yolu)', () {
    expect(resolver.userAvatar(withPhoto), same(_image));
    expect(requested, ['users/u_ayse/a.jpg']);
  });

  test('kullanıcı yok, fotoğraf yok, silinmiş ya da anonim → null', () {
    expect(resolver.userAvatar(null), isNull);
    expect(resolver.userAvatar(UserModelFixtures.ayse), isNull);
    expect(resolver.userAvatar(withPhoto.copyWith(isDeleted: true)), isNull);
    expect(
      resolver.userAvatar(withPhoto.copyWith(status: UserStatus.deleted)),
      isNull,
    );
    // Silinmiş / anonim kullanıcı için istek de atılmaz.
    expect(requested, [null]);
  });

  testWidgets('UserRow görseli avatara geçirir; yoksa baş harfler', (
    tester,
  ) async {
    await tester.pumpApp(
      Column(
        children: [
          UserRow(user: withPhoto, avatarImage: _image),
          UserRow(user: UserModelFixtures.ayse),
        ],
      ),
    );
    final avatars = tester.widgetList<GuAvatar>(find.byType(GuAvatar));
    expect(avatars.map((avatar) => avatar.image), [same(_image), isNull]);
  });

  group('madde 5 · her avatar yerinde fotoğraf', () {
    const zeynepPath = 'users/u_zeynep/20261013T090000Z_0001020304050607.jpg';
    final zeynep = UserModelFixtures.byId(
      'u_zeynep',
    ).copyWith(avatarPath: zeynepPath);
    final mehmet = UserModelFixtures.byId('u_mehmet');

    testWidgets('gönderi kartı, yorum, üye / katılımcı / başvuru satırı: '
        'fotoğraflıda görsel, fotoğrafsızda baş harf', (tester) async {
      final post = PostModelFixtures.p01;
      final comment = CommentModelFixtures.cm01;
      final membership = MembershipModelFixtures.c01Mehmet;
      final application = membership.copyWith(
        status: MembershipStatus.pending,
      );
      final rsvp = RsvpModelFixtures.e01Mehmet;
      Widget rows(UserModel user) => Consumer(
        builder: (context, ref, _) {
          ImageProvider? image(double size) =>
              ref.userAvatarImage(user, displaySize: size);
          return Column(
            children: [
              PostCard(
                post: post,
                author: user,
                authorAvatar: image(GuSizes.postAvatar),
              ),
              CommentRow(
                comment: comment,
                author: user,
                authorAvatar: image(GuSizes.commentAvatar),
              ),
              MemberRow(
                membership: membership,
                user: user,
                avatarImage: image(GuSizes.avatar),
              ),
              AttendeeRow(
                rsvp: rsvp,
                name: user.name,
                attended: false,
                onToggle: (_) {},
                avatarImage: image(GuSizes.avatar),
              ),
              ApplicationRow(
                application: application,
                user: user,
                timeLabel: '1 sa',
                actionKey: GuKey.action('MGT-04.row.${user.uid}'),
                onOpen: () {},
                avatarImage: image(GuSizes.applicationRowAvatar),
              ),
            ],
          );
        },
      );
      await tester.pumpApp(
        SingleChildScrollView(
          child: Column(
            children: [
              KeyedSubtree(key: const ValueKey('photo'), child: rows(zeynep)),
              KeyedSubtree(key: const ValueKey('none'), child: rows(mehmet)),
            ],
          ),
        ),
        overrides: _imageOverrides,
        size: const Size(390, 3000),
      );
      await tester.pumpAndSettle();

      for (final type in [
        PostCard,
        CommentRow,
        MemberRow,
        AttendeeRow,
        ApplicationRow,
      ]) {
        expect(
          _avatarPaths(
            tester,
            find.descendant(
              of: find.byKey(const ValueKey('photo')),
              matching: find.byType(type),
            ),
          ),
          [zeynepPath],
          reason: '$type fotoğraflı',
        );
        expect(
          _avatarPaths(
            tester,
            find.descendant(
              of: find.byKey(const ValueKey('none')),
              matching: find.byType(type),
            ),
          ),
          [null],
          reason: '$type fotoğrafsız',
        );
      }
    });

    testWidgets('kimlikten çözüm (CLB-03 üye önizlemesi): tek toplu okuma; '
        'fotoğraflıda görsel, fotoğrafsızda baş harf', (tester) async {
      final members = [
        MembershipModelFixtures.byId('c01_u_p_c01'),
        MembershipModelFixtures.byId('c01_u_zeynep'),
        MembershipModelFixtures.c01Mehmet,
      ];
      await tester.pumpApp(
        _Seed(
          users: [UserModelFixtures.byId('u_p_c01'), zeynep, mehmet],
          child: ClubMembersTab(
            memberCount: 3,
            members: members,
            onMember: (_) {},
            onAllMembers: () {},
            memberKeyOf: (id) => GuKey.action('CLB-03.member.$id'),
          ),
        ),
        overrides: _imageOverrides,
      );
      await tester.pumpAndSettle();

      expect(_avatarPaths(tester, find.byType(ClubMembersTab)), [
        null,
        zeynepPath,
        null,
      ]);
      // Satır başına değil, liste başına tek okuma (N+1 yok).
      final reads = _users().callsTo('getUsers');
      expect(reads, hasLength(1));
      expect(reads.single.args.single, ['u_p_c01', 'u_zeynep', 'u_mehmet']);
    });

    testWidgets('okuma hatası: baş harfler kalır (yer değişimi yok)', (
      tester,
    ) async {
      await tester.pumpApp(
        _Seed(
          users: [zeynep],
          child: Builder(
            builder: (context) {
              _users().failNext(FirestoreError.unavailable);
              return ClubMembersTab(
                memberCount: 1,
                members: [MembershipModelFixtures.byId('c01_u_zeynep')],
                onMember: (_) {},
                onAllMembers: () {},
                memberKeyOf: (id) => GuKey.action('CLB-03.member.$id'),
              );
            },
          ),
        ),
        overrides: _imageOverrides,
      );
      await tester.pumpAndSettle();

      expect(_avatarPaths(tester, find.byType(ClubMembersTab)), [null]);
      expect(find.text(zeynep.name.initials), findsOneWidget);
    });

    testWidgets('oturumdaki kullanıcı: listedeki eski belge yerine oturumun '
        'güncel fotoğrafı (kendi gönderin / üye satırın)', (tester) async {
      const freshPath = 'users/u_mehmet/20261016T090000Z_0001020304050607.jpg';
      final session = SessionState(
        status: AuthStatus.active,
        uid: mehmet.uid,
        user: mehmet.copyWith(avatarPath: freshPath),
      );
      await tester.pumpApp(
        Consumer(
          builder: (context, ref, _) {
            // Uygulamada oturum hep kuruludur (yönlendirme izler).
            ref.watch(sessionViewModelProvider);
            return Column(
              children: [
                // Önbellekten gelen eski belge: fotoğraf yok.
                PostCard(
                  post: PostModelFixtures.p01,
                  author: mehmet,
                  authorAvatar: ref.userAvatarImage(
                    mehmet,
                    displaySize: GuSizes.postAvatar,
                  ),
                ),
                MemberRow(
                  membership: MembershipModelFixtures.c01Mehmet,
                  avatarImage: ref.userAvatarImageOf(
                    mehmet.uid,
                    displaySize: GuSizes.avatar,
                  ),
                ),
              ],
            );
          },
        ),
        overrides: [
          ..._imageOverrides,
          sessionViewModelProvider.overrideWithBuild((ref, _) => session),
        ],
      );
      await tester.pumpAndSettle();

      expect(_avatarPaths(tester, find.byType(PostCard)), [freshPath]);
      expect(_avatarPaths(tester, find.byType(MemberRow)), [freshPath]);
      // Kendi kimliği için toplu okuma yapılmaz.
      expect(_users().callsTo('getUsers'), isEmpty);
    });

    testWidgets('SHT-25 atama kipi: aday belgesi elde → fotoğraf ondan, '
        'toplu okuma yok; devir kipi (anlık görüntü) dizinden okur', (
      tester,
    ) async {
      await tester.pumpApp(
        _Seed(
          users: [zeynep, mehmet],
          child: PresidentPickerSheet(
            mode: PresidentPickerMode.assign,
            candidates: [
              PresidentCandidate.fromUser(zeynep),
              PresidentCandidate.fromUser(mehmet),
            ],
          ),
        ),
        overrides: _imageOverrides,
      );
      await tester.pumpAndSettle();
      expect(
        _avatarPaths(tester, find.byType(PresidentPickerSheet)),
        unorderedEquals(<String?>[null, zeynepPath]),
      );
      expect(_users().callsTo('getUsers'), isEmpty);

      await tester.pumpApp(
        _Seed(
          users: [zeynep],
          child: PresidentPickerSheet(
            candidates: [
              PresidentCandidate.fromMembership(
                MembershipModelFixtures.byId('c01_u_zeynep'),
              ),
            ],
          ),
        ),
        overrides: _imageOverrides,
      );
      await tester.pumpAndSettle();
      expect(_avatarPaths(tester, find.byType(PresidentPickerSheet)), [
        zeynepPath,
      ]);
      expect(_users().callsTo('getUsers'), hasLength(1));
    });
  });
}
