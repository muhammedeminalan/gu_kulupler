// CLB-03 · ClubDetailState: varsayılanlar, `props` / `copyWith` tüm alanlar,
// türetimler (`seesInside`, `canManage`, `activeRole`, `retryAfterAt`)
// (PLAN §12.6, §12.16).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/clubs/provider/club_detail_state.dart';
import 'package:gu_kulupler/product/navigation/club_detail_tab.dart';

import '../../../fixtures/event_model_fixtures.dart';
import '../../../fixtures/rsvp_model_fixtures.dart';
import '../club_detail_test_support.dart';

void main() {
  final now = DateTime.utc(2026, 10, 12, 16, 30);
  final membership = sessionWith().memberships[kClubId]!;
  final event = EventModelFixtures.e01;
  final rsvp = RsvpModelFixtures.e01Mehmet;
  final full = ClubDetailState(
    club: kClub,
    access: ClubAccess.manager,
    membership: membership,
    tab: ClubDetailTab.events,
    events: [event],
    rsvps: {event.id: rsvp},
    isEventsFetching: true,
    isEventsError: true,
    managers: kManagers,
    memberPreview: [kPresident],
    isFetching: true,
    isRefreshing: true,
    isError: true,
    isNotFound: true,
    isActing: true,
  );

  group('CLB-03 · ClubDetailState', () {
    test('varsayılan: kulüp yok, ziyaretçi, hakkında sekmesi, bayraklar '
        'kapalı', () {
      const state = ClubDetailState();
      expect(state.club, isNull);
      expect(state.access, ClubAccess.visitor);
      expect(state.membership, isNull);
      expect(state.tab, ClubDetailTab.about);
      expect(state.events, isEmpty);
      expect(state.rsvps, isEmpty);
      expect(state.isEventsFetching, isFalse);
      expect(state.isEventsError, isFalse);
      expect(state.managers, isEmpty);
      expect(state.memberPreview, isEmpty);
      expect(state.isFetching, isFalse);
      expect(state.isRefreshing, isFalse);
      expect(state.isError, isFalse);
      expect(state.isNotFound, isFalse);
      expect(state.isActing, isFalse);
    });

    test('props tüm alanları içerir (15 alan)', () {
      expect(full.props, [
        kClub,
        ClubAccess.manager,
        membership,
        ClubDetailTab.events,
        [event],
        {event.id: rsvp},
        true,
        true,
        kManagers,
        [kPresident],
        true,
        true,
        true,
        true,
        true,
      ]);
      expect(const ClubDetailState(), const ClubDetailState());
    });

    test('copyWith: her alan tek başına değişir, diğerleri korunur', () {
      const base = ClubDetailState();
      final variants = <ClubDetailState>[
        base.copyWith(club: kClub),
        base.copyWith(access: ClubAccess.member),
        base.copyWith(membership: membership),
        base.copyWith(tab: ClubDetailTab.posts),
        base.copyWith(events: [event]),
        base.copyWith(rsvps: {event.id: rsvp}),
        base.copyWith(isEventsFetching: true),
        base.copyWith(isEventsError: true),
        base.copyWith(managers: kManagers),
        base.copyWith(memberPreview: [kPresident]),
        base.copyWith(isFetching: true),
        base.copyWith(isRefreshing: true),
        base.copyWith(isError: true),
        base.copyWith(isNotFound: true),
        base.copyWith(isActing: true),
      ];
      expect(variants[0].club, kClub);
      expect(variants[1].access, ClubAccess.member);
      expect(variants[2].membership, membership);
      expect(variants[3].tab, ClubDetailTab.posts);
      expect(variants[4].events, [event]);
      expect(variants[5].rsvps, {event.id: rsvp});
      expect(variants[6].isEventsFetching, isTrue);
      expect(variants[7].isEventsError, isTrue);
      expect(variants[8].managers, kManagers);
      expect(variants[9].memberPreview, [kPresident]);
      expect(variants[10].isFetching, isTrue);
      expect(variants[11].isRefreshing, isTrue);
      expect(variants[12].isError, isTrue);
      expect(variants[13].isNotFound, isTrue);
      expect(variants[14].isActing, isTrue);
      // Her kopya tabandan ve diğerlerinden farklıdır (tek alan değişti).
      expect({base, ...variants}, hasLength(variants.length + 1));
    });

    test('copyWith: argümansız kopya eşittir; bayraklar ve listeler geri '
        'boşalabilir', () {
      expect(full.copyWith(), full);
      final cleared = full.copyWith(
        events: const [],
        rsvps: const {},
        isEventsFetching: false,
        isEventsError: false,
        managers: const [],
        memberPreview: const [],
        isFetching: false,
        isRefreshing: false,
        isError: false,
        isNotFound: false,
        isActing: false,
      );
      expect(
        cleared,
        ClubDetailState(
          club: kClub,
          access: ClubAccess.manager,
          membership: membership,
          tab: ClubDetailTab.events,
        ),
      );
    });

    test('copyWith: clearMembership üyeliği kaldırır ve verilen değere üstün '
        'gelir', () {
      expect(full.copyWith(clearMembership: true).membership, isNull);
      expect(
        full.copyWith(membership: membership, clearMembership: true).membership,
        isNull,
      );
    });

    test('seesInside: üye, yönetici, danışman ve süper admin kulübün içini '
        'görür; ziyaretçi, bekleyen ve reddedilen görmez', () {
      final inside = {
        for (final access in ClubAccess.values)
          access: ClubDetailState(access: access).seesInside,
      };
      expect(inside, {
        ClubAccess.visitor: false,
        ClubAccess.pending: false,
        ClubAccess.rejected: false,
        ClubAccess.member: true,
        ClubAccess.manager: true,
        ClubAccess.advisor: true,
        ClubAccess.superAdmin: true,
      });
    });

    test('canManage: yalnızca yönetici ve süper admin', () {
      final managing = {
        for (final access in ClubAccess.values)
          if (ClubDetailState(access: access).canManage) access,
      };
      expect(managing, {ClubAccess.manager, ClubAccess.superAdmin});
    });

    test('activeRole: yalnızca aktif üyelik rol taşır', () {
      ClubRole? roleOf(MembershipStatus status, ClubRole role) =>
          ClubDetailState(
            membership: membership.copyWith(status: status, role: role),
          ).activeRole;

      expect(const ClubDetailState().activeRole, isNull);
      expect(roleOf(MembershipStatus.active, ClubRole.board), ClubRole.board);
      expect(
        roleOf(MembershipStatus.active, ClubRole.president),
        ClubRole.president,
      );
      for (final status in MembershipStatus.values) {
        if (status == MembershipStatus.active) continue;
        expect(roleOf(status, ClubRole.board), isNull, reason: status.name);
      }
    });

    test('retryAfterAt: bekleme sürüyorsa bitiş anı; yoksa ya da dolduysa '
        'null', () {
      DateTime? waiting(DateTime? retryAfter) => ClubDetailState(
        membership: membership.copyWith(
          status: MembershipStatus.rejected,
          retryAfter: retryAfter,
        ),
      ).retryAfterAt(now);

      final later = now.add(const Duration(days: 3));
      expect(const ClubDetailState().retryAfterAt(now), isNull);
      expect(waiting(null), isNull);
      expect(waiting(later), later);
      expect(waiting(now), isNull);
      expect(waiting(now.subtract(const Duration(seconds: 1))), isNull);
    });
  });
}
