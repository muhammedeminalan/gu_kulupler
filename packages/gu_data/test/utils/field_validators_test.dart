// T-09 · FieldValidators (PLAN §9.1, §9.6 "Validator" sütunu; CD-130): her
// kural tek statik fonksiyon; geçerli değer `null`, geçersiz değer ilk
// `FieldError`. Tablo her fonksiyonun sınırlarını (son geçerli / ilk geçersiz
// değer) ve her hata türünü bir kez sabitler; sayılar PLAN §9.8 `Limits`
// tablosundaki değerlerdir.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/fake_app_clock.dart';
import '../helpers/repo_sources.dart';

/// Bir satır: açıklama, doğrulayıcının döndürdüğü, beklenen.
typedef _Case = (String label, FieldError? actual, FieldError? expected);

const FieldError _empty = FieldError.empty;
const FieldError _short = FieldError.tooShort;
const FieldError _long = FieldError.tooLong;
const FieldError _format = FieldError.invalidFormat;
const FieldError _range = FieldError.outOfRange;

/// [n] karakterlik metin.
String _x(int n) => 'x' * n;

/// [n] öğeli liste.
List<String> _items(int n, [String item = 'x']) => List.filled(n, item);

/// 2026-10-07 21:30 UTC = Istanbul 2026-10-08 00:30.
final DateTime _now = DateTime.utc(2026, 10, 7, 21, 30);
final FakeAppClock _clock = FakeAppClock(_now);

/// Fonksiyon adı → satırlar.
Map<String, List<_Case>> _table() => {
  'requiredId': [
    ('dolu', FieldValidators.requiredId('c01'), null),
    ('boş', FieldValidators.requiredId(''), _empty),
  ],
  'counter': [
    ('0', FieldValidators.counter(0), null),
    ('-1', FieldValidators.counter(-1), _range),
  ],
  'adminReason': [
    ('1', FieldValidators.adminReason('x'), null),
    ('300', FieldValidators.adminReason(_x(300)), null),
    ('boş', FieldValidators.adminReason(''), _empty),
    ('yalnızca boşluk', FieldValidators.adminReason('   '), _empty),
    ('301', FieldValidators.adminReason(_x(301)), _long),
  ],
  'name': [
    ('2', FieldValidators.name('Al'), null),
    ('60', FieldValidators.name(_x(60)), null),
    ('boş', FieldValidators.name(''), _empty),
    ('1', FieldValidators.name('A'), _short),
    // Tek kod noktası, iki UTF-16 birimi: alt sınır kod noktasıyla ölçülür.
    ('tek emoji', FieldValidators.name('👍'), _short),
    ('61', FieldValidators.name(_x(61)), _long),
  ],
  'nameLower': [
    ('2', FieldValidators.nameLower('al'), null),
    ('1', FieldValidators.nameLower('a'), _short),
    ('61', FieldValidators.nameLower(_x(61)), _long),
  ],
  'bio': [
    ('boş', FieldValidators.bio(''), null),
    ('140', FieldValidators.bio(_x(140)), null),
    ('141', FieldValidators.bio(_x(141)), _long),
  ],
  'department': [
    ('d01', FieldValidators.department('d01'), null),
    ('tabloda yok', FieldValidators.department('d99'), _format),
  ],
  'interests': [
    ('1', FieldValidators.interests(['i01']), null),
    (
      '5',
      FieldValidators.interests(['i01', 'i02', 'i03', 'i04', 'i05']),
      null,
    ),
    ('boş', FieldValidators.interests([]), _empty),
    ('boş, personel', FieldValidators.interests([], staff: true), null),
    (
      '6',
      FieldValidators.interests(['i01', 'i02', 'i03', 'i04', 'i05', 'i06']),
      _long,
    ),
    ('tekrarlı', FieldValidators.interests(['i01', 'i01']), _format),
    ('tabloda yok', FieldValidators.interests(['i99']), _format),
  ],
  'universityEmail': [
    (
      'öğrenci',
      FieldValidators.universityEmail('a@ogr.gumushane.edu.tr'),
      null,
    ),
    ('boş', FieldValidators.universityEmail(''), _empty),
    ('bozuk', FieldValidators.universityEmail('a@@gumushane.edu.tr'), _format),
    ('yabancı alan', FieldValidators.universityEmail('a@gmail.com'), _range),
  ],
  'emailLower': [
    (
      'küçültülmüş',
      FieldValidators.emailLower('a@x.tr', email: 'A@X.tr'),
      null,
    ),
    (
      'küçültülmemiş',
      FieldValidators.emailLower('A@x.tr', email: 'A@x.tr'),
      _format,
    ),
  ],
  'fcmTokenCount': [
    ('10', FieldValidators.fcmTokenCount(10), null),
    ('11', FieldValidators.fcmTokenCount(11), _long),
  ],
  'platform': [
    ('ios', FieldValidators.platform('ios'), null),
    ('web', FieldValidators.platform('web'), _format),
  ],
  'clubName': [
    ('1', FieldValidators.clubName('x'), null),
    ('boş', FieldValidators.clubName(''), _empty),
    ('61', FieldValidators.clubName(_x(61)), _long),
  ],
  'clubNameLower': [
    ('2', FieldValidators.clubNameLower('xx'), null),
    ('1', FieldValidators.clubNameLower('x'), _short),
  ],
  'categoryId': [
    ('k01', FieldValidators.categoryId('k01'), null),
    ('tabloda yok', FieldValidators.categoryId('k99'), _format),
  ],
  'founded': [
    ('1900', FieldValidators.founded(1900, _clock), null),
    ('bu yıl', FieldValidators.founded(2026, _clock), null),
    ('1899', FieldValidators.founded(1899, _clock), _range),
    ('gelecek yıl', FieldValidators.founded(2027, _clock), _range),
  ],
  'clubSummary': [
    ('160', FieldValidators.clubSummary(_x(160)), null),
    ('161', FieldValidators.clubSummary(_x(161)), _long),
  ],
  'clubAbout': [
    ('1000', FieldValidators.clubAbout(_x(1000)), null),
    ('1001', FieldValidators.clubAbout(_x(1001)), _long),
  ],
  'conditions': [
    ('boş liste', FieldValidators.conditions([]), null),
    ('10 madde', FieldValidators.conditions(_items(10, _x(120))), null),
    ('11 madde', FieldValidators.conditions(_items(11)), _long),
    ('boş madde', FieldValidators.conditions(['ok', '']), _empty),
    ('121 karakter madde', FieldValidators.conditions([_x(121)]), _long),
  ],
  'socialEmail': [
    ('serbest alan', FieldValidators.socialEmail('iletisim@kulup.org'), null),
    ('bozuk', FieldValidators.socialEmail('kulup.org'), _format),
  ],
  'instagram': [
    ('@ ile', FieldValidators.instagram('@gu_kulupler'), null),
    ('boşluklu', FieldValidators.instagram('@a b'), _format),
  ],
  'web': [
    ('https', FieldValidators.web('https://gumushane.edu.tr/kulup'), null),
    ('http', FieldValidators.web('http://kulup.org'), null),
    ('başka şema', FieldValidators.web('ftp://kulup.org'), _format),
    ('şemasız', FieldValidators.web('gumushane.edu.tr'), _format),
    ('alan adı yok', FieldValidators.web('https://'), _format),
    ('ayrışmayan', FieldValidators.web('http://[::1'), _format),
  ],
  'applicationNote': [
    (
      'boş, not istenmiyor',
      FieldValidators.applicationNote('', requireNote: false),
      null,
    ),
    (
      'boş, not isteniyor',
      FieldValidators.applicationNote('', requireNote: true),
      _empty,
    ),
    (
      '300',
      FieldValidators.applicationNote(_x(300), requireNote: true),
      null,
    ),
    (
      '301',
      FieldValidators.applicationNote(_x(301), requireNote: false),
      _long,
    ),
  ],
  'rejectNote': [
    ('200', FieldValidators.rejectNote(_x(200)), null),
    ('201', FieldValidators.rejectNote(_x(201)), _long),
  ],
  'rejectReason': [
    (
      'ret, nedenli',
      FieldValidators.rejectReason(
        RejectReason.quota,
        status: MembershipStatus.rejected,
      ),
      null,
    ),
    (
      'ret, nedensiz',
      FieldValidators.rejectReason(null, status: MembershipStatus.rejected),
      _empty,
    ),
    (
      'çıkarma, other',
      FieldValidators.rejectReason(
        RejectReason.other,
        status: MembershipStatus.removed,
      ),
      null,
    ),
    (
      'çıkarma, başka neden',
      FieldValidators.rejectReason(
        RejectReason.quota,
        status: MembershipStatus.removed,
      ),
      _range,
    ),
    (
      'bekleyen, nedensiz',
      FieldValidators.rejectReason(null, status: MembershipStatus.pending),
      null,
    ),
  ],
  'postText': [
    ('1000', FieldValidators.postText(_x(1000)), null),
    ('boş', FieldValidators.postText(''), _empty),
    ('1001', FieldValidators.postText(_x(1001)), _long),
  ],
  'postTitle': [
    (
      'duyuru, 80',
      FieldValidators.postTitle(_x(80), type: PostType.announcement),
      null,
    ),
    (
      'duyuru, başlıksız',
      FieldValidators.postTitle(null, type: PostType.announcement),
      _empty,
    ),
    (
      'duyuru, 81',
      FieldValidators.postTitle(_x(81), type: PostType.announcement),
      _long,
    ),
    (
      'gönderi, başlıksız',
      FieldValidators.postTitle(null, type: PostType.post),
      null,
    ),
    (
      'anket, başlıklı',
      FieldValidators.postTitle('x', type: PostType.poll),
      _format,
    ),
  ],
  'postImageCount': [
    ('4', FieldValidators.postImageCount(4), null),
    ('5', FieldValidators.postImageCount(5), _long),
  ],
  'postPoll': [
    (
      'anket, anketli',
      FieldValidators.postPoll(type: PostType.poll, hasPoll: true),
      null,
    ),
    (
      'anket, anketsiz',
      FieldValidators.postPoll(type: PostType.poll, hasPoll: false),
      _empty,
    ),
    (
      'gönderi, anketli',
      FieldValidators.postPoll(type: PostType.post, hasPoll: true),
      _format,
    ),
    (
      'duyuru, anketsiz',
      FieldValidators.postPoll(type: PostType.announcement, hasPoll: false),
      null,
    ),
  ],
  'pushSent': [
    (
      'duyuru, push',
      FieldValidators.pushSent(type: PostType.announcement, pushSent: true),
      null,
    ),
    (
      'gönderi, push',
      FieldValidators.pushSent(type: PostType.post, pushSent: true),
      _format,
    ),
    (
      'gönderi, push yok',
      FieldValidators.pushSent(type: PostType.post, pushSent: false),
      null,
    ),
  ],
  'pollOptions': [
    ('2', FieldValidators.pollOptions(['a', 'b']), null),
    ('4 × 60', FieldValidators.pollOptions(_items(4, _x(60))), null),
    ('boş', FieldValidators.pollOptions([]), _empty),
    ('1', FieldValidators.pollOptions(['a']), _short),
    ('5', FieldValidators.pollOptions(_items(5)), _long),
    ('boş seçenek', FieldValidators.pollOptions(['a', '']), _empty),
    ('61 karakter', FieldValidators.pollOptions(['a', _x(61)]), _long),
  ],
  'pollDurationDays': [
    for (final days in [1, 3, 7])
      ('$days gün', FieldValidators.pollDurationDays(days), null),
    ('2 gün', FieldValidators.pollDurationDays(2), _range),
  ],
  'comment': [
    ('500', FieldValidators.comment(_x(500)), null),
    ('boş', FieldValidators.comment(''), _empty),
    ('501', FieldValidators.comment(_x(501)), _long),
  ],
  'eventTitle': [
    ('80', FieldValidators.eventTitle(_x(80)), null),
    ('boş', FieldValidators.eventTitle(''), _empty),
    ('81', FieldValidators.eventTitle(_x(81)), _long),
  ],
  'eventDesc': [
    ('boş', FieldValidators.eventDesc(''), null),
    ('1001', FieldValidators.eventDesc(_x(1001)), _long),
  ],
  'placeId': [
    ('pl01', FieldValidators.placeId('pl01'), null),
    ('tabloda yok', FieldValidators.placeId('pl99'), _format),
  ],
  'placeText': [
    ('120', FieldValidators.placeText(_x(120)), null),
    ('121', FieldValidators.placeText(_x(121)), _long),
  ],
  'capacity': [
    ('sınırsız', FieldValidators.capacity(null, goingCount: 500), null),
    ('1', FieldValidators.capacity(1), null),
    ('0', FieldValidators.capacity(0), _range),
    ('kayıtlıya eşit', FieldValidators.capacity(30, goingCount: 30), null),
    ('kayıtlının altı', FieldValidators.capacity(29, goingCount: 30), _range),
  ],
  'eventEnd': [
    (
      'başlangıçtan sonra',
      FieldValidators.eventEnd(
        _now.add(const Duration(hours: 1)),
        startsAt: _now,
      ),
      null,
    ),
    (
      'başlangıçla aynı',
      FieldValidators.eventEnd(_now, startsAt: _now),
      _range,
    ),
  ],
  'eventStart': [
    (
      'gelecekte',
      FieldValidators.eventStart(
        _now.add(const Duration(seconds: 1)),
        _clock,
      ),
      null,
    ),
    ('şu an', FieldValidators.eventStart(_now, _clock), _range),
  ],
  'ticketCode': [
    ('geçerli', FieldValidators.ticketCode('GU-ABCD-2345'), null),
    ('0 içeren', FieldValidators.ticketCode('GU-ABCD-0000'), _format),
  ],
  'reportNote': [
    ('300', FieldValidators.reportNote(_x(300)), null),
    ('301', FieldValidators.reportNote(_x(301)), _long),
  ],
  'reportTarget': [
    (
      'gönderi',
      FieldValidators.reportTarget(
        targetType: ReportTargetType.post,
        targetId: 'p01',
        reporterId: 'u1',
        targetClubId: 'c01',
      ),
      null,
    ),
    (
      'başka kullanıcı',
      FieldValidators.reportTarget(
        targetType: ReportTargetType.user,
        targetId: 'u2',
        reporterId: 'u1',
        targetClubId: null,
      ),
      null,
    ),
    (
      'kendini şikayet',
      FieldValidators.reportTarget(
        targetType: ReportTargetType.user,
        targetId: 'u1',
        reporterId: 'u1',
        targetClubId: null,
      ),
      _format,
    ),
    (
      'kullanıcı hedefinde kulüp',
      FieldValidators.reportTarget(
        targetType: ReportTargetType.user,
        targetId: 'u2',
        reporterId: 'u1',
        targetClubId: 'c01',
      ),
      _format,
    ),
    (
      'etkinlik, kulüpsüz',
      FieldValidators.reportTarget(
        targetType: ReportTargetType.event,
        targetId: 'e01',
        reporterId: 'u1',
        targetClubId: null,
      ),
      _empty,
    ),
    (
      'yorum, boş kulüp',
      FieldValidators.reportTarget(
        targetType: ReportTargetType.comment,
        targetId: 'cm01',
        reporterId: 'u1',
        targetClubId: '',
      ),
      _empty,
    ),
    (
      'boş hedef',
      FieldValidators.reportTarget(
        targetType: ReportTargetType.club,
        targetId: '',
        reporterId: 'u1',
        targetClubId: 'c01',
      ),
      _empty,
    ),
    (
      'boş şikayetçi',
      FieldValidators.reportTarget(
        targetType: ReportTargetType.post,
        targetId: 'p01',
        reporterId: '',
        targetClubId: 'c01',
      ),
      _empty,
    ),
  ],
  'blockTarget': [
    (
      'başka kullanıcı',
      FieldValidators.blockTarget(blockerId: 'u1', blockedId: 'u2'),
      null,
    ),
    (
      'kendini engelleme',
      FieldValidators.blockTarget(blockerId: 'u1', blockedId: 'u1'),
      _format,
    ),
    (
      'boş engelleyen',
      FieldValidators.blockTarget(blockerId: '', blockedId: 'u2'),
      _empty,
    ),
    (
      'boş engellenen',
      FieldValidators.blockTarget(blockerId: 'u1', blockedId: ''),
      _empty,
    ),
  ],
  'reminderTime': [
    ('1h', FieldValidators.reminderTime(ReminderOption.oneHour), null),
    ('1d', FieldValidators.reminderTime(ReminderOption.oneDay), null),
    ('none', FieldValidators.reminderTime(ReminderOption.none), _range),
    (
      '15m',
      FieldValidators.reminderTime(ReminderOption.fifteenMinutes),
      _range,
    ),
    (
      'varsayılan ayar belgesi',
      FieldValidators.reminderTime(
        const UserSettingsModel.defaults('u1').reminderTime,
      ),
      null,
    ),
  ],
  'timeOfDay': [
    ('22:00', FieldValidators.timeOfDay('22:00'), null),
    ('24:00', FieldValidators.timeOfDay('24:00'), _format),
  ],
  'supportTicketNo': [
    ('geçerli', FieldValidators.supportTicketNo('GU-7K3Q9X'), null),
    ('kısa', FieldValidators.supportTicketNo('GU-7K3Q9'), _format),
  ],
  'supportMessage': [
    ('500', FieldValidators.supportMessage(_x(500)), null),
    ('boş', FieldValidators.supportMessage(''), _empty),
    ('501', FieldValidators.supportMessage(_x(501)), _long),
  ],
  'supportAttachmentCount': [
    ('1', FieldValidators.supportAttachmentCount(1), null),
    ('2', FieldValidators.supportAttachmentCount(2), _long),
  ],
  'announcementDay': [
    (
      'bugün (Istanbul)',
      FieldValidators.announcementDay('2026-10-08', _clock),
      null,
    ),
    (
      'UTC günü (dün)',
      FieldValidators.announcementDay('2026-10-07', _clock),
      _range,
    ),
    (
      'tiresiz',
      FieldValidators.announcementDay('20261008', _clock),
      _format,
    ),
  ],
  'announcementCount': [
    ('0', FieldValidators.announcementCount(0), null),
    ('2', FieldValidators.announcementCount(2), null),
    ('3', FieldValidators.announcementCount(3), _range),
    ('-1', FieldValidators.announcementCount(-1), _range),
  ],
};

void main() {
  final table = _table();

  group('T-09 · FieldValidators', () {
    test('FieldError beş hata türü taşır (PLAN §9.1)', () {
      expect(
        [for (final error in FieldError.values) error.name],
        ['empty', 'tooShort', 'tooLong', 'invalidFormat', 'outOfRange'],
      );
    });

    test('kaynaktaki her doğrulayıcı tabloda sınanır (eksik ve fazla yok)', () {
      final declared = RegExp(r'static FieldError\? ([a-z]\w*)\(')
          .allMatches(
            readRepoFile(
              'packages/gu_data/lib/src/utils/field_validators.dart',
            ),
          )
          .map((match) => match.group(1)!)
          .toSet();

      expect(declared, isNotEmpty);
      expect(table.keys.toSet(), declared);
    });

    for (final MapEntry(key: name, value: cases) in table.entries) {
      test('$name: sınırlar ve hata türleri', () {
        expect(
          {for (final (label, actual, _) in cases) label: actual},
          {for (final (label, _, expected) in cases) label: expected},
        );
      });
    }
  });
}
