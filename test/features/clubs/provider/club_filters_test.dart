// T-17 · ClubFilters (CD-108): SHT-04 süzgeci ve sıralaması — prototip
// `GU.clubFilters` (`screens-clubs.js:5–16`).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/clubs/provider/club_filters.dart';

import '../../../fixtures/club_model_fixtures.dart';

ClubModel _club(
  String id, {
  String categoryId = 'k01',
  int memberCount = 10,
  bool approvalRequired = true,
  bool applicationsOpen = true,
  ClubStatus status = ClubStatus.active,
  DateTime? createdAt,
}) => ClubModelFixtures.c01.copyWith(
  id: id,
  nameLower: id,
  categoryId: categoryId,
  memberCount: memberCount,
  approvalRequired: approvalRequired,
  applicationsOpen: applicationsOpen,
  status: status,
  createdAt: createdAt ?? DateTime.utc(2026),
);

List<String> _ids(Iterable<ClubModel> clubs) => [
  for (final club in clubs) club.id,
];

void main() {
  group('T-17 · ClubFilters', () {
    final clubs = [
      _club('a', memberCount: 5, createdAt: DateTime.utc(2026, 3)),
      _club('b', categoryId: 'k02', memberCount: 30, applicationsOpen: false),
      _club('c', memberCount: 30, approvalRequired: false),
      _club('d', status: ClubStatus.suspended, memberCount: 99),
    ];

    test('varsayılan: süzme yok, askıdaki kulüp girmez, "Popüler" sıralar; '
        'eşitlikte girdi sırası korunur', () {
      expect(ClubFilters.none.props, [
        <String>{},
        ClubMembershipFilter.all,
        false,
        false,
        ClubSort.popular,
      ]);
      expect(ClubFilters.none.activeCount, 0);
      expect(ClubFilters.none.singleCategoryId, isNull);
      expect(_ids(ClubFilters.none.apply(clubs)), ['b', 'c', 'a']);
    });

    test('kategori, üyelik, başvurusu açık ve anında katılım süzer', () {
      expect(
        _ids(const ClubFilters(categoryIds: {'k02'}).apply(clubs)),
        ['b'],
      );
      expect(
        _ids(
          const ClubFilters(
            membership: ClubMembershipFilter.mine,
          ).apply(clubs, memberClubIds: {'a', 'd'}),
        ),
        ['a'],
      );
      expect(
        _ids(
          const ClubFilters(
            membership: ClubMembershipFilter.notMine,
          ).apply(clubs, memberClubIds: {'a'}),
        ),
        ['b', 'c'],
      );
      expect(
        _ids(const ClubFilters(applicationsOpenOnly: true).apply(clubs)),
        ['c', 'a'],
      );
      expect(_ids(const ClubFilters(instantOnly: true).apply(clubs)), ['c']);
    });

    test('sıralama: yeni eklenen (yeniden eskiye) ve A–Z (`nameLower`)', () {
      expect(
        _ids(const ClubFilters(sort: ClubSort.newest).apply(clubs)),
        ['a', 'b', 'c'],
      );
      expect(
        _ids(const ClubFilters(sort: ClubSort.az).apply(clubs.reversed)),
        ['a', 'b', 'c'],
      );
    });

    test('activeCount: kategori kaç tane olursa olsun 1; varsayılan dışı '
        'her alan 1', () {
      const filters = ClubFilters(
        categoryIds: {'k01', 'k02'},
        membership: ClubMembershipFilter.mine,
        applicationsOpenOnly: true,
        instantOnly: true,
        sort: ClubSort.az,
      );
      expect(filters.activeCount, 5);
      expect(filters.singleCategoryId, isNull);
      expect(const ClubFilters(categoryIds: {'k03'}).singleCategoryId, 'k03');
    });

    test('copyWith ve props tüm alanları taşır', () {
      const base = ClubFilters.none;
      final changed = [
        base.copyWith(categoryIds: {'k01'}),
        base.copyWith(membership: ClubMembershipFilter.notMine),
        base.copyWith(applicationsOpenOnly: true),
        base.copyWith(instantOnly: true),
        base.copyWith(sort: ClubSort.newest),
      ];
      for (final filters in changed) {
        expect(filters, isNot(base));
        expect(filters.copyWith(), filters);
      }
      expect(base.copyWith(), base);
      expect(base.props, hasLength(5));
    });
  });
}
