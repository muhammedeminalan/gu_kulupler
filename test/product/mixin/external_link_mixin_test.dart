// DLG-32 · Uygulamadan ayrılıyorsun — `ExternalLinkMixin`,
// `confirmAndOpenExternalLink` ve `ExternalLinks`: onay → adresi aç akışı, sonuçlar (açıldı / vazgeçildi /
// açılamadı), izinli şemalar, kulüp bağlantı adresleri (e-posta / Instagram
// / web) ve gerçek servisle uçtan uca gösterim. Referans: prototip
// dialogs.js:52, screens-clubs.js:83, :96.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/mixin/external_link_mixin.dart';
import 'package:gu_kulupler/product/service/url_launcher_service.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_feedback_service.dart';
import '../../fakes/fake_url_launcher_service.dart';
import '../../fakes/register_fakes.dart';
import '../../helpers/design_files.dart';
import '../feedback/dialog_test_support.dart';

/// Dış bağlantı açan bir ViewModel'in en küçük hali.
final class _Notifier with ProjectDependencyMixin, ExternalLinkMixin {}

final Uri _web = Uri.parse('https://gumushane.edu.tr/kulupler');
final Uri _mail = Uri(scheme: 'mailto', path: 'kulup@gumushane.edu.tr');

void main() {
  group('DLG-32 · ExternalLinks · kulüp bağlantı adresleri', () {
    test('mail: mailto adresi; boşluk kırpılır; boş adres null', () {
      expect(ExternalLinks.mail('kulup@gumushane.edu.tr'), _mail);
      expect(ExternalLinks.mail('  kulup@gumushane.edu.tr '), _mail);
      expect(
        ExternalLinks.mail('kulup@gumushane.edu.tr').toString(),
        'mailto:kulup@gumushane.edu.tr',
      );
      expect(ExternalLinks.mail(''), isNull);
      expect(ExternalLinks.mail('   '), isNull);
    });

    test('instagram: https://instagram.com/<ad>; baştaki @ atılır; boş ad '
        'null', () {
      for (final handle in ['@gu.dagcilik', 'gu.dagcilik', ' @gu.dagcilik ']) {
        expect(
          ExternalLinks.instagram(handle).toString(),
          'https://instagram.com/gu.dagcilik',
          reason: handle,
        );
      }
      expect(ExternalLinks.instagram(''), isNull);
      expect(ExternalLinks.instagram('@'), isNull);
    });

    test('instagram: ad yol parçası olarak kodlanır (başka sunucuya '
        'yönlenemez)', () {
      final uri = ExternalLinks.instagram('@a/../../evil.example?x=1')!;
      expect(uri.host, 'instagram.com');
      expect(uri.scheme, 'https');
      expect(uri.hasQuery, isFalse);
    });

    test('web: şemalı adres aynen; şemasız adrese https eklenir', () {
      expect(
        ExternalLinks.web('https://dagcilik.gumushane.edu.tr').toString(),
        'https://dagcilik.gumushane.edu.tr',
      );
      expect(
        ExternalLinks.web('http://dagcilik.gumushane.edu.tr/a?b=1').toString(),
        'http://dagcilik.gumushane.edu.tr/a?b=1',
      );
      expect(
        ExternalLinks.web(' dagcilik.gumushane.edu.tr ').toString(),
        'https://dagcilik.gumushane.edu.tr',
      );
    });

    test('web: izinli olmayan şema, sunucusuz adres ve kullanıcı bilgisi '
        'taşıyan adres null', () {
      for (final address in [
        '',
        '   ',
        'javascript://alert(1)',
        'intent://scan/#Intent;scheme=zxing;end',
        'ftp://dosya.example/a',
        'file:///etc/passwd',
        'tel://05001112233',
        'mailto://kulup@gumushane.edu.tr',
        'https://',
        'https://gumushane.edu.tr@evil.example',
        'https://kullanici:sifre@evil.example/giris',
        'http://[bozuk',
      ]) {
        expect(ExternalLinks.web(address), isNull, reason: address);
      }
    });

    test('isAllowed: yalnızca https / http (sunuculu, kullanıcı bilgisiz) ve '
        'mailto', () {
      expect(ExternalLinks.allowedSchemes, {'https', 'http', 'mailto'});
      for (final uri in [_web, _mail, Uri.parse('http://a.example')]) {
        expect(ExternalLinks.isAllowed(uri), isTrue, reason: '$uri');
      }
      for (final address in [
        'tel:05001112233',
        'sms:05001112233',
        'javascript:alert(1)',
        'intent://x',
        'data:text/html,merhaba',
        'https:///yol',
        'https://a@b.example',
        '/goreli/yol',
      ]) {
        expect(
          ExternalLinks.isAllowed(Uri.parse(address)),
          isFalse,
          reason: address,
        );
      }
    });
  });

  group('DLG-32 · ExternalLinkMixin', () {
    late FakeFeedbackService feedback;
    late FakeUrlLauncherService launcher;

    setUp(() async {
      await GetIt.I.reset();
      registerDefaultFakes();
      addTearDown(GetIt.I.reset);
      feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
      launcher = GetIt.I<UrlLauncherService>() as FakeUrlLauncherService;
    });

    test('DLG-32 özel gövdeyle açılır; "Aç" (true) → adres açılır, sonuç '
        'opened', () async {
      feedback.nextDialogResult = true;

      expect(
        await _Notifier().openExternalLink(_web),
        ExternalLinkResult.opened,
      );

      expect(feedback.dialogs, [DialogId.dlg32]);
      expect(feedback.lastDialogBuilder, isNotNull);
      expect(launcher.opened, [_web]);
    });

    test('"Vazgeç" (false) ve scrim / geri (null) → cancelled; adres '
        'açılmaz', () async {
      for (final result in [false, null]) {
        feedback.nextDialogResult = result;

        expect(
          await _Notifier().openExternalLink(_web),
          ExternalLinkResult.cancelled,
        );
      }
      expect(feedback.dialogs, [DialogId.dlg32, DialogId.dlg32]);
      expect(launcher.opened, isEmpty);
    });

    test(
      'cihazda adresi açabilecek uygulama yoksa failed (fırlatmaz)',
      () async {
        feedback.nextDialogResult = true;
        launcher.canOpen = false;

        expect(
          await _Notifier().openExternalLink(_mail),
          ExternalLinkResult.failed,
        );
        expect(launcher.opened, [_mail]);
      },
    );

    test('izinli olmayan şema sorulmadan reddedilir: dialog açılmaz, adres '
        'açılmaz, sonuç failed', () async {
      feedback.dialogResults[DialogId.dlg32] = true;
      for (final address in [
        'tel:05001112233',
        'javascript:alert(1)',
        'intent://scan/#Intent;end',
        'https://gumushane.edu.tr@evil.example',
      ]) {
        expect(
          await _Notifier().openExternalLink(Uri.parse(address)),
          ExternalLinkResult.failed,
          reason: address,
        );
      }
      expect(feedback.dialogs, isEmpty);
      expect(launcher.opened, isEmpty);
    });

    test(
      'confirmAndOpenExternalLink: verilen servislerle aynı akış',
      () async {
        final ownFeedback = FakeFeedbackService()..nextDialogResult = true;
        final ownLauncher = FakeUrlLauncherService();

        expect(
          await confirmAndOpenExternalLink(
            feedback: ownFeedback,
            launcher: ownLauncher,
            uri: _web,
          ),
          ExternalLinkResult.opened,
        );
        expect(ownFeedback.dialogs, [DialogId.dlg32]);
        expect(ownLauncher.opened, [_web]);
        // Kayıtlı servislere dokunulmaz.
        expect(feedback.dialogs, isEmpty);
        expect(launcher.opened, isEmpty);
      },
    );

    test('`/// Design: DLG-32` izi mixin bildirimindedir', () {
      expect(
        readText('lib/product/mixin/external_link_mixin.dart'),
        contains(
          RegExp(
            r'/// Design: DLG-32\s*\nmixin ExternalLinkMixin on '
            r'ProjectDependencyMixin\b',
          ),
        ),
      );
    });
  });

  group('DLG-32 · uçtan uca (gerçek FeedbackService)', () {
    testWidgets('adres dialogda gösterilir; "Aç" → dialog kapanır ve adres '
        'açılır; "Vazgeç" → açılmaz', (tester) async {
      final harness = DialogHarness();
      await harness.pump(tester);
      await GetIt.I.unregister<FeedbackService>();
      GetIt.I.registerSingleton<FeedbackService>(harness.service);
      final launcher = GetIt.I<UrlLauncherService>() as FakeUrlLauncherService;

      ExternalLinkResult? result;
      unawaited(_Notifier().openExternalLink(_web).then((v) => result = v));
      await tester.pumpAndSettle();
      expect(find.text('https://gumushane.edu.tr/kulupler'), findsOneWidget);
      expect(launcher.opened, isEmpty);

      await tester.tap(
        find.byKey(DialogHarness.keyOf(DialogId.dlg32, 'cancel')),
      );
      await tester.pumpAndSettle();
      expect(result, ExternalLinkResult.cancelled);
      expect(launcher.opened, isEmpty);

      unawaited(_Notifier().openExternalLink(_web).then((v) => result = v));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(DialogHarness.keyOf(DialogId.dlg32, 'open')));
      await tester.pumpAndSettle();

      expect(result, ExternalLinkResult.opened);
      expect(launcher.opened, [_web]);
      expect(find.byType(GuDialogFrame), findsNothing);
    });
  });
}
