// SHT-26 · Şikayet detayı — hedef türü × durum varyantları (rozetler,
// önizleme, şikayet satırları, çözüm bandı), alt bilgi eylem kümesi ve
// sırası (anahtarlar `SHT-26.*`), seçim sonucu ([ReportDetailAction]),
// bekleyen eylem, alt bilgi yerleşimi (yan yana / alt alta), kapatma, cihaz
// matrisi, açık + koyu golden. Referans: design/reference-shots/sheets/
// SHT-26__*.webp, design/prototype/app/sheets.js:120–128.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/admin/provider/report_group.dart';
import 'package:gu_kulupler/features/admin/provider/report_target_preview.dart';
import 'package:gu_kulupler/features/admin/view/widget/report_detail_sheet.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/widget/member/user_row.dart';
import 'package:gu_kulupler/product/widget/post/post_card.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../../fakes/register_fakes.dart';
import '../../../../fixtures/club_model_fixtures.dart';
import '../../../../fixtures/comment_model_fixtures.dart';
import '../../../../fixtures/event_model_fixtures.dart';
import '../../../../fixtures/post_model_fixtures.dart';
import '../../../../fixtures/user_model_fixtures.dart';
import '../../../../helpers/device_matrix.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../product/feedback/sheet_test_support.dart';

/// Demo `r01`: `p17` gönderisine 3 spam şikayeti (en eski önce; zamanlar
/// varsayılan saat anına göre "Dün", "Dün", "20 saat önce").
ReportModel _report(
  String reporter,
  ReportTargetType type,
  String target, {
  ReportReason reason = ReportReason.spam,
  String note = '',
  int hoursAgo = 1,
  ReportStatus status = ReportStatus.open,
  ReportAction? action,
}) => ReportModel(
  targetType: type,
  targetId: target,
  reporterId: reporter,
  reason: reason,
  note: note,
  status: status,
  action: action,
  createdAt: kDefaultFakeNowUtc.subtract(Duration(hours: hoursAgo)),
  resolvedAt: status == ReportStatus.resolved
      ? DateTime.utc(2026, 10, 10, 9, 15)
      : null,
);

final PostModel _post = PostModelFixtures.byId('p17');

ReportGroup _postGroup({ReportStatus status = ReportStatus.open}) {
  final action = status == ReportStatus.resolved ? ReportAction.removed : null;
  return ReportGroup.groupOf([
    _report(
      'u051',
      ReportTargetType.post,
      'p17',
      note: 'Aynı bağlantı üç kez paylaşıldı.',
      hoursAgo: 30,
      status: status,
      action: action,
    ),
    _report(
      'u052',
      ReportTargetType.post,
      'p17',
      hoursAgo: 28,
      status: status,
      action: action,
    ),
    _report(
      'u053',
      ReportTargetType.post,
      'p17',
      note: 'Reklam gibi duruyor.',
      hoursAgo: 20,
      status: status,
      action: action,
    ),
  ]).single;
}

ReportGroup _single(ReportTargetType type, String target) =>
    ReportGroup.groupOf([
      _report('u062', type, target, reason: ReportReason.other),
    ]).single;

final Map<String, UserModel> _reporters = {
  for (final id in ['u051', 'u052', 'u053', 'u062'])
    id: UserModelFixtures.byId(id),
};

ReportTargetPreview _postPreview() => ReportTargetPreview(
  post: _post,
  author: UserModelFixtures.byId(_post.authorId),
  club: ClubModelFixtures.byId(_post.clubId),
);

ReportDetailSheet _sheet(
  ReportGroup group,
  ReportTargetPreview? preview, {
  ValueChanged<ReportDetailAction>? onAction,
  ReportDetailAction? pending,
}) => ReportDetailSheet(
  group: group,
  preview: preview,
  reporters: _reporters,
  pendingAction: pending,
  onAction: onAction ?? (_) {},
);

Future<SheetHarness<Object>> _open(
  WidgetTester tester,
  ReportDetailSheet sheet,
) async {
  final h = SheetHarness<Object>(SheetId.sht26, (_) => sheet);
  await h.pump(tester);
  await h.open(tester);
  return h;
}

/// Alt bilgide görünen eylemler, ekrandaki sırayla (soldan sağa, üstten
/// alta).
List<ReportDetailAction> _footer(WidgetTester tester) {
  final found =
      [
        for (final action in ReportDetailAction.values)
          if (find
              .byKey(ReportDetailSheet.actionKey(action))
              .evaluate()
              .isNotEmpty)
            (
              action,
              tester.getTopLeft(
                find.byKey(ReportDetailSheet.actionKey(action)),
              ),
            ),
      ]..sort((a, b) {
        final dy = a.$2.dy.compareTo(b.$2.dy);
        return dy != 0 ? dy : a.$2.dx.compareTo(b.$2.dx);
      });
  return [for (final (action, _) in found) action];
}

void main() {
  group('SHT-26 · ReportDetailSheet', () {
    testWidgets('gönderi · açık: rozetler, PostCard önizlemesi, "3 şikayet" '
        'satırları (en eski üstte, not), üç eylem', (tester) async {
      await _open(tester, _sheet(_postGroup(), _postPreview()));

      expect(find.text('Şikayet detayı'), findsOneWidget);
      expect(find.text('Gönderi'), findsOneWidget);
      expect(find.text('Açık'), findsOneWidget);
      final card = tester.widget<PostCard>(find.byType(PostCard));
      expect(card.post, _post);
      expect(card.hideActions, isTrue);
      expect(card.showClub, isTrue);
      expect(find.text('Ayça Öztürk'), findsOneWidget);
      expect(find.text('3 şikayet'), findsOneWidget);
      expect(find.text('Spam'), findsNWidgets(3));
      expect(find.text('Aynı bağlantı üç kez paylaşıldı.'), findsOneWidget);
      expect(find.text('Reklam gibi duruyor.'), findsOneWidget);
      expect(find.text('20 saat önce'), findsOneWidget);
      expect(find.text('Dün'), findsNWidgets(2));
      final deniz = tester.getTopLeft(find.text('Deniz Kurt')).dy;
      final sude = tester.getTopLeft(find.text('Sude Turan')).dy;
      final hilal = tester.getTopLeft(find.text('Hilal Özkan')).dy;
      expect(deniz < sude && sude < hilal, isTrue);
      expect(_footer(tester), [
        ReportDetailAction.dismiss,
        ReportDetailAction.suspendUser,
        ReportDetailAction.removeContent,
      ]);
      expect(find.byKey(ReportDetailSheet.suspendClubKey), findsNothing);
    });

    testWidgets('eylem dokunuşu seçimi döndürür; bekleyen eylem `loading` ve '
        'başka seçim gönderilmez', (tester) async {
      final picked = <ReportDetailAction>[];
      await _open(
        tester,
        _sheet(_postGroup(), _postPreview(), onAction: picked.add),
      );
      for (final action in [
        ReportDetailAction.dismiss,
        ReportDetailAction.suspendUser,
        ReportDetailAction.removeContent,
      ]) {
        await tester.tap(find.byKey(ReportDetailSheet.actionKey(action)));
        await tester.pump();
      }
      expect(picked, [
        ReportDetailAction.dismiss,
        ReportDetailAction.suspendUser,
        ReportDetailAction.removeContent,
      ]);

      picked.clear();
      // Döner gösterge sürekli çizer: overlay yerine doğrudan çizilir.
      await tester.pumpApp(
        Align(
          alignment: Alignment.bottomCenter,
          child: _sheet(
            _postGroup(),
            _postPreview(),
            onAction: picked.add,
            pending: ReportDetailAction.dismiss,
          ),
        ),
      );
      await tester.pump();
      expect(
        tester
            .widget<GuButton>(find.byKey(ReportDetailSheet.closeReportKey))
            .loading,
        isTrue,
      );
      await tester.tap(find.byKey(ReportDetailSheet.removeContentKey));
      await tester.pump();
      expect(picked, isEmpty);
    });

    testWidgets('yorum: yazar + metin; kapat · askıya al · kaldır', (
      tester,
    ) async {
      final comment = CommentModelFixtures.byId('cm24');
      await _open(
        tester,
        _sheet(
          _single(ReportTargetType.comment, 'cm24'),
          ReportTargetPreview(
            comment: comment,
            author: UserModelFixtures.byId(comment.authorId),
          ),
        ),
      );
      expect(find.text('Yorum'), findsOneWidget);
      expect(find.text(comment.text), findsOneWidget);
      expect(find.text('Nisa Yıldırım'), findsOneWidget);
      expect(_footer(tester), [
        ReportDetailAction.dismiss,
        ReportDetailAction.suspendUser,
        ReportDetailAction.removeContent,
      ]);
    });

    testWidgets('kullanıcı: UserRow; kapat · askıya al (kaldır yok)', (
      tester,
    ) async {
      final user = UserModelFixtures.byId('u077');
      await _open(
        tester,
        _sheet(
          _single(ReportTargetType.user, 'u077'),
          ReportTargetPreview(user: user),
        ),
      );
      expect(find.text('Kullanıcı'), findsOneWidget);
      expect(tester.widget<UserRow>(find.byType(UserRow)).user, user);
      expect(_footer(tester), [
        ReportDetailAction.dismiss,
        ReportDetailAction.suspendUser,
      ]);
    });

    testWidgets('kulüp: amblem + ad; kapat · kulübü askıya al', (tester) async {
      final club = ClubModelFixtures.byId('c10');
      await _open(
        tester,
        _sheet(
          _single(ReportTargetType.club, 'c10'),
          ReportTargetPreview(club: club),
        ),
      );
      expect(find.text('Kulüp'), findsOneWidget);
      expect(find.text(club.name), findsOneWidget);
      expect(find.byType(GuEmblem), findsOneWidget);
      expect(_footer(tester), [
        ReportDetailAction.dismiss,
        ReportDetailAction.suspendClub,
      ]);
      expect(
        find.descendant(
          of: find.byKey(ReportDetailSheet.suspendClubKey),
          matching: find.text('Askıya al'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('etkinlik: amblem + başlık; yalnız kapat', (tester) async {
      final event = EventModelFixtures.e01;
      await _open(
        tester,
        _sheet(
          _single(ReportTargetType.event, event.id),
          ReportTargetPreview(event: event),
        ),
      );
      expect(find.text('Etkinlik'), findsOneWidget);
      expect(find.text(event.title), findsOneWidget);
      expect(_footer(tester), [ReportDetailAction.dismiss]);
    });

    testWidgets('hedef yok: "İçerik kaldırıldı"; yazar bilinmediği için '
        'askıya alma yok', (tester) async {
      await _open(tester, _sheet(_postGroup(), const ReportTargetPreview()));
      expect(find.text('İçerik kaldırıldı'), findsOneWidget);
      expect(find.byType(PostCard), findsNothing);
      expect(_footer(tester), [
        ReportDetailAction.dismiss,
        ReportDetailAction.removeContent,
      ]);
    });

    testWidgets('önizleme yükleniyor: iskelet', (tester) async {
      await _open(tester, _sheet(_postGroup(), null));
      expect(find.byType(GuSkeletonList), findsOneWidget);
      expect(find.byType(PostCard), findsNothing);
      expect(find.text('3 şikayet'), findsOneWidget);
    });

    testWidgets('çözülmüş: "Çözüldü" + işlem rozeti, çözüm bandı; salt okunur '
        '(alt bilgi yok)', (tester) async {
      await _open(
        tester,
        _sheet(_postGroup(status: ReportStatus.resolved), _postPreview()),
      );
      expect(find.text('Çözüldü'), findsOneWidget);
      expect(find.text('İçerik kaldırıldı'), findsOneWidget);
      final banner = tester.widget<GuBanner>(find.byType(GuBanner));
      expect(banner.kind, GuBannerKind.success);
      expect(banner.text, endsWith('tarihinde çözüldü: İçerik kaldırıldı'));
      expect(_footer(tester), isEmpty);
    });

    testWidgets('alt bilgi: sığan düğmeler yan yana (kulüp, 390), sığmayan '
        'üçlü alt alta tam genişlik (gönderi)', (tester) async {
      await _open(
        tester,
        _sheet(
          _single(ReportTargetType.club, 'c10'),
          ReportTargetPreview(club: ClubModelFixtures.byId('c10')),
        ),
      );
      final close = tester.getRect(
        find.byKey(ReportDetailSheet.closeReportKey),
      );
      final suspend = tester.getRect(
        find.byKey(ReportDetailSheet.suspendClubKey),
      );
      expect(close.top, suspend.top);
      expect(close.width, closeTo(suspend.width, 1));

      await _open(tester, _sheet(_postGroup(), _postPreview()));
      final rects = [
        for (final action in [
          ReportDetailAction.dismiss,
          ReportDetailAction.suspendUser,
          ReportDetailAction.removeContent,
        ])
          tester.getRect(find.byKey(ReportDetailSheet.actionKey(action))),
      ];
      expect(
        rects[0].top < rects[1].top && rects[1].top < rects[2].top,
        isTrue,
      );
      expect(rects.map((r) => r.width).toSet(), hasLength(1));
    });

    testWidgets("SHT-26.close sheet'i kapatır", (tester) async {
      final h = await _open(tester, _sheet(_postGroup(), _postPreview()));
      await tester.tap(find.byKey(ReportDetailSheet.closeKey));
      await tester.pumpAndSettle();
      expect(h.isClosed, isTrue);
      expect(h.result, isNull);
    });

    testWidgets('cihaz matrisi: taşma yok (gönderi · açık)', (tester) async {
      await DeviceMatrix.run(
        tester,
        (context) => Align(
          alignment: Alignment.bottomCenter,
          child: _sheet(_postGroup(), _postPreview()),
        ),
      );
    });

    testWidgets('golden: gönderi · açık — açık + koyu (TR)', (tester) async {
      await SheetHarness<Object>(
        SheetId.sht26,
        (_) => _sheet(_postGroup(), _postPreview()),
      ).golden(tester, 'SHT-26');
    });
  });
}
