// T-33 · SHT-25 · Başkan seç (`PresidentPickerSheet`): devir adayları
// (aktif member / board; başkan, danışman ve aktif olmayan hariç), ada göre
// Türkçe sıralama + arama, anahtarlar, seçim `pop(userId)`.
// Prototip sheets.js:117–119.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/president_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/device_matrix.dart';
import 'sheet_test_support.dart';

MembershipModel _m(
  String uid,
  String name,
  ClubRole role, {
  MembershipStatus status = MembershipStatus.active,
}) => MembershipModel(
  clubId: 'c03',
  userId: uid,
  status: status,
  role: role,
  applicant: MembershipApplicantModel(name: name, avatarSeed: uid),
);

/// Referans görüntüdeki gibi "bölüm · sınıf" satırlı adaylar (atama kipi).
final List<PresidentCandidate> _assignPool = [
  for (final (i, name, dept, year) in [
    (1, 'Alp Aksoy', 'd01', YearLevel.second),
    (2, 'Alp Arslan', 'd02', YearLevel.second),
    (3, 'Alp Korkmaz', 'd03', YearLevel.first),
    (4, 'Arda Polat', 'd04', YearLevel.fourth),
    (5, 'Aslı Çetin', 'd05', YearLevel.third),
    (6, 'Aslı Kaya', 'd06', YearLevel.third),
    (7, 'Ayça Acar', 'd07', YearLevel.first),
    (8, 'Ayça Aslan', 'd02', YearLevel.second),
    (9, 'Ayça Öztürk', 'd08', YearLevel.fourth),
    (10, 'Ayşe Demir', 'd09', YearLevel.first),
  ])
    PresidentCandidate(
      userId: 'u$i',
      name: name,
      avatarSeed: 'u$i',
      department: dept,
      year: year,
    ),
];

final List<MembershipModel> _members = [
  _m('u1', 'Zeynep', ClubRole.member),
  _m('u2', 'Ömer', ClubRole.board),
  _m('u3', 'Burak', ClubRole.president),
  _m('u4', 'Ayşe', ClubRole.advisor),
  _m('u5', 'Ilgaz', ClubRole.member),
  _m('u6', 'Can', ClubRole.member, status: MembershipStatus.removed),
];

void main() {
  test('devir adayları: aktif member / board', () {
    expect(
      PresidentPickerSheet.transferCandidates(_members).map((c) => c.userId),
      ['u1', 'u2', 'u5'],
    );
  });

  test('ada göre sıralı (Türkçe); arama Türkçe küçük harfle', () {
    final all = PresidentPickerSheet.transferCandidates(_members);
    expect(PresidentPickerSheet.filter(all, '').map((c) => c.name), [
      'Ilgaz',
      'Ömer',
      'Zeynep',
    ]);
    expect(
      PresidentPickerSheet.filter(all, 'ılg').map((c) => c.userId),
      ['u5'],
    );
  });

  test('anahtarlar prototipteki aksiyon adlarıdır', () {
    expect(PresidentPickerSheet.searchKey, GuKey.action('SHT-25.search'));
    expect(
      PresidentPickerSheet.selectKey('u1'),
      GuKey.action('SHT-25.select.u1'),
    );
  });

  testWidgets('satır → pop(userId)', (tester) async {
    final harness = SheetHarness<String>(
      SheetId.sht25,
      (_) => PresidentPickerSheet(
        candidates: PresidentPickerSheet.transferCandidates(_members),
      ),
    );
    await harness.pump(tester);
    await harness.open(tester);
    await tester.tap(find.byKey(PresidentPickerSheet.selectKey('u2')));
    await tester.pumpAndSettle();
    expect(harness.result, 'u2');
  });

  test('en çok 40 satır (`slice(0, 40)`)', () {
    final many = [
      for (var i = 0; i < 55; i++)
        PresidentCandidate(userId: 'u$i', name: 'Üye $i', avatarSeed: 'u$i'),
    ];
    expect(
      PresidentPickerSheet.filter(many, ''),
      hasLength(PresidentPickerSheet.maxRows),
    );
  });

  testWidgets('kip başlığı; arama süzer; eşleşme yoksa "Eşleşen üye yok"; '
      'X → null', (tester) async {
    final tr = lookupAppLocalizations(const Locale('tr'));
    final harness = SheetHarness<String>(
      SheetId.sht25,
      (_) => PresidentPickerSheet(
        candidates: PresidentPickerSheet.transferCandidates(_members),
      ),
    );
    await harness.pump(tester);
    await harness.open(tester);
    expect(find.text(tr.sht25Transfer), findsOneWidget);
    expect(find.text(tr.adminUsersSearch), findsOneWidget);

    await tester.enterText(find.byKey(PresidentPickerSheet.searchKey), 'zey');
    await tester.pump();
    expect(find.byKey(PresidentPickerSheet.selectKey('u1')), findsOneWidget);
    expect(find.byKey(PresidentPickerSheet.selectKey('u2')), findsNothing);

    await tester.enterText(find.byKey(PresidentPickerSheet.searchKey), 'xyz');
    await tester.pump();
    expect(find.text(tr.membersNoResults), findsOneWidget);

    await tester.tap(find.byKey(GuKey.action('SHT-25.close')));
    await tester.pumpAndSettle();
    expect(harness.result, isNull);

    harness.builder = (_) => PresidentPickerSheet(
      candidates: _assignPool,
      mode: PresidentPickerMode.assign,
    );
    await harness.open(tester);
    expect(find.text(tr.sht25Assign), findsOneWidget);
  });

  testWidgets('cihaz matrisi: uzun ad + bölüm — taşma yok', (tester) async {
    await DeviceMatrix.run(
      tester,
      (_) => const Align(
        alignment: Alignment.bottomCenter,
        child: PresidentPickerSheet(
          candidates: [
            PresidentCandidate(
              userId: 'u1',
              name:
                  'Muhammed Abdurrahman Çağlayan Karaosmanoğlu Büyükçekmeceli',
              avatarSeed: 'u1',
              department: 'd10',
              year: YearLevel.fourth,
            ),
          ],
        ),
      ),
      safeAreas: true,
    );
  });

  testWidgets('golden: atama kipi, aday listesi — açık + koyu (TR)', (
    tester,
  ) async {
    await SheetHarness<String>(
      SheetId.sht25,
      (_) => PresidentPickerSheet(
        candidates: _assignPool,
        mode: PresidentPickerMode.assign,
      ),
    ).golden(tester, 'SHT-25');
  });
}
