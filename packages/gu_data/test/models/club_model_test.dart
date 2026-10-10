// T-09 · ClubModel (+ gömülü ClubSocialModel, ClubAdvisorModel): JSON
// gidiş-dönüşü, PLAN §9.6.3 tablosuyla alan / anahtar / varsayılan paritesi
// (tablo docs/PLAN.md'den okunur), copyWith ve eşitlik, türetilmiş alanlar.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/plan_model_table_club_group.dart';

final DateTime _createdAt = DateTime.utc(2026, 9, 1, 8, 30, 15, 123);
final DateTime _updatedAt = DateTime.utc(2026, 10, 8, 20, 15, 1, 456);
final DateTime _deletedAt = DateTime.utc(2026, 10, 9, 6, 0, 0, 789);
final DateTime _otherTime = DateTime.utc(2027, 1, 2, 3, 4, 5, 6);

const ClubSocialModel _social = ClubSocialModel(
  email: 'yazilim@gumushane.edu.tr',
  instagram: '@gu_yazilim',
  web: 'https://yazilim.example.org',
);

const ClubAdvisorModel _advisor = ClubAdvisorModel(
  name: 'Hakan Yalçın',
  title: 'Doç. Dr.',
  userId: 'u_hakan',
);

/// Her alanı varsayılanından farklı ve dolu olan kulüp.
final ClubModel _full = ClubModel(
  id: 'c01',
  name: 'Yazılım Kulübü',
  nameLower: 'yazılım kulübü',
  categoryId: 'k01',
  iconName: 'code-xml',
  palette: ClubPalette.slate,
  pattern: ClubPattern.waves,
  coverSeed: 'ozel-tohum',
  logoPath: 'clubs/c01/20261008T201501Z_3f9a1c2b7d4e5f60.jpg',
  coverPath: 'clubs/c01/20261008T201502Z_0011223344556677.png',
  memberCount: 80,
  approvalRequired: false,
  applicationsOpen: false,
  requireNote: true,
  founded: 2012,
  summary: 'Kod yazan öğrenciler',
  about: 'Uzun tanıtım',
  conditions: const ['Öğrenci olmak'],
  social: _social,
  presidentId: 'u_ayse',
  pinnedPostId: 'p07',
  advisor: _advisor,
  status: ClubStatus.suspended,
  suspendReason: 'İnceleme',
  lastMembershipRef: 'memberships/c01_u_ayse',
  createdBy: 'u_admin',
  createdAt: _createdAt,
  updatedAt: _updatedAt,
  isDeleted: true,
  deletedAt: _deletedAt,
  deletedBy: 'u_admin',
);

/// Yalnızca zorunlu alanları taşıyan belge verisi.
const Map<String, Object?> _minimalJson = {
  'name': 'Dağcılık',
  'nameLower': 'dağcılık',
  'categoryId': 'k03',
  'iconName': 'mountain',
  'palette': 'red',
  'pattern': 'mountain',
  'founded': 1998,
  'presidentId': 'u_mehmet',
};

void main() {
  final table = ClubGroupPlanTable.read('9.6.3');

  group('T-09 · ClubModel', () {
    test('toJson → fromJson aynı modeli verir; zamanlar Timestamp olur', () {
      final json = _full.toJson();

      expect(ClubModel.fromJson(json, id: _full.id), _full);
      for (final key in table.jsonKeysOfType('DateTime')) {
        expect(json[key], isA<Timestamp>(), reason: key);
      }
      expect(json.values.whereType<FieldValue>(), isEmpty);
    });

    test('JSON anahtarları PLAN §9.6.3 tablosuyla aynıdır (id yazılmaz)', () {
      expect(_full.toJson().keys.toSet(), table.jsonKeys);
    });

    test('gömülü nesneler Map olarak yazılır', () {
      final json = _full.toJson();

      expect(json['social'], {
        'email': 'yazilim@gumushane.edu.tr',
        'instagram': '@gu_yazilim',
        'web': 'https://yazilim.example.org',
      });
      expect(json['advisor'], {
        'name': 'Hakan Yalçın',
        'title': 'Doç. Dr.',
        'userId': 'u_hakan',
      });
    });

    test('eksik alanlar tablo varsayılanını alır; fazla anahtar ve verideki '
        'id yok sayılır', () {
      final model = ClubModel.fromJson(const {
        ..._minimalJson,
        'id': 'veri-icindeki-id',
        'gelecekAlan': 1,
      }, id: 'c03');

      expect(_minimalJson.keys.toSet(), table.requiredJsonKeys);
      expect(model.id, 'c03');
      expect(
        model,
        const ClubModel(
          id: 'c03',
          name: 'Dağcılık',
          nameLower: 'dağcılık',
          categoryId: 'k03',
          iconName: 'mountain',
          palette: ClubPalette.red,
          pattern: ClubPattern.mountain,
          founded: 1998,
          presidentId: 'u_mehmet',
        ),
      );
      table.expectDefaults(
        {
          'coverSeed': model.coverSeed,
          'logoPath': model.logoPath,
          'coverPath': model.coverPath,
          'memberCount': model.memberCount,
          'approvalRequired': model.approvalRequired,
          'applicationsOpen': model.applicationsOpen,
          'requireNote': model.requireNote,
          'summary': model.summary,
          'about': model.about,
          'conditions': model.conditions,
          'social': model.social,
          'pinnedPostId': model.pinnedPostId,
          'advisor': model.advisor,
          'status': model.status,
          'suspendReason': model.suspendReason,
          'lastMembershipRef': model.lastMembershipRef,
          'createdBy': model.createdBy,
          'createdAt': model.createdAt,
          'updatedAt': model.updatedAt,
          'isDeleted': model.isDeleted,
          'deletedAt': model.deletedAt,
          'deletedBy': model.deletedBy,
        },
        codes: {
          'FirestoreIds.clubCoverSeed(id)': FirestoreIds.clubCoverSeed('c03'),
          'const []': const <String>[],
          'const ClubSocialModel()': const ClubSocialModel(),
          'ClubStatus.active': ClubStatus.active,
        },
      );
    });

    test('bilinmeyen status varsayılana düşmez, hata verir', () {
      expect(
        () => ClubModel.fromJson(const {
          ..._minimalJson,
          'status': 'frozen',
        }, id: 'c'),
        throwsParseError,
      );
    });

    test('copyWith her alanı değiştirir; her alan eşitliğe girer', () {
      const social = ClubSocialModel(web: 'https://baska.example.org');
      const advisor = ClubAdvisorModel(name: 'Elif Kaya', title: '');

      expect(_full.copyWith(), _full);
      expectFieldCases<ClubModel>(_full, [
        (
          field: 'id',
          copy: _full.copyWith(id: 'c02'),
          read: (m) => m.id,
          expected: 'c02',
        ),
        (
          field: 'name',
          copy: _full.copyWith(name: 'Satranç'),
          read: (m) => m.name,
          expected: 'Satranç',
        ),
        (
          field: 'nameLower',
          copy: _full.copyWith(nameLower: 'satranç'),
          read: (m) => m.nameLower,
          expected: 'satranç',
        ),
        (
          field: 'categoryId',
          copy: _full.copyWith(categoryId: 'k05'),
          read: (m) => m.categoryId,
          expected: 'k05',
        ),
        (
          field: 'iconName',
          copy: _full.copyWith(iconName: 'crown'),
          read: (m) => m.iconName,
          expected: 'crown',
        ),
        (
          field: 'palette',
          copy: _full.copyWith(palette: ClubPalette.bordeaux),
          read: (m) => m.palette,
          expected: ClubPalette.bordeaux,
        ),
        (
          field: 'pattern',
          copy: _full.copyWith(pattern: ClubPattern.dots),
          read: (m) => m.pattern,
          expected: ClubPattern.dots,
        ),
        (
          field: 'coverSeed',
          copy: _full.copyWith(coverSeed: 'yeni-tohum'),
          read: (m) => m.coverSeed,
          expected: 'yeni-tohum',
        ),
        (
          field: 'logoPath',
          copy: _full.copyWith(logoPath: 'clubs/c01/yeni.jpg'),
          read: (m) => m.logoPath,
          expected: 'clubs/c01/yeni.jpg',
        ),
        (
          field: 'coverPath',
          copy: _full.copyWith(coverPath: 'clubs/c01/kapak.webp'),
          read: (m) => m.coverPath,
          expected: 'clubs/c01/kapak.webp',
        ),
        (
          field: 'memberCount',
          copy: _full.copyWith(memberCount: 81),
          read: (m) => m.memberCount,
          expected: 81,
        ),
        (
          field: 'approvalRequired',
          copy: _full.copyWith(approvalRequired: true),
          read: (m) => m.approvalRequired,
          expected: true,
        ),
        (
          field: 'applicationsOpen',
          copy: _full.copyWith(applicationsOpen: true),
          read: (m) => m.applicationsOpen,
          expected: true,
        ),
        (
          field: 'requireNote',
          copy: _full.copyWith(requireNote: false),
          read: (m) => m.requireNote,
          expected: false,
        ),
        (
          field: 'founded',
          copy: _full.copyWith(founded: 2020),
          read: (m) => m.founded,
          expected: 2020,
        ),
        (
          field: 'summary',
          copy: _full.copyWith(summary: 'Yeni özet'),
          read: (m) => m.summary,
          expected: 'Yeni özet',
        ),
        (
          field: 'about',
          copy: _full.copyWith(about: 'Yeni tanıtım'),
          read: (m) => m.about,
          expected: 'Yeni tanıtım',
        ),
        (
          field: 'conditions',
          copy: _full.copyWith(conditions: const ['A', 'B']),
          read: (m) => m.conditions,
          expected: const ['A', 'B'],
        ),
        (
          field: 'social',
          copy: _full.copyWith(social: social),
          read: (m) => m.social,
          expected: social,
        ),
        (
          field: 'presidentId',
          copy: _full.copyWith(presidentId: 'u_can'),
          read: (m) => m.presidentId,
          expected: 'u_can',
        ),
        (
          field: 'pinnedPostId',
          copy: _full.copyWith(pinnedPostId: 'p09'),
          read: (m) => m.pinnedPostId,
          expected: 'p09',
        ),
        (
          field: 'advisor',
          copy: _full.copyWith(advisor: advisor),
          read: (m) => m.advisor,
          expected: advisor,
        ),
        (
          field: 'status',
          copy: _full.copyWith(status: ClubStatus.active),
          read: (m) => m.status,
          expected: ClubStatus.active,
        ),
        (
          field: 'suspendReason',
          copy: _full.copyWith(suspendReason: 'Başka gerekçe'),
          read: (m) => m.suspendReason,
          expected: 'Başka gerekçe',
        ),
        (
          field: 'lastMembershipRef',
          copy: _full.copyWith(lastMembershipRef: 'memberships/c01_u_can'),
          read: (m) => m.lastMembershipRef,
          expected: 'memberships/c01_u_can',
        ),
        (
          field: 'createdBy',
          copy: _full.copyWith(createdBy: 'u_admin2'),
          read: (m) => m.createdBy,
          expected: 'u_admin2',
        ),
        (
          field: 'createdAt',
          copy: _full.copyWith(createdAt: _otherTime),
          read: (m) => m.createdAt,
          expected: _otherTime,
        ),
        (
          field: 'updatedAt',
          copy: _full.copyWith(updatedAt: _otherTime),
          read: (m) => m.updatedAt,
          expected: _otherTime,
        ),
        (
          field: 'isDeleted',
          copy: _full.copyWith(isDeleted: false),
          read: (m) => m.isDeleted,
          expected: false,
        ),
        (
          field: 'deletedAt',
          copy: _full.copyWith(deletedAt: _otherTime),
          read: (m) => m.deletedAt,
          expected: _otherTime,
        ),
        (
          field: 'deletedBy',
          copy: _full.copyWith(deletedBy: 'u_admin2'),
          read: (m) => m.deletedBy,
          expected: 'u_admin2',
        ),
      ], fields: table.fields);
    });

    test('copyWith clear* bayrakları null olabilen her alanı null yapar', () {
      expectFieldCases<ClubModel>(_full, [
        (
          field: 'logoPath',
          copy: _full.copyWith(clearLogoPath: true),
          read: (m) => m.logoPath,
          expected: null,
        ),
        (
          field: 'coverPath',
          copy: _full.copyWith(clearCoverPath: true),
          read: (m) => m.coverPath,
          expected: null,
        ),
        (
          field: 'pinnedPostId',
          copy: _full.copyWith(clearPinnedPostId: true),
          read: (m) => m.pinnedPostId,
          expected: null,
        ),
        (
          field: 'advisor',
          copy: _full.copyWith(clearAdvisor: true),
          read: (m) => m.advisor,
          expected: null,
        ),
        (
          field: 'suspendReason',
          copy: _full.copyWith(clearSuspendReason: true),
          read: (m) => m.suspendReason,
          expected: null,
        ),
        (
          field: 'lastMembershipRef',
          copy: _full.copyWith(clearLastMembershipRef: true),
          read: (m) => m.lastMembershipRef,
          expected: null,
        ),
        (
          field: 'createdBy',
          copy: _full.copyWith(clearCreatedBy: true),
          read: (m) => m.createdBy,
          expected: null,
        ),
        (
          field: 'createdAt',
          copy: _full.copyWith(clearCreatedAt: true),
          read: (m) => m.createdAt,
          expected: null,
        ),
        (
          field: 'updatedAt',
          copy: _full.copyWith(clearUpdatedAt: true),
          read: (m) => m.updatedAt,
          expected: null,
        ),
        (
          field: 'deletedAt',
          copy: _full.copyWith(clearDeletedAt: true),
          read: (m) => m.deletedAt,
          expected: null,
        ),
        (
          field: 'deletedBy',
          copy: _full.copyWith(clearDeletedBy: true),
          read: (m) => m.deletedBy,
          expected: null,
        ),
      ], fields: table.nullableFields);
    });

    test('türetilmiş coverSeed kimliği izler; açık verilen korunur', () {
      final derived = ClubModel.fromJson(_minimalJson, id: 'c03');

      expect(
        derived.copyWith(id: 'c04').coverSeed,
        FirestoreIds.clubCoverSeed('c04'),
      );
      expect(_full.copyWith(id: 'c04').coverSeed, 'ozel-tohum');
    });

    test('isSuspended ve hasCustomCover alanlardan türer', () {
      final active = ClubModel.fromJson(_minimalJson, id: 'c03');

      expect(active.isSuspended, isFalse);
      expect(active.hasCustomCover, isFalse);
      expect(active.isLive, isTrue);
      expect(_full.isSuspended, isTrue);
      expect(_full.hasCustomCover, isTrue);
      expect(_full.isLive, isFalse);
    });
  });

  group('T-09 · ClubSocialModel', () {
    test('anahtarları PLAN tanımıyla aynıdır; alanlar varsayılan null', () {
      expect(
        _social.toJson().keys.toSet(),
        ClubGroupPlanTable.embeddedKeys('ClubSocialModel'),
      );
      expect(ClubSocialModel.fromJson(const {}), const ClubSocialModel());
      expect(const ClubSocialModel().props, [null, null, null]);
    });

    test('copyWith her alanı değiştirir ve null yapar', () {
      final fields = ClubGroupPlanTable.embeddedKeys('ClubSocialModel');

      expect(_social.copyWith(), _social);
      expectFieldCases<ClubSocialModel>(_social, [
        (
          field: 'email',
          copy: _social.copyWith(email: 'a@b.co'),
          read: (m) => m.email,
          expected: 'a@b.co',
        ),
        (
          field: 'instagram',
          copy: _social.copyWith(instagram: 'gu.kulup'),
          read: (m) => m.instagram,
          expected: 'gu.kulup',
        ),
        (
          field: 'web',
          copy: _social.copyWith(web: 'http://x.org'),
          read: (m) => m.web,
          expected: 'http://x.org',
        ),
      ], fields: fields);
      expectFieldCases<ClubSocialModel>(_social, [
        (
          field: 'email',
          copy: _social.copyWith(clearEmail: true),
          read: (m) => m.email,
          expected: null,
        ),
        (
          field: 'instagram',
          copy: _social.copyWith(clearInstagram: true),
          read: (m) => m.instagram,
          expected: null,
        ),
        (
          field: 'web',
          copy: _social.copyWith(clearWeb: true),
          read: (m) => m.web,
          expected: null,
        ),
      ], fields: fields);
    });
  });

  group('T-09 · ClubAdvisorModel', () {
    test('anahtarları PLAN tanımıyla aynıdır; userId varsayılan null', () {
      expect(
        _advisor.toJson().keys.toSet(),
        ClubGroupPlanTable.embeddedKeys('ClubAdvisorModel'),
      );
      expect(
        ClubAdvisorModel.fromJson(const {'name': 'Elif Kaya', 'title': ''}),
        const ClubAdvisorModel(name: 'Elif Kaya', title: ''),
      );
    });

    test('copyWith her alanı değiştirir; clearUserId hesabı ayırır', () {
      expect(_advisor.copyWith(), _advisor);
      expectFieldCases<ClubAdvisorModel>(
        _advisor,
        [
          (
            field: 'name',
            copy: _advisor.copyWith(name: 'Elif Kaya'),
            read: (m) => m.name,
            expected: 'Elif Kaya',
          ),
          (
            field: 'title',
            copy: _advisor.copyWith(title: 'Prof. Dr.'),
            read: (m) => m.title,
            expected: 'Prof. Dr.',
          ),
          (
            field: 'userId',
            copy: _advisor.copyWith(userId: 'u_elif'),
            read: (m) => m.userId,
            expected: 'u_elif',
          ),
        ],
        fields: ClubGroupPlanTable.embeddedKeys('ClubAdvisorModel'),
      );
      expect(_advisor.copyWith(clearUserId: true).userId, isNull);
    });
  });
}
