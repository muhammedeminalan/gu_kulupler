// AUT-05 · Profilini tamamla — üç adımın içeriği (TR / EN), 4 envanter
// aksiyonu + adıma bağlı aksiyonlar ve sonuçları (SHT-02, SHT-03, SHT-16,
// DLG-04, DLG-05, DLG-25, TST-04, TST-05, TST-24, TST-32, TST-57), doğrulama
// ve gönderim hataları, yükleniyor durumu, cihaz matrisi, dokunma hedefleri,
// açık + koyu golden. Referans: design/reference-shots/screens/AUT-05__*.webp.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/auth/provider/setup_profile_state.dart';
import 'package:gu_kulupler/features/auth/provider/setup_profile_view_model.dart';
import 'package:gu_kulupler/features/auth/view/setup_profile_view.dart';
import 'package:gu_kulupler/features/auth/view/widget/setup_profile_interests_step.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/unsaved_changes_dialog.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/department_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/photo_source_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/year_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:gu_kulupler/product/service/permission_service.dart';
import 'package:gu_kulupler/product/widget/form/form_error_line.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_app_preferences_store.dart';
import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_image_picker_service.dart';
import '../../../fakes/fake_permission_service.dart';
import '../../../fakes/fake_user_repository.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

final Key _close = GuKey.action('AUT-05.close');
final Key _next = GuKey.action('AUT-05.next');
final Key _photo = GuKey.action('AUT-05.photo');
final Key _skipPhoto = GuKey.action('AUT-05.skipPhoto');
// Envanter yakalaması yalnızca 1. adımdır; sonraki adımların anahtarları
// prototipten gelir (`screens-auth.js:144–147`).
final Key _department = GuKey.action('AUT-05.department');
final Key _year = GuKey.action('AUT-05.year');
final Key _back = GuKey.action('AUT-05.back');
final Key _finish = GuKey.action('AUT-05.finish');

const String _uid = 'u_unverified';
const String _email = 'unverified@ogr.gumushane.edu.tr';
const String _name = 'Deneme Kullanıcı';

/// Referans görüntüdeki kullanıcı (`seed.js:154`).
const SetupProfileState _base = SetupProfileState(
  name: _name,
  avatarSeed: _uid,
);

final SetupProfileState _infoStep = _base.copyWith(step: SetupStep.info);

final SetupProfileState _interestsStep = _base.copyWith(
  step: SetupStep.interests,
  departmentId: 'd10',
  year: YearLevel.first,
);

/// Ekranı [state] başlangıç durumuyla açar (kimlik alanları oturumdan
/// okunmaz; ViewModel metotları gerçek, bağımlılıklar fake'tir).
List<Override> _with(SetupProfileState state) => [
  setupProfileViewModelProvider.overrideWithBuild((ref, notifier) => state),
];

FakeAuthRepository _auth() => GetIt.I<AuthRepository>() as FakeAuthRepository;

FakeUserRepository _users() => GetIt.I<UserRepository>() as FakeUserRepository;

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

FakeConnectivityService _connectivity() =>
    GetIt.I<ConnectivityService>() as FakeConnectivityService;

FakePermissionService _permissions() =>
    GetIt.I<PermissionService>() as FakePermissionService;

FakeImagePickerService _picker() =>
    GetIt.I<ImagePickerService>() as FakeImagePickerService;

FakeAppPreferencesStore _preferences() =>
    GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore;

/// Doğrulanmış oturum açar (`pumpApp` sonrasında çağrılır: fake'ler orada
/// kurulur).
void _signIn() => _auth().currentUser = const AuthUserInfo(
  uid: _uid,
  email: _email,
  emailVerified: true,
  displayName: _name,
);

Future<void> _pump(
  WidgetTester tester, {
  SetupProfileState state = _base,
  Locale locale = const Locale('tr'),
}) => tester.pumpApp(
  const SetupProfileView(),
  locale: locale,
  overrides: _with(state),
);

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
    tester.widget<GuChip>(find.byKey(SetupProfileInterestsStep.keyOf(id)));

String _progress(WidgetTester tester, int step) =>
    tester.l10n.authSetupProgress('$step', '3');

void main() {
  group('AUT-05 · Profilini tamamla · içerik', () {
    for (final locale in DeviceMatrix.locales) {
      final code = locale.languageCode;

      testWidgets(
        '1. adım ($code): çubuk, başlık, avatar, iki düğme, "Devam"',
        (tester) async {
          await _pump(tester, locale: locale);
          final l10n = tester.l10n;

          // Çubuk: kapat + "Adım 1/3" + adım çubuğu.
          expect(find.bySemanticsLabel(l10n.a11yClose), findsOneWidget);
          expect(
            tester.widget<GuAppBar>(find.byType(GuAppBar)).closeIcon,
            isTrue,
          );
          expect(
            find.descendant(
              of: find.byType(GuAppBar),
              matching: find.text(_progress(tester, 1)),
            ),
            findsOneWidget,
          );
          final stepbar = tester.widget<GuStepbar>(find.byType(GuStepbar));
          expect(stepbar.step, 1);
          expect(stepbar.total, 3);
          expect(stepbar.semanticLabel, '1/3');

          expect(find.text(l10n.authSetupPhotoTitle), findsOneWidget);
          expect(find.text(l10n.authSetupPhotoDesc), findsOneWidget);
          final avatar = tester.widget<GuAvatar>(find.byType(GuAvatar));
          expect(avatar.size, 120);
          expect(avatar.initials, 'DK');
          expect(avatar.seed, _uid);
          expect(avatar.image, isNull);
          expect(find.byType(GuBadge), findsNothing);

          final photo = _button(tester, _photo);
          expect(photo.label, l10n.authSetupAddPhoto);
          expect(photo.variant, GuButtonVariant.tonal);
          expect(photo.icon, GuIcons.camera);
          final skip = _button(tester, _skipPhoto);
          expect(skip.label, l10n.authSetupSkipPhoto);
          expect(skip.variant, GuButtonVariant.text);

          // Alt çubuk: yalnızca "Devam".
          final next = _button(tester, _next);
          expect(next.label, l10n.commonContinue);
          expect(next.variant, GuButtonVariant.primary);
          expect(next.loading, isFalse);
          expect(find.byKey(_back), findsNothing);
          expect(find.byKey(_finish), findsNothing);
          expect(find.byType(FormErrorLine), findsNothing);
        },
      );

      testWidgets('2. adım ($code): başlık, bölüm ve sınıf seçicileri, "Geri" '
          '+ "Devam"', (tester) async {
        await _pump(tester, state: _infoStep, locale: locale);
        final l10n = tester.l10n;

        expect(find.text(_progress(tester, 2)), findsOneWidget);
        expect(tester.widget<GuStepbar>(find.byType(GuStepbar)).step, 2);
        expect(find.text(l10n.authSetupEduTitle), findsOneWidget);
        expect(find.text(l10n.authSetupEduDesc), findsOneWidget);

        final department = _pickerField(tester, _department);
        expect(department.label, l10n.profileDepartment);
        expect(department.icon, GuIcons.graduationCap);
        expect(department.value, isNull);
        expect(department.placeholder, l10n.commonSelect);
        expect(department.errorText, isNull);
        final year = _pickerField(tester, _year);
        expect(year.label, l10n.profileYear);
        expect(year.icon, GuIcons.calendarDays);
        expect(year.value, isNull);
        expect(year.placeholder, l10n.commonSelect);
        expect(find.text(l10n.commonSelect), findsNWidgets(2));

        final back = _button(tester, _back);
        expect(back.label, l10n.commonBack);
        expect(back.variant, GuButtonVariant.outline);
        expect(_button(tester, _next).label, l10n.commonContinue);
        expect(find.byKey(_photo), findsNothing);
        expect(find.byKey(_finish), findsNothing);
      });

      testWidgets('3. adım ($code): başlık + sayaç, 16 çip, "Geri" + '
          '"Tamamla"', (tester) async {
        await _pump(
          tester,
          state: _interestsStep.copyWith(interests: const {'i02', 'i16'}),
          locale: locale,
        );
        final l10n = tester.l10n;
        final context = tester.element(find.byType(SetupProfileInterestsStep));

        expect(find.text(_progress(tester, 3)), findsOneWidget);
        expect(tester.widget<GuStepbar>(find.byType(GuStepbar)).step, 3);
        expect(find.text(l10n.authSetupInterestTitle), findsOneWidget);
        expect(find.text('2/5'), findsOneWidget);
        expect(find.text(l10n.authSetupInterestDesc), findsOneWidget);

        expect(find.byType(GuChip), findsNWidgets(16));
        for (final interest in StaticTables.interests) {
          final chip = _chip(tester, interest.id);
          expect(chip.label, StaticLabels.interest(context, interest.id));
          expect(chip.selected, {'i02', 'i16'}.contains(interest.id));
        }

        final finish = _button(tester, _finish);
        expect(finish.label, l10n.commonFinish);
        expect(finish.loading, isFalse);
        expect(_button(tester, _back).disabled, isFalse);
        expect(find.byKey(_next), findsNothing);
        expect(find.byType(FormErrorLine), findsNothing);
      });
    }

    testWidgets('personel hesabında sınıf alanı çizilmez', (tester) async {
      await _pump(tester, state: _infoStep.copyWith(isStaff: true));

      expect(find.byKey(_department), findsOneWidget);
      expect(find.byKey(_year), findsNothing);
    });

    testWidgets(
      'yerleşim: çubuk gerçek güvenli alanın altında, gövde yatay '
      '16 / üst 16, avatar 120 ortalı, eylem çubuğu alt güvenli alanı kaplar',
      (tester) async {
        await tester.pumpApp(
          const SetupProfileView(),
          overrides: _with(_base),
          viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
        );
        final l10n = tester.l10n;

        final bar = tester.getRect(find.byType(GuAppBar));
        expect(bar, const Rect.fromLTWH(0, 0, 390, 47 + 56));
        // Adım çubuğu: kapat düğmesi + boşluklardan sonra, sağda 16.
        final stepbar = tester.getRect(find.byType(GuStepbar));
        expect(stepbar.left, 8 + 48 + 4 + 8);
        expect(stepbar.right, 390 - 8 - 8);
        expect(stepbar.height, 4);

        final title = tester.getRect(find.text(l10n.authSetupPhotoTitle));
        expect(title.left, 16);
        expect(title.top, bar.bottom + 16);
        final desc = tester.getRect(find.text(l10n.authSetupPhotoDesc));
        expect(desc.top, title.bottom + 16);

        final avatar = tester.getRect(find.byType(GuAvatar));
        expect(avatar.size, const Size(120, 120));
        expect(avatar.center.dx, 195);
        expect(avatar.top, desc.bottom + 16 + 16);
        final photo = tester.getRect(find.byKey(_photo));
        expect(photo.top, avatar.bottom + 12);
        expect(photo.height, 48);
        expect(photo.center.dx, 195);
        final skip = tester.getRect(find.byKey(_skipPhoto));
        expect(skip.top, photo.bottom + 12);
        expect(skip.height, 44);

        final cta = tester.getRect(find.byType(GuStickyCta));
        expect(cta.bottom, 844);
        final next = tester.getRect(find.byKey(_next));
        expect(next.left, 16);
        expect(next.right, 390 - 16);
        expect(next.height, 48);
        expect(next.bottom, 844 - 34 - 12);
        expect(next.top, cta.top + 1 + 12);
      },
    );
  });

  group('AUT-05 · Profilini tamamla · envanter ve ölçüler', () {
    testWidgets('aksiyon envanteri: 4 aksiyon (1. adım)', (tester) async {
      await _pump(tester);
      expectActionInventory(tester, 'AUT-05');
    });

    testWidgets('adıma bağlı anahtarlar: 2. adımda department / year / back / '
        'next; 3. adımda 16 toggleInterest + back / finish', (tester) async {
      await _pump(tester, state: _infoStep);
      expect(
        ActionInventory.found(tester).where((key) => key.startsWith('AUT-05.')),
        unorderedEquals([
          'AUT-05.close',
          'AUT-05.department',
          'AUT-05.year',
          'AUT-05.back',
          'AUT-05.next',
        ]),
      );

      await _pump(tester, state: _interestsStep);
      expect(
        ActionInventory.found(tester).where((key) => key.startsWith('AUT-05.')),
        unorderedEquals([
          'AUT-05.close',
          for (final interest in StaticTables.interests)
            'AUT-05.toggleInterest.${interest.id}',
          'AUT-05.back',
          'AUT-05.finish',
        ]),
      );
    });

    testWidgets('cihaz matrisi: 1. adım taşmaz (güvenli alanlar)', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (_) => const SetupProfileView(),
        overrides: _with(_base),
        safeAreas: true,
      );
    });

    testWidgets('cihaz matrisi: 1. adım fotoğraf rozeti + hata satırıyla '
        'taşmaz', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => const SetupProfileView(),
        overrides: _with(
          _base.copyWith(
            avatar: kFakeJpeg,
            errors: const {
              SetupProfileField.photo: FormFieldError.invalidFormat,
            },
          ),
        ),
      );
    });

    testWidgets('cihaz matrisi: 2. adım (en uzun bölüm adı + hata) taşmaz', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (_) => const SetupProfileView(),
        overrides: _with(
          _infoStep.copyWith(
            departmentId: 'd02',
            errors: const {
              SetupProfileField.department: FormFieldError.required,
              SetupProfileField.year: FormFieldError.required,
            },
          ),
        ),
        safeAreas: true,
      );
    });

    testWidgets('cihaz matrisi: 3. adım (seçimler + iki hata satırı) taşmaz', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (_) => const SetupProfileView(),
        overrides: _with(
          _interestsStep.copyWith(
            interests: const {'i01', 'i02', 'i03', 'i04', 'i05'},
            errors: const {
              SetupProfileField.interests: FormFieldError.required,
            },
            submitError: SetupProfileError.unknown,
          ),
        ),
        safeAreas: true,
      );
    });

    testWidgets('dokunma hedefleri: Android 48 dp / iOS 44 pt (K-03)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      for (final state in [_base, _infoStep, _interestsStep]) {
        await _pump(tester, state: state);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await tester.pumpApp(
          const SetupProfileView(),
          overrides: _with(state),
          platform: TargetPlatform.iOS,
        );
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      }
      handle.dispose();
    });
  });

  group('AUT-05 · Profilini tamamla · fotoğraf adımı', () {
    testWidgets('AUT-05.next → 2. adım', (tester) async {
      await _pump(tester);

      await _tap(tester, _next);

      expect(find.text(tester.l10n.authSetupEduTitle), findsOneWidget);
      expect(find.text(_progress(tester, 2)), findsOneWidget);
      expect(_feedback().dialogs, isEmpty);
    });

    testWidgets('AUT-05.skipPhoto → 2. adım', (tester) async {
      await _pump(tester);

      await _tap(tester, _skipPhoto);

      expect(find.text(tester.l10n.authSetupEduTitle), findsOneWidget);
      expect(find.byKey(_back), findsOneWidget);
    });

    testWidgets('AUT-05.photo → SHT-16 (kaldır satırı yok) → Galeri → DLG-05 '
        '→ seçici → önizleme + "Fotoğraf eklendi"', (tester) async {
      await _pump(tester);
      _feedback()
        ..nextSheetResult = PhotoSourceChoice.gallery
        ..nextDialogResult = true;

      await _tap(tester, _photo);
      await tester.pump();

      expect(_feedback().sheets, [SheetId.sht16]);
      final sheet =
          _feedback().lastSheetBuilder!(tester.element(find.byKey(_photo)))
              as PhotoSourceSheet;
      expect(sheet.hasPhoto, isFalse);
      expect(sheet.maxImages, 1);
      expect(_feedback().dialogs, [DialogId.dlg05]);
      expect(_picker().picks, [MediaSource.gallery]);

      final avatar = tester.widget<GuAvatar>(find.byType(GuAvatar));
      expect((avatar.image! as MemoryImage).bytes, same(kFakeJpeg.bytes));
      final badge = tester.widget<GuBadge>(find.byType(GuBadge));
      expect(badge.label, tester.l10n.authSetupPhotoAdded);
      expect(badge.kind, GuBadgeKind.success);
      expect(badge.icon, GuIcons.circleCheck);
      // Fotoğraf gönderime kadar yüklenmez (W-57).
      expect(_users().callsTo('updateAvatar'), isEmpty);
      expect(_feedback().toasts, isEmpty);
    });

    testWidgets('AUT-05.photo → SHT-16 → Kamera → DLG-04 → sistem izni → '
        'çekim → önizleme', (tester) async {
      await _pump(tester);
      _feedback()
        ..nextSheetResult = PhotoSourceChoice.camera
        ..nextDialogResult = true;

      await _tap(tester, _photo);
      await tester.pump();

      expect(_feedback().dialogs, [DialogId.dlg04]);
      expect(_permissions().requested, [Permission.camera]);
      expect(_picker().picks, [MediaSource.camera]);
      expect(find.byType(GuBadge), findsOneWidget);
    });

    testWidgets('kamera izni kalıcı reddedilmişse TST-32 gösterilir, fotoğraf '
        'eklenmez', (tester) async {
      await _pump(tester);
      _permissions().results[Permission.camera] =
          PermissionStatus.permanentlyDenied;
      _feedback()
        ..nextSheetResult = PhotoSourceChoice.camera
        ..nextDialogResult = true;

      await _tap(tester, _photo);
      await tester.pump();

      expect(_feedback().toasts, [ToastId.tst32]);
      expect(_feedback().hasToastAction, isTrue);
      expect(_picker().picks, isEmpty);
      expect(find.byType(GuBadge), findsNothing);
      expect(find.byType(FormErrorLine), findsNothing);
    });

    testWidgets('SHT-16 kapatılırsa hiçbir şey olmaz', (tester) async {
      await _pump(tester);

      await _tap(tester, _photo);
      await tester.pump();

      expect(_feedback().sheets, [SheetId.sht16]);
      expect(_feedback().dialogs, isEmpty);
      expect(_picker().picks, isEmpty);
      expect(find.byType(GuBadge), findsNothing);
    });

    testWidgets('görsel sınırdan büyükse hata satırı üst sınırı MB olarak '
        'söyler', (tester) async {
      await _pump(tester);
      _preferences().values[AppPreferenceKeys.photoAccessExplained] = true;
      _picker().nextError = ImagePickError.tooLarge;
      _feedback().nextSheetResult = PhotoSourceChoice.gallery;

      await _tap(tester, _photo);
      await tester.pump();

      expect(Limits.imageMaxBytes, 5 * 1024 * 1024);
      expect(
        find.descendant(
          of: find.byType(FormErrorLine),
          matching: find.text(tester.l10n.imageTooLarge(5)),
        ),
        findsOneWidget,
      );
    });

    testWidgets('görsel işlenemezse düğmelerin altında hata satırı çıkar', (
      tester,
    ) async {
      await _pump(tester);
      _preferences().values[AppPreferenceKeys.photoAccessExplained] = true;
      _picker().nextError = ImagePickError.unreadable;
      _feedback().nextSheetResult = PhotoSourceChoice.gallery;

      await _tap(tester, _photo);
      await tester.pump();

      final line = find.byType(FormErrorLine);
      expect(
        find.descendant(
          of: line,
          matching: find.text(tester.l10n.imageInvalidType),
        ),
        findsOneWidget,
      );
      expect(
        tester.getRect(line).top,
        tester.getRect(find.byKey(_skipPhoto)).bottom + 12,
      );
      expect(find.byType(GuBadge), findsNothing);
    });
  });

  group('AUT-05 · Profilini tamamla · eğitim adımı (SHT-02, SHT-03)', () {
    testWidgets('AUT-05.department → SHT-02 (seçili değerle) → seçim alana '
        'yazılır', (tester) async {
      await _pump(tester, state: _infoStep.copyWith(departmentId: 'd01'));
      _feedback().nextSheetResult = 'd10';

      await _tap(tester, _department);
      await tester.pump();

      expect(_feedback().sheets, [SheetId.sht02]);
      final sheet =
          _feedback().lastSheetBuilder!(
                tester.element(find.byKey(_department)),
              )
              as DepartmentPickerSheet;
      expect(sheet.value, 'd01');
      final context = tester.element(find.byKey(_department));
      expect(
        _pickerField(tester, _department).value,
        StaticLabels.department(context, 'd10'),
      );
    });

    testWidgets('AUT-05.year → SHT-03 (seçili değerle) → seçim alana yazılır', (
      tester,
    ) async {
      await _pump(tester, state: _infoStep.copyWith(year: YearLevel.prep));
      _feedback().nextSheetResult = YearLevel.third;

      await _tap(tester, _year);
      await tester.pump();

      expect(_feedback().sheets, [SheetId.sht03]);
      final sheet =
          _feedback().lastSheetBuilder!(tester.element(find.byKey(_year)))
              as YearPickerSheet;
      expect(sheet.value, YearLevel.prep);
      final context = tester.element(find.byKey(_year));
      expect(
        _pickerField(tester, _year).value,
        StaticLabels.year(context, YearLevel.third),
      );
    });

    testWidgets('sheet kapatılırsa değer değişmez', (tester) async {
      await _pump(tester, state: _infoStep);

      await _tap(tester, _department);
      await _tap(tester, _year);
      await tester.pump();

      expect(_feedback().sheets, [SheetId.sht02, SheetId.sht03]);
      expect(_pickerField(tester, _department).value, isNull);
      expect(_pickerField(tester, _year).value, isNull);
    });

    testWidgets('AUT-05.next boş alanlarla: iki "zorunlu" hatası; seçim '
        'hatayı siler; dolu formda 3. adım', (tester) async {
      await _pump(tester, state: _infoStep);
      final l10n = tester.l10n;

      await _tap(tester, _next);
      expect(_pickerField(tester, _department).errorText, l10n.authErrRequired);
      expect(_pickerField(tester, _year).errorText, l10n.authErrRequired);
      expect(find.text(l10n.authErrRequired), findsNWidgets(2));
      expect(find.text(l10n.authSetupEduTitle), findsOneWidget);

      _feedback().nextSheetResult = 'd03';
      await _tap(tester, _department);
      await tester.pump();
      expect(_pickerField(tester, _department).errorText, isNull);
      expect(find.text(l10n.authErrRequired), findsOneWidget);

      _feedback().nextSheetResult = YearLevel.fourth;
      await _tap(tester, _year);
      await tester.pump();
      await _tap(tester, _next);
      expect(find.text(l10n.authSetupInterestTitle), findsOneWidget);
    });

    testWidgets('AUT-05.back → 1. adım', (tester) async {
      await _pump(tester, state: _infoStep);

      await _tap(tester, _back);

      expect(find.text(tester.l10n.authSetupPhotoTitle), findsOneWidget);
      expect(find.byKey(_back), findsNothing);
    });
  });

  group('AUT-05 · Profilini tamamla · ilgi alanları ve gönderim (TST-04, '
      'TST-05, TST-57)', () {
    testWidgets(
      'AUT-05.toggleInterest.<id> seçer / kaldırır; sayaç güncellenir',
      (tester) async {
        await _pump(tester, state: _interestsStep);

        await _tap(tester, SetupProfileInterestsStep.keyOf('i07'));
        expect(_chip(tester, 'i07').selected, isTrue);
        expect(find.text('1/5'), findsOneWidget);

        await _tap(tester, SetupProfileInterestsStep.keyOf('i07'));
        expect(_chip(tester, 'i07').selected, isFalse);
        expect(find.text('0/5'), findsOneWidget);
      },
    );

    testWidgets('altıncı ilgi alanı seçilmez: TST-04', (tester) async {
      await _pump(
        tester,
        state: _interestsStep.copyWith(
          interests: const {'i01', 'i02', 'i03', 'i04', 'i05'},
        ),
      );

      await _tap(tester, SetupProfileInterestsStep.keyOf('i06'));

      expect(_feedback().toasts, [ToastId.tst04]);
      expect(_chip(tester, 'i06').selected, isFalse);
      expect(find.text('5/5'), findsOneWidget);
    });

    testWidgets('AUT-05.finish seçim yokken: "En az bir ilgi alanı seç" '
        'çiplerin 16 dp altında; seçim hatayı siler', (tester) async {
      await _pump(tester, state: _interestsStep);
      final l10n = tester.l10n;

      await _tap(tester, _finish);

      final line = find.byType(FormErrorLine);
      expect(
        find.descendant(
          of: line,
          matching: find.text(l10n.authSetupMinInterest),
        ),
        findsOneWidget,
      );
      expect(
        tester.getRect(line).top,
        tester.getRect(find.byType(Wrap)).bottom + 16,
      );
      expect(_users().callsTo('updateProfile'), isEmpty);
      expect(_button(tester, _finish).loading, isFalse);

      await _tap(tester, SetupProfileInterestsStep.keyOf('i01'));
      expect(line, findsNothing);
    });

    testWidgets('AUT-05.finish → profil yazılır, oturum yenilenir, TST-05; '
        'düğme yükleniyor kalır', (tester) async {
      await _pump(
        tester,
        state: _interestsStep.copyWith(interests: const {'i04', 'i01'}),
      );
      _signIn();

      await _tap(tester, _finish);
      await tester.pump();

      final users = _users();
      expect(users.createdProfiles, [
        (
          uid: _uid,
          email: _email,
          name: _name,
          nameLower: 'deneme kullanıcı',
          avatarSeed: _uid,
        ),
      ]);
      expect(
        users.profilePatches.single.patch,
        const UserProfilePatch(
          department: 'd10',
          year: YearLevel.first,
          interests: ['i01', 'i04'],
          profileComplete: true,
        ),
      );
      expect(users.users[_uid]!.profileComplete, isTrue);
      expect(_feedback().toasts, [ToastId.tst05]);
      expect(_feedback().toastParams.single.name, 'Deneme');
      // Ekran gezinmez; router yönlendirene kadar form kilitli.
      expect(_button(tester, _finish).loading, isTrue);
      expect(_button(tester, _back).disabled, isTrue);
      expect(find.byType(FormErrorLine), findsNothing);
    });

    testWidgets('fotoğraflı gönderim: profil yamasından sonra yüklenir, '
        'TST-57 → TST-05', (tester) async {
      await _pump(
        tester,
        state: _interestsStep.copyWith(
          interests: const {'i01'},
          avatar: kFakeJpeg,
          isDirty: true,
        ),
      );
      _signIn();

      await _tap(tester, _finish);
      await tester.pump();

      final users = _users();
      // Profil tamamlanınca oturum etkinleşir ve push jetonu yazılır (T-42);
      // AUT-05 sırası yalnızca profil yazımlarıdır.
      expect(
        [
          for (final call in users.calls)
            if (call.method != 'getUser' && call.method != 'upsertFcmToken')
              call.method,
        ],
        ['createProfile', 'updateProfile', 'updateAvatar'],
      );
      expect(users.users[_uid]!.avatarPath, users.avatarUploads.single.path);
      expect(_feedback().toasts, [ToastId.tst57, ToastId.tst05]);
    });

    testWidgets('çevrimdışı gönderim: TST-24, hata satırı yok', (tester) async {
      await _pump(
        tester,
        state: _interestsStep.copyWith(interests: const {'i01'}),
      );
      _signIn();
      _connectivity().isOffline = true;

      await _tap(tester, _finish);
      await tester.pump();

      expect(_feedback().toasts, [ToastId.tst24]);
      expect(_users().callsTo('createProfile'), isEmpty);
      expect(_button(tester, _finish).loading, isFalse);
      expect(find.byType(FormErrorLine), findsNothing);
    });

    testWidgets('sunucu hatası: çiplerin altında "Bir şeyler ters gitti"; '
        'yeniden deneme tamamlar', (tester) async {
      await _pump(
        tester,
        state: _interestsStep.copyWith(interests: const {'i01'}),
      );
      _signIn();
      _users().failNext(FirestoreError.permissionDenied);

      await _tap(tester, _finish);
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(FormErrorLine),
          matching: find.text(tester.l10n.sysErrorTitle),
        ),
        findsOneWidget,
      );
      expect(_button(tester, _finish).loading, isFalse);
      expect(_feedback().toasts, isEmpty);

      await _tap(tester, _finish);
      await tester.pump();
      expect(find.byType(FormErrorLine), findsNothing);
      expect(_feedback().toasts, [ToastId.tst05]);
    });

    testWidgets('ağ hatası: TST-24, hata satırı yok', (tester) async {
      await _pump(
        tester,
        state: _interestsStep.copyWith(interests: const {'i01'}),
      );
      _signIn();
      _users().failNext(FirestoreError.unavailable);

      await _tap(tester, _finish);
      await tester.pump();

      expect(_feedback().toasts, [ToastId.tst24]);
      expect(find.byType(FormErrorLine), findsNothing);
      expect(_button(tester, _finish).loading, isFalse);
    });

    testWidgets('AUT-05.back → 2. adım (seçimler korunur)', (tester) async {
      await _pump(tester, state: _interestsStep);
      final context = tester.element(find.byType(SetupProfileView));

      await _tap(tester, _back);

      expect(find.text(tester.l10n.authSetupEduTitle), findsOneWidget);
      expect(
        _pickerField(tester, _department).value,
        StaticLabels.department(context, 'd10'),
      );
      expect(
        _pickerField(tester, _year).value,
        StaticLabels.year(context, YearLevel.first),
      );
    });
  });

  group('AUT-05 · Profilini tamamla · kapat (DLG-25)', () {
    testWidgets('AUT-05.close seçim yokken: soru sorulmaz, oturum kapanır', (
      tester,
    ) async {
      await _pump(tester);

      await _tap(tester, _close);
      await tester.pump();

      expect(_feedback().dialogs, isEmpty);
      expect(_auth().callsTo('signOut'), hasLength(1));
    });

    testWidgets('AUT-05.close seçim varken: DLG-25 ("Kaydet" yok) → '
        '"Kaydetmeden çık" → oturum kapanır', (tester) async {
      await _pump(tester, state: _infoStep);
      _feedback().nextSheetResult = 'd01';
      await _tap(tester, _department);
      await tester.pump();
      _feedback().nextDialogResult = UnsavedChangesResult.discard;

      await _tap(tester, _close);
      await tester.pump();

      expect(_feedback().dialogs, [DialogId.dlg25]);
      final dialog =
          _feedback().lastDialogBuilder!(tester.element(find.byKey(_close)))
              as UnsavedChangesDialog;
      expect(dialog.hasSave, isFalse);
      expect(_auth().callsTo('signOut'), hasLength(1));
    });

    for (final result in [UnsavedChangesResult.keep, null]) {
      testWidgets('DLG-25 ${result?.name ?? 'scrim / geri'} → ekran ve '
          'seçimler yerinde, oturum açık', (tester) async {
        await _pump(
          tester,
          state: _interestsStep.copyWith(
            interests: const {'i03'},
            isDirty: true,
          ),
        );
        _feedback().nextDialogResult = result;

        await _tap(tester, _close);
        await tester.pump();

        expect(_feedback().dialogs, [DialogId.dlg25]);
        expect(_auth().callsTo('signOut'), isEmpty);
        expect(_chip(tester, 'i03').selected, isTrue);
      });
    }

    testWidgets('sistem geri tuşu seçim varken DLG-25 açar', (tester) async {
      await _pump(tester, state: _base.copyWith(isDirty: true));

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(_feedback().dialogs, [DialogId.dlg25]);
      expect(find.byType(SetupProfileView), findsOneWidget);
      expect(_auth().callsTo('signOut'), isEmpty);
    });

    testWidgets('gönderim sürerken kapat etkisizdir', (tester) async {
      await _pump(
        tester,
        state: _interestsStep.copyWith(
          interests: const {'i03'},
          isDirty: true,
          isSubmitting: true,
        ),
      );

      await _tap(tester, _close);

      expect(_button(tester, _finish).loading, isTrue);
      expect(_feedback().dialogs, isEmpty);
      expect(_auth().callsTo('signOut'), isEmpty);
    });
  });

  group('AUT-05 · Profilini tamamla · golden', () {
    testWidgets('1. adım (fotoğraf) açık + koyu', (tester) async {
      await goldenForThemes(
        tester,
        'AUT-05',
        const SetupProfileView(),
        overrides: _with(_base),
      );
    });

    testWidgets('1. adım, fotoğraf seçilmiş ("Fotoğraf eklendi" rozeti)', (
      tester,
    ) async {
      // Örnek görsel çözülemez: önizleme yerine baş harfler görünür (prototip
      // maketiyle aynı görünüm).
      await goldenForThemes(
        tester,
        'AUT-05__photo',
        const SetupProfileView(),
        overrides: _with(_base.copyWith(avatar: kFakeJpeg, isDirty: true)),
      );
    });

    testWidgets('2. adım (bölüm seçili, sınıf hatalı)', (tester) async {
      await goldenForThemes(
        tester,
        'AUT-05__info',
        const SetupProfileView(),
        overrides: _with(
          _infoStep.copyWith(
            departmentId: 'd10',
            errors: const {SetupProfileField.year: FormFieldError.required},
          ),
        ),
      );
    });

    testWidgets('3. adım (üç seçim)', (tester) async {
      await goldenForThemes(
        tester,
        'AUT-05__interests',
        const SetupProfileView(),
        overrides: _with(
          _interestsStep.copyWith(interests: const {'i01', 'i04', 'i06'}),
        ),
      );
    });
  });
}
