// SET-04 · AboutViewModel + AboutState: sürüm / derleme (AppInfoService),
// açılır satırlar, "Lisansı görüntüle" (DLG-32 → UrlLauncherService)
// (PLAN §12.12).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/features/settings/constants/about_content.dart';
import 'package:gu_kulupler/features/settings/provider/about_state.dart';
import 'package:gu_kulupler/features/settings/provider/about_view_model.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/mixin/external_link_mixin.dart';
import 'package:gu_kulupler/product/service/app_info_service.dart';
import 'package:gu_kulupler/product/service/url_launcher_service.dart';

import '../../../fakes/fake_app_info_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_url_launcher_service.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/test_container.dart';

void main() {
  late FakeFeedbackService feedback;
  late FakeUrlLauncherService launcher;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    launcher = GetIt.I<UrlLauncherService>() as FakeUrlLauncherService;
  });

  ProviderContainer container() {
    final c = createContainer();
    addTearDown(c.listen(aboutViewModelProvider, (_, _) {}).close);
    return c;
  }

  test('AboutState: copyWith + props tüm alanlar', () {
    const base = AboutState();
    final changed = base.copyWith(
      version: '2.0.0',
      buildNumber: '7',
      openLicenses: {AboutLicense.inter},
      isReleaseNotesOpen: true,
    );
    expect(changed.props, [
      '2.0.0',
      '7',
      {AboutLicense.inter},
      true,
    ]);
    expect(changed.copyWith(), changed);
    expect(changed.isLicenseOpen(AboutLicense.inter), isTrue);
    expect(changed.isLicenseOpen(AboutLicense.lucide), isFalse);
  });

  test('sürüm ve derleme numarası paketten', () {
    (GetIt.I<AppInfoService>() as FakeAppInfoService)
      ..version = '1.2.3'
      ..buildNumber = '42';
    final state = container().read(aboutViewModelProvider);
    expect(state.version, '1.2.3');
    expect(state.buildNumber, '42');
    expect(state.openLicenses, isEmpty);
    expect(state.isReleaseNotesOpen, isFalse);
  });

  test('lisans ve sürüm notları satırları açılır / kapanır', () {
    final c = container();
    c.read(aboutViewModelProvider.notifier)
      ..toggleLicense(AboutLicense.lucide)
      ..toggleLicense(AboutLicense.inter)
      ..toggleReleaseNotes();
    var state = c.read(aboutViewModelProvider);
    expect(state.openLicenses, {AboutLicense.lucide, AboutLicense.inter});
    expect(state.isReleaseNotesOpen, isTrue);
    c.read(aboutViewModelProvider.notifier)
      ..toggleLicense(AboutLicense.lucide)
      ..toggleReleaseNotes();
    state = c.read(aboutViewModelProvider);
    expect(state.openLicenses, {AboutLicense.inter});
    expect(state.isReleaseNotesOpen, isFalse);
  });

  test('"Lisansı görüntüle": DLG-32 "Aç" → adres açılır', () async {
    feedback.dialogResults[DialogId.dlg32] = true;
    final result = await container()
        .read(aboutViewModelProvider.notifier)
        .openLicense(AboutLicense.montserrat);
    expect(result, ExternalLinkResult.opened);
    expect(feedback.dialogs, [DialogId.dlg32]);
    expect(launcher.opened, [AboutLicense.montserrat.uri]);
  });

  test('"Lisansı görüntüle": vazgeçilirse açılmaz', () async {
    feedback.dialogResults[DialogId.dlg32] = false;
    final result = await container()
        .read(aboutViewModelProvider.notifier)
        .openLicense(AboutLicense.lucide);
    expect(result, ExternalLinkResult.cancelled);
    expect(launcher.opened, isEmpty);
  });
}
