// PRF-02 · Profili düzenle — içerik, 25 envanter aksiyonu ve sonuçları
// (SHT-02, SHT-03, SHT-16, TST-04, TST-20, TST-21, TST-X9), kaydedilmemiş
// değişiklik uyarısı (DLG-25: geri düğmesi + sistem geri), hata durumu,
// klavye açıkken kaydırma, cihaz matrisi, açık + koyu golden.
// Referans: design/reference-shots/screens/PRF-02__*.webp.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/profile/provider/edit_profile_state.dart';
import 'package:gu_kulupler/features/profile/provider/edit_profile_view_model.dart';
import 'package:gu_kulupler/features/profile/view/edit_profile_view.dart';
import 'package:gu_kulupler/features/profile/view/widget/edit_profile_interests.dart';
import 'package:gu_kulupler/features/profile/view/widget/profile_avatar_button.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/unsaved_changes_dialog.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/photo_source_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_kulupler/product/widget/form/form_error_line.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_app_preferences_store.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_user_repository.dart';
import '../../../fixtures/user_model_fixtures.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

const String _uid = 'u_mehmet';
const String _email = 'mehmet.kaya@ogr.gumushane.edu.tr';

final Key _back = GuKey.action('PRF-02.back');
final Key _avatar = GuKey.action('PRF-02.avatar');
final Key _name = GuKey.action('PRF-02.name');
final Key _department = GuKey.action('PRF-02.department');
final Key _year = GuKey.action('PRF-02.year');
final Key _bio = GuKey.action('PRF-02.bio');
final Key _emailField = GuKey.action('PRF-02.email');
final Key _lockedEmail = GuKey.action('PRF-02.lockedEmail');
final Key _save = GuKey.action('PRF-02.save');

/// Referans görüntüdeki kullanıcı (`screens-actions.json` `user: u_mehmet`).
final UserModel _mehmet = UserModelFixtures.byId(_uid);

final EditProfileState _base = EditProfileState(
  original: _mehmet,
  name: _mehmet.name,
  departmentId: _mehmet.department,
  year: _mehmet.year,
  interests: _mehmet.interests.toSet(),
  bio: _mehmet.bio,
  email: _email,
);

/// Ekranı [state] başlangıç durumuyla açar (form oturumdan kurulmaz;
/// ViewModel metotları gerçek, bağımlılıklar fake'tir).
List<Override> _with(EditProfileState state) => [
  editProfileViewModelProvider.overrideWithBuild((ref, notifier) => state),
];

FakeUserRepository _users() => GetIt.I<UserRepository>() as FakeUserRepository;

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

Future<void> _pump(
  WidgetTester tester, {
  EditProfileState? state,
  Locale locale = const Locale('tr'),
  double keyboardInset = 0,
}) => tester.pumpApp(
  const EditProfileView(),
  locale: locale,
  keyboardInset: keyboardInset,
  overrides: _with(state ?? _base),
);

/// `/profile` (yer tutucu) üstünde `/profile/edit`: geri dönüşü sınar.
Future<GoRouter> _pumpRouter(
  WidgetTester tester, {
  EditProfileState? state,
}) async {
  GoRouter? created;
  await tester.pumpAppRouter(
    overrides: _with(state ?? _base),
    routerOf: (ref) => created ??= GoRouter(
      initialLocation: '/profile/edit',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (context, state) => const _Stub(),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (context, state) => const EditProfileView(),
            ),
          ],
        ),
      ],
    ),
  );
  final router = created!;
  addTearDown(router.dispose);
  await tester.pumpAndSettle();
  _users().users[_uid] = _mehmet;
  return router;
}

String _path(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pump();
}

GuButton _button(WidgetTester tester, Key key) =>
    tester.widget<GuButton>(find.byKey(key));

GuPickerField _pickerField(WidgetTester tester, Key key) =>
    tester.widget<GuPickerField>(
      find.ancestor(of: find.byKey(key), matching: find.byType(GuPickerField)),
    );

GuChip _chip(WidgetTester tester, String id) =>
    tester.widget<GuChip>(find.byKey(EditProfileInterests.keyOf(id)));

class _Stub extends StatelessWidget {
  const _Stub();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('/profile'));
}

void main() {
  group('PRF-02 · Profili düzenle · içerik', () {
    testWidgets('çubuk, avatar, alanlar, sayaç, kilitli e-posta, bant, kapalı '
        '"Kaydet"', (tester) async {
      await _pump(tester);
      final l10n = tester.l10n;
      final context = tester.element(find.byType(EditProfileView));

      expect(find.text(l10n.editProfileTitle), findsOneWidget);
      final avatar = tester.widget<GuAvatar>(find.byType(GuAvatar));
      expect(avatar.size, 96);
      expect(avatar.initials, 'MK');
      expect(avatar.image, isNull);
      expect(find.text(l10n.profileChangePhoto), findsOneWidget);
      expect(
        tester.widget<GuEmblem>(find.byType(GuEmblem)).background,
        GuColors.light.brandPrimary,
      );

      expect(find.text('Mehmet Kaya'), findsOneWidget);
      expect(
        _pickerField(tester, _department).value,
        StaticLabels.department(context, 'd02'),
      );
      expect(
        _pickerField(tester, _year).value,
        StaticLabels.year(context, YearLevel.third),
      );
      expect(find.text('4/${Limits.interestsMax}'), findsOneWidget);
      for (final interest in StaticTables.interests) {
        expect(
          _chip(tester, interest.id).selected,
          _mehmet.interests.contains(interest.id),
        );
      }
      expect(find.text(_mehmet.bio), findsOneWidget);
      expect(find.text(_email), findsOneWidget);
      expect(find.text(l10n.editProfileEmailLocked), findsOneWidget);
      expect(find.text(l10n.editProfilePrivacy), findsOneWidget);
      expect(find.byType(FormErrorLine), findsNothing);

      final save = _button(tester, _save);
      expect(save.label, l10n.commonSave);
      expect(save.disabled, isTrue);
      expect(save.loading, isFalse);
    });

    testWidgets('hatalar: ad, ilgi alanı, fotoğraf ve kaydetme', (
      tester,
    ) async {
      await _pump(
        tester,
        state: _base.copyWith(
          name: '',
          interests: const {},
          errors: const {
            EditProfileField.name: FormFieldError.required,
            EditProfileField.interests: FormFieldError.required,
            EditProfileField.photo: FormFieldError.invalidFormat,
          },
          submitError: EditProfileError.unknown,
        ),
      );
      final l10n = tester.l10n;

      expect(find.text(l10n.authErrRequired), findsOneWidget);
      expect(find.text(l10n.authSetupMinInterest), findsOneWidget);
      expect(find.text(l10n.imageInvalidType), findsOneWidget);
      expect(find.text(l10n.sysErrorTitle), findsOneWidget);
      expect(find.text('0/${Limits.interestsMax}'), findsOneWidget);
      expect(_button(tester, _save).disabled, isFalse);
    });

    testWidgets('personelde sınıf alanı yok', (tester) async {
      await _pump(
        tester,
        state: _base.copyWith(original: _mehmet.copyWith(staff: true)),
      );

      expect(find.byKey(_year), findsNothing);
    });

    testWidgets('profil yoksa hata durumu, "Kaydet" yok', (tester) async {
      await _pump(tester, state: const EditProfileState(isError: true));

      expect(find.byType(GuErrorState), findsOneWidget);
      expect(find.byKey(GuKey.action('PRF-02.retry')), findsOneWidget);
      expect(find.byKey(_save), findsNothing);
    });
  });

  group('PRF-02 · Profili düzenle · aksiyonlar', () {
    testWidgets('aksiyon envanteri: 25 aksiyon', (tester) async {
      await _pump(tester);
      expectActionInventory(tester, 'PRF-02');
    });

    testWidgets('PRF-02.avatar → SHT-16 → galeri: önizleme, form kirli', (
      tester,
    ) async {
      await _pump(tester);
      (GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore)
              .values[AppPreferenceKeys.photoAccessExplained] =
          true;
      _feedback().nextSheetResult = PhotoSourceChoice.gallery;

      await _tap(tester, _avatar);
      await tester.pump();

      expect(_feedback().sheets, [SheetId.sht16]);
      final sheet =
          _feedback().lastSheetBuilder!(tester.element(find.byKey(_avatar)))
              as PhotoSourceSheet;
      expect(sheet.hasPhoto, isFalse);
      expect(
        tester
            .widget<ProfileAvatarButton>(find.byType(ProfileAvatarButton))
            .image,
        isA<MemoryImage>(),
      );
      expect(_button(tester, _save).disabled, isFalse);
    });

    testWidgets('PRF-02.department → SHT-02, PRF-02.year → SHT-03', (
      tester,
    ) async {
      await _pump(tester);
      final context = tester.element(find.byType(EditProfileView));

      _feedback().nextSheetResult = 'd10';
      await _tap(tester, _department);
      await tester.pump();
      _feedback().nextSheetResult = YearLevel.first;
      await _tap(tester, _year);
      await tester.pump();

      expect(_feedback().sheets, [SheetId.sht02, SheetId.sht03]);
      expect(
        _pickerField(tester, _department).value,
        StaticLabels.department(context, 'd10'),
      );
      expect(
        _pickerField(tester, _year).value,
        StaticLabels.year(context, YearLevel.first),
      );
    });

    testWidgets('PRF-02.toggleInterest: seçim + sayaç; 5 doluyken TST-04', (
      tester,
    ) async {
      await _pump(tester);

      await _tap(tester, EditProfileInterests.keyOf('i02'));
      expect(_chip(tester, 'i02').selected, isTrue);
      expect(find.text('5/${Limits.interestsMax}'), findsOneWidget);

      await _tap(tester, EditProfileInterests.keyOf('i03'));
      expect(_chip(tester, 'i03').selected, isFalse);
      expect(_feedback().toasts, [ToastId.tst04]);
    });

    testWidgets('PRF-02.name / PRF-02.bio: yazma formu kirletir; biyografi '
        'sınırda kesilir', (tester) async {
      await _pump(tester);

      await tester.enterText(find.byKey(_name), 'Mehmet K.');
      await tester.enterText(find.byKey(_bio), 'b' * (Limits.bioMax + 10));
      await tester.pump();

      expect(_button(tester, _save).disabled, isFalse);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).at(1))
            .controller
            .text,
        hasLength(Limits.bioMax),
      );
    });

    testWidgets('PRF-02.lockedEmail / PRF-02.email → TST-20', (tester) async {
      await _pump(tester);

      await _tap(tester, _lockedEmail);
      // Metin alanı dokunmayı almaz (AbsorbPointer): sarmalayıcıya gider.
      await tester.tap(find.byKey(_emailField), warnIfMissed: false);
      await tester.pump();

      expect(_feedback().toasts, [ToastId.tst20, ToastId.tst20]);
    });

    testWidgets('kapalı PRF-02.save → TST-X9, yazım yok', (tester) async {
      await _pump(tester);

      await _tap(tester, _save);
      await tester.pump();

      expect(_feedback().toasts, [ToastId.tstX9]);
      expect(_users().profilePatches, isEmpty);
    });

    testWidgets('PRF-02.save: yazar, TST-21, ekran kapanır', (tester) async {
      final router = await _pumpRouter(tester);

      await tester.enterText(find.byKey(_name), 'Mehmet K.');
      await _tap(tester, _save);
      await tester.pumpAndSettle();

      expect(
        _users().profilePatches.single.patch,
        const UserProfilePatch(name: 'Mehmet K.', nameLower: 'mehmet k.'),
      );
      expect(_feedback().toasts, [ToastId.tst21]);
      expect(_path(router), '/profile');
    });

    testWidgets('klavye açıkken içerik kayar: biyografi görünür alana gelir', (
      tester,
    ) async {
      await _pump(tester, keyboardInset: 320);

      await tester.ensureVisible(find.byKey(_bio));
      await tester.pump();

      expect(tester.getRect(find.byKey(_bio)).bottom, lessThan(844 - 320));
    });
  });

  group('PRF-02 · Profili düzenle · kaydedilmemiş değişiklik (DLG-25)', () {
    testWidgets('değişiklik yokken geri: soru sorulmaz, ekran kapanır', (
      tester,
    ) async {
      final router = await _pumpRouter(tester);

      await _tap(tester, _back);
      await tester.pumpAndSettle();

      expect(_feedback().dialogs, isEmpty);
      expect(_path(router), '/profile');
    });

    testWidgets('değişiklik varken geri: DLG-25 ("Kaydet" var) → "Kaydetmeden '
        'çık" → ekran kapanır, yazım yok', (tester) async {
      final router = await _pumpRouter(tester);
      await tester.enterText(find.byKey(_name), 'Mehmet K.');
      _feedback().nextDialogResult = UnsavedChangesResult.discard;

      await _tap(tester, _back);
      await tester.pumpAndSettle();

      expect(_feedback().dialogs, [DialogId.dlg25]);
      final dialog =
          _feedback().lastDialogBuilder!(tester.element(find.byType(_Stub)))
              as UnsavedChangesDialog;
      expect(dialog.hasSave, isTrue);
      expect(_users().profilePatches, isEmpty);
      expect(_path(router), '/profile');
    });

    testWidgets('DLG-25 "Kaydet" → yazar, TST-21, ekran kapanır', (
      tester,
    ) async {
      final router = await _pumpRouter(tester);
      await tester.enterText(find.byKey(_bio), 'Yeni');
      _feedback().nextDialogResult = UnsavedChangesResult.save;

      await _tap(tester, _back);
      await tester.pumpAndSettle();

      expect(_users().profilePatches.single.patch.bio, 'Yeni');
      expect(_feedback().toasts, [ToastId.tst21]);
      expect(_path(router), '/profile');
    });

    for (final result in [UnsavedChangesResult.keep, null]) {
      testWidgets('DLG-25 ${result?.name ?? 'scrim / geri'} → ekran ve '
          'değişiklik yerinde', (tester) async {
        final router = await _pumpRouter(tester);
        await tester.enterText(find.byKey(_name), 'Mehmet K.');
        _feedback().nextDialogResult = result;

        await _tap(tester, _back);
        await tester.pumpAndSettle();

        expect(_feedback().dialogs, [DialogId.dlg25]);
        expect(_path(router), '/profile/edit');
        expect(find.text('Mehmet K.'), findsOneWidget);
      });
    }

    testWidgets('sistem geri tuşu değişiklik varken DLG-25 açar', (
      tester,
    ) async {
      final router = await _pumpRouter(tester);
      await tester.enterText(find.byKey(_name), 'Mehmet K.');
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(_feedback().dialogs, [DialogId.dlg25]);
      expect(_path(router), '/profile/edit');
    });
  });

  group('PRF-02 · Profili düzenle · matris ve golden', () {
    testWidgets('cihaz matrisi (+ klavye): hatalı form taşmaz', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => const EditProfileView(),
        overrides: _with(
          _base.copyWith(
            departmentId: 'd02',
            errors: const {
              EditProfileField.name: FormFieldError.tooShort,
              EditProfileField.interests: FormFieldError.required,
              EditProfileField.photo: FormFieldError.limitExceeded,
            },
            submitError: EditProfileError.unknown,
          ),
        ),
        keyboard: true,
      );
    });

    testWidgets('varsayılan açık + koyu', (tester) async {
      await goldenForThemes(
        tester,
        'PRF-02',
        const EditProfileView(),
        overrides: _with(_base),
      );
    });
  });
}
