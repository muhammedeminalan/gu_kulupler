// T-34 · MGT-05 · Etkinlik formu gövdesi (`EventForm`): üç adımın alanları
// ve geri çağrıları (tür, ad / açıklama sayacı, kapak → SHT-31, tarih / saat
// → SHT-28 / SHT-29, mekân → SHT-30, kontenjan "Sınırsız" + adımlayıcı,
// görünürlük, otomatik hatırlatıcı), düzenleme ("Şu an N kayıtlı"), kilitli
// tarih / saat (W-82), alan hataları, önizleme + özet, uzun metin 320 × 1.6,
// cihaz matrisi, 1. adım açık + koyu golden. Referans:
// design/reference-shots/screens/MGT-05__{light,dark}__tr.webp; prototip
// screens-manage.js:86–117.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/management/provider/event_form_state.dart';
import 'package:gu_kulupler/features/management/view/widget/event_form.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/widget/event/event_card.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../../helpers/device_matrix.dart';
import '../../../../helpers/golden_helper.dart';
import '../../../../helpers/pump_app.dart';
import '../../manage_test_support.dart';

final AppLocalizations _tr = lookupAppLocalizations(const Locale('tr'));

/// 19 Ekim 2026 18:00 – 20:00 Istanbul.
final DateTime _start = DateTime.utc(2026, 10, 19, 15);
final DateTime _end = DateTime.utc(2026, 10, 19, 17);

/// Geri çağrı günlüğü.
final class _Calls {
  final List<String> taps = [];
  final List<Object?> values = [];
}

EventForm _form(
  _Calls calls, {
  EventFormStep step = EventFormStep.basics,
  String title = '',
  String desc = '',
  EventType? type = EventType.social,
  String? placeId,
  String placeText = '',
  int? capacity = 40,
  EventVisibility visibility = EventVisibility.public,
  Map<EventField, FormFieldError> errors = const {},
  bool timeLocked = false,
  int minCapacity = 1,
  int? registeredCount,
  int conflictCount = 0,
  ImageProvider? coverImage,
}) => EventForm(
  step: step,
  title: title,
  desc: desc,
  type: type,
  startsAt: _start,
  endsAt: _end,
  placeId: placeId,
  placeText: placeText,
  capacity: capacity,
  visibility: visibility,
  autoReminder: true,
  coverPalette: kManageClub.palette,
  coverPattern: ClubPattern.mountain,
  errors: errors,
  timeLocked: timeLocked,
  minCapacity: minCapacity,
  club: kManageClub,
  registeredCount: registeredCount,
  conflictCount: conflictCount,
  coverImage: coverImage,
  onTitleChanged: (v) => calls.values.add(('title', v)),
  onDescChanged: (v) => calls.values.add(('desc', v)),
  onTypeChanged: (v) => calls.values.add(('type', v)),
  onCoverTap: () => calls.taps.add('cover'),
  onStartDateTap: () => calls.taps.add('startDate'),
  onStartTimeTap: () => calls.taps.add('startTime'),
  onEndDateTap: () => calls.taps.add('endDate'),
  onEndTimeTap: () => calls.taps.add('endTime'),
  onPlaceTap: () => calls.taps.add('place'),
  onCapacityChanged: (v) => calls.values.add(('capacity', v)),
  onVisibilityChanged: (v) => calls.values.add(('visibility', v)),
  onAutoReminderChanged: (v) => calls.values.add(('autoReminder', v)),
);

/// Formu çağıran gibi kaydırılabilir `px16 pt8 pb24` gövdede çizer.
Widget _host(EventForm form) => Scaffold(
  body: SingleChildScrollView(
    padding: GuInsets.only(
      left: GuSpacing.s16,
      right: GuSpacing.s16,
      top: GuSpacing.s8,
      bottom: GuSpacing.s24,
    ),
    child: form,
  ),
);

Key _k(String action) => GuKey.action('MGT-05.$action');

Future<void> _tap(WidgetTester tester, String action) async {
  await tester.ensureVisible(find.byKey(_k(action)));
  await tester.tap(find.byKey(_k(action)));
  await tester.pump();
}

void main() {
  group('T-34 · MGT-05 · EventForm', () {
    testWidgets('yüklenmemiş yerel kapak (coverImage) şablonun yerine '
        'çizilir', (tester) async {
      final image = MemoryImage(Uint8List.fromList(const [0, 1, 2]));
      await tester.pumpApp(_host(_form(_Calls(), coverImage: image)));
      final cover = tester.widget<GuCover>(
        find.descendant(
          of: find.byKey(_k('cover')),
          matching: find.byType(GuCover),
        ),
      );
      expect(cover.image, same(image));
      // Bozuk bayt çözülemez; görsel hatası testi düşürmesin.
      tester.takeException();
    });

    testWidgets('1. adım: kapak · ad · açıklama · tür; dokunuşlar geri '
        'çağrılara gider', (tester) async {
      final calls = _Calls();
      await tester.pumpApp(_host(_form(calls)));
      for (final action in [
        'cover',
        'title',
        'desc',
        for (final type in EventType.values) 'type.${type.json}',
      ]) {
        expect(find.byKey(_k(action)), findsOneWidget, reason: action);
      }
      expect(find.text(_tr.eventFormChangeCover), findsOneWidget);
      expect(find.text(_tr.eventFormName), findsOneWidget);
      expect(find.text(_tr.eventFormType), findsOneWidget);
      // 2. adımın anahtarları yok.
      expect(find.byKey(_k('startDate')), findsNothing);

      await _tap(tester, 'cover');
      await tester.enterText(find.byKey(_k('title')), 'Kış kampı');
      await tester.enterText(find.byKey(_k('desc')), 'Uludağ');
      await _tap(tester, 'type.gezi');
      expect(calls.taps, ['cover']);
      expect(calls.values, [
        ('title', 'Kış kampı'),
        ('desc', 'Uludağ'),
        ('type', EventType.trip),
      ]);
      final chips = tester.widgetList<GuChip>(find.byType(GuChip));
      expect(chips.where((c) => c.selected).map((c) => c.label), [
        _tr.eventTypeSosyal,
      ]);
    });

    testWidgets('ViewModel kesince alan kesilmiş metni gösterir', (
      tester,
    ) async {
      final calls = _Calls();
      await tester.pumpApp(_host(_form(calls, title: 'Önce')));
      await tester.pumpApp(_host(_form(calls, title: 'Sonra')));
      final field = tester.widget<TextField>(find.byKey(_k('title')));
      expect(field.controller!.text, 'Sonra');
    });

    testWidgets('2. adım: tarih / saat / mekân / kontenjan / görünürlük / '
        'hatırlatıcı', (tester) async {
      final calls = _Calls();
      await tester.pumpApp(
        _host(_form(calls, step: EventFormStep.schedule, placeId: 'pl05')),
      );
      expect(find.text('18:00'), findsOneWidget);
      expect(find.text('20:00'), findsOneWidget);
      expect(find.text(_tr.placePl05), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
      expect(find.text(_tr.eventFormVisibilityHelpPublic), findsOneWidget);

      for (final action in [
        'startDate',
        'startTime',
        'endDate',
        'endTime',
        'place',
      ]) {
        await _tap(tester, action);
      }
      expect(calls.taps, [
        'startDate',
        'startTime',
        'endDate',
        'endTime',
        'place',
      ]);

      await _tap(tester, 'capacity.plus');
      await _tap(tester, 'capacity.minus');
      await _tap(tester, 'unlimited');
      await _tap(tester, 'visibility.members');
      await _tap(tester, 'autoReminder');
      expect(calls.values, [
        ('capacity', 40 + EventForm.capacityStep),
        ('capacity', 40 - EventForm.capacityStep),
        ('capacity', null),
        ('visibility', EventVisibility.membersOnly),
        ('autoReminder', false),
      ]);
    });

    testWidgets('sınırsız: adımlayıcı yok; kapatınca son değer (alt sınıra '
        'çekilmiş) döner', (tester) async {
      final calls = _Calls();
      await tester.pumpApp(
        _host(
          _form(
            calls,
            step: EventFormStep.schedule,
            capacity: null,
            minCapacity: 55,
          ),
        ),
      );
      expect(find.byKey(_k('capacity.plus')), findsNothing);
      await _tap(tester, 'unlimited');
      expect(calls.values, [('capacity', 55)]);
    });

    testWidgets('düzenleme: "Şu an N kayıtlı"; eksi alt sınırda devre dışı', (
      tester,
    ) async {
      final calls = _Calls();
      await tester.pumpApp(
        _host(
          _form(
            calls,
            step: EventFormStep.schedule,
            capacity: 12,
            minCapacity: 12,
            registeredCount: 12,
          ),
        ),
      );
      expect(find.text(_tr.eventFormRegisteredNow(12)), findsOneWidget);
      await _tap(tester, 'capacity.minus');
      expect(calls.values, isEmpty);
    });

    testWidgets('W-82: başlamış yayındaki etkinlikte tarih / saat kilitli + '
        'açıklama', (tester) async {
      final calls = _Calls();
      await tester.pumpApp(
        _host(_form(calls, step: EventFormStep.schedule, timeLocked: true)),
      );
      expect(find.text(_tr.eventFormTimeLocked), findsOneWidget);
      for (final action in ['startDate', 'startTime', 'endDate', 'endTime']) {
        expect(
          tester
              .widget<GuPickerField>(
                find.ancestor(
                  of: find.byKey(_k(action)),
                  matching: find.byType(GuPickerField),
                ),
              )
              .disabled,
          isTrue,
          reason: action,
        );
        await _tap(tester, action);
      }
      expect(calls.taps, isEmpty);
      // Mekân kilitli değil.
      await _tap(tester, 'place');
      expect(calls.taps, ['place']);
    });

    testWidgets('alan hataları ARB metinleriyle; çakışma bandı', (
      tester,
    ) async {
      final calls = _Calls();
      await tester.pumpApp(
        _host(
          _form(
            calls,
            step: EventFormStep.schedule,
            capacity: 10,
            minCapacity: 15,
            registeredCount: 15,
            conflictCount: 2,
            errors: const {
              EventField.startsAt: FormFieldError.invalidFormat,
              EventField.endsAt: FormFieldError.endBeforeStart,
              EventField.place: FormFieldError.required,
              EventField.capacity: FormFieldError.capacityBelowGoing,
            },
          ),
        ),
      );
      expect(find.text(_tr.eventFormErrFuture), findsOneWidget);
      expect(find.text(_tr.eventFormErrEndAfter), findsOneWidget);
      expect(find.text(_tr.authErrRequired), findsOneWidget);
      expect(find.text(_tr.eventFormErrCapacity(15)), findsOneWidget);
      expect(find.text(_tr.eventFormRegisteredNow(15)), findsNothing);
      expect(find.text(_tr.eventFormConflict(2)), findsOneWidget);
    });

    testWidgets('1. adım: ad zorunlu hatası', (tester) async {
      await tester.pumpApp(
        _host(
          _form(
            _Calls(),
            errors: const {EventField.title: FormFieldError.required},
          ),
        ),
      );
      expect(find.text(_tr.authErrRequired), findsOneWidget);
    });

    testWidgets('3. adım: önizleme kartı + özet (adsız → "Adsız etkinlik")', (
      tester,
    ) async {
      await tester.pumpApp(
        _host(
          _form(
            _Calls(),
            step: EventFormStep.settings,
            placeText: 'Kafeterya',
            capacity: null,
          ),
        ),
      );
      expect(find.text(_tr.eventFormPreviewNote), findsOneWidget);
      expect(find.byType(EventCard), findsOneWidget);
      expect(find.text(_tr.eventFormUntitled), findsOneWidget);
      expect(find.text(_tr.eventTypeSosyal), findsOneWidget);
      expect(find.text('Kafeterya'), findsWidgets);
      expect(find.text(_tr.eventFormUnlimited), findsOneWidget);
      expect(find.text(_tr.eventVisibilityPublic), findsOneWidget);
    });

    testWidgets('uzun metin 320 × 1.6: taşma yok (üç adım)', (tester) async {
      final long = 'Uzun etkinlik adı ' * 5;
      for (final step in EventFormStep.values) {
        await DeviceMatrix.run(
          tester,
          (_) => _host(
            _form(
              _Calls(),
              step: step,
              title: long,
              desc: long * 4,
              placeText: long,
              registeredCount: 999,
              conflictCount: 3,
              timeLocked: true,
              errors: const {EventField.capacity: FormFieldError.required},
            ),
          ),
        );
      }
    });

    testWidgets('golden: 1. adım (yeni, c03) — açık + koyu (TR)', (
      tester,
    ) async {
      await goldenForThemes(
        tester,
        'event_form__basics',
        _host(_form(_Calls())),
      );
    });

    testWidgets('golden: 2. adım (düzenleme) — açık + koyu (TR)', (
      tester,
    ) async {
      await goldenForThemes(
        tester,
        'event_form__schedule',
        _host(
          _form(
            _Calls(),
            step: EventFormStep.schedule,
            placeId: 'pl01',
            registeredCount: 12,
            minCapacity: 12,
          ),
        ),
      );
    });
  });
}
