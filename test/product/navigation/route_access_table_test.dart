// T-11 · RouteAccessTable: 57 yol kalıbı ↔ PLAN §13.3 "Guard" sütunu
// (navigation.md §2). Tablo burada açıkça yazılıdır; satır başına assert.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/navigation/route_guards.dart';

/// PLAN §13.3 — kalıp → guard. Guard kodları: `—` public · `G` guest ·
/// `A` active · `üye` member · `M` manager · `V` managerOrAdvisor ·
/// `S` superAdmin.
const Map<String, RouteAccess> _expected = {
  // §13.3.1 Kabuksuz (12)
  '/splash': RouteAccess.public,
  '/error': RouteAccess.public,
  '/offline': RouteAccess.public,
  '/not-found': RouteAccess.public,
  '/debug': RouteAccess.debugOnly,
  '/onboarding': RouteAccess.guest,
  '/login': RouteAccess.guest,
  '/login/register': RouteAccess.guest,
  '/login/reset': RouteAccess.guest,
  '/verify': RouteAccess.unverified,
  '/setup-profile': RouteAccess.profileIncomplete,
  '/legal/:tip': RouteAccess.public,
  // §13.3.2 Kulüpler (20)
  '/clubs': RouteAccess.active,
  '/clubs/search': RouteAccess.active,
  '/clubs/user/:userId': RouteAccess.active,
  '/clubs/:clubId': RouteAccess.active,
  '/clubs/:clubId/applied': RouteAccess.active,
  '/clubs/:clubId/application': RouteAccess.active,
  '/clubs/:clubId/members': RouteAccess.member,
  '/clubs/:clubId/posts/:postId': RouteAccess.member,
  '/clubs/:clubId/compose': RouteAccess.manager,
  '/clubs/:clubId/manage': RouteAccess.managerOrAdvisor,
  '/clubs/:clubId/manage/applications': RouteAccess.managerOrAdvisor,
  '/clubs/:clubId/manage/members': RouteAccess.managerOrAdvisor,
  '/clubs/:clubId/manage/events': RouteAccess.managerOrAdvisor,
  '/clubs/:clubId/manage/events/new': RouteAccess.manager,
  '/clubs/:clubId/manage/events/:eventId/edit': RouteAccess.manager,
  '/clubs/:clubId/manage/events/:eventId/attendance':
      RouteAccess.managerOrAdvisor,
  '/clubs/:clubId/manage/events/:eventId/attendance/scan': RouteAccess.manager,
  '/clubs/:clubId/manage/content': RouteAccess.managerOrAdvisor,
  '/clubs/:clubId/manage/settings': RouteAccess.managerOrAdvisor,
  '/clubs/:clubId/manage/activity': RouteAccess.managerOrAdvisor,
  // §13.3.3 Etkinlikler (5)
  '/events': RouteAccess.active,
  '/events/:eventId': RouteAccess.active,
  '/events/:eventId/ticket': RouteAccess.active,
  '/events/mine': RouteAccess.active,
  '/events/search': RouteAccess.active,
  // §13.3.4 Bildirimler (2)
  '/notifications': RouteAccess.active,
  '/notifications/preferences': RouteAccess.active,
  // §13.3.5 Profil (11)
  '/profile': RouteAccess.active,
  '/profile/edit': RouteAccess.active,
  '/profile/clubs': RouteAccess.active,
  '/profile/saved': RouteAccess.active,
  '/profile/settings': RouteAccess.active,
  '/profile/settings/notifications': RouteAccess.active,
  '/profile/settings/blocked': RouteAccess.active,
  '/profile/settings/blocked/:userId': RouteAccess.active,
  '/profile/settings/delete': RouteAccess.active,
  '/profile/settings/about': RouteAccess.active,
  '/profile/settings/support': RouteAccess.active,
  // §13.3.6 Admin (7)
  '/admin': RouteAccess.superAdmin,
  '/admin/clubs': RouteAccess.superAdmin,
  '/admin/clubs/new': RouteAccess.superAdmin,
  '/admin/clubs/:clubId/edit': RouteAccess.superAdmin,
  '/admin/reports': RouteAccess.superAdmin,
  '/admin/users': RouteAccess.superAdmin,
  '/admin/users/:userId': RouteAccess.superAdmin,
};

/// Kalıptaki `:ad` parçalarını örnek değerle doldurur.
String _sample(String pattern) => pattern.replaceAllMapped(
  RegExp(':([A-Za-z]+)'),
  (match) => switch (match.group(1)) {
    'clubId' => 'c01',
    'eventId' => 'e01',
    'postId' => 'p01',
    'userId' => 'u01',
    'tip' => 'kvkk',
    final other => throw StateError('bilinmeyen parametre: $other'),
  },
);

void main() {
  group('T-11 · RouteAccessTable', () {
    test('57 kalıp vardır ve PLAN §13.3 ile birebir aynıdır', () {
      expect(_expected, hasLength(57));
      expect(RouteAccessTable.patterns, _expected);
    });

    test('enum on değerdir (PLAN §13.1 sırası)', () {
      expect(RouteAccess.values.map((access) => access.name), [
        'public',
        'guest',
        'unverified',
        'profileIncomplete',
        'active',
        'member',
        'manager',
        'managerOrAdvisor',
        'superAdmin',
        'debugOnly',
      ]);
    });

    for (final MapEntry(key: pattern, value: access) in _expected.entries) {
      test('$pattern → ${access.name}', () {
        final match = RouteAccessTable.match(Uri.parse(_sample(pattern)));
        expect(match.pattern, pattern);
        expect(match.access, access);
        expect(RouteAccessTable.accessOf(Uri.parse(_sample(pattern))), access);
      });
    }

    test('yol parametre adları clubId / eventId / postId / userId / tip', () {
      final names = {
        for (final pattern in RouteAccessTable.patterns.keys)
          for (final match in RegExp(':([A-Za-z]+)').allMatches(pattern))
            match.group(1),
      };
      expect(names, {'clubId', 'eventId', 'postId', 'userId', 'tip'});
    });

    test('sabit parça parametreden önce gelir', () {
      String? patternOf(String location) =>
          RouteAccessTable.match(Uri.parse(location)).pattern;
      expect(patternOf('/clubs/search'), '/clubs/search');
      expect(patternOf('/clubs/c01'), '/clubs/:clubId');
      expect(patternOf('/clubs/user/u01'), '/clubs/user/:userId');
      expect(patternOf('/clubs/c01/applied'), '/clubs/:clubId/applied');
      expect(patternOf('/events/mine'), '/events/mine');
      expect(patternOf('/events/search'), '/events/search');
      expect(patternOf('/events/e01'), '/events/:eventId');
      expect(
        patternOf('/clubs/c01/manage/events/new'),
        '/clubs/:clubId/manage/events/new',
      );
      expect(patternOf('/admin/clubs/new'), '/admin/clubs/new');
      expect(
        patternOf('/admin/clubs/c01/edit'),
        '/admin/clubs/:clubId/edit',
      );
    });

    test('yol parametreleri okunur', () {
      final match = RouteAccessTable.match(
        Uri.parse('/clubs/c07/manage/events/e42/attendance/scan'),
      );
      expect(match.clubId, 'c07');
      expect(match.pathParameters, {'clubId': 'c07', 'eventId': 'e42'});
      expect(RouteAccessTable.match(Uri.parse('/clubs')).clubId, isNull);
      expect(
        RouteAccessTable.match(Uri.parse('/legal/kvkk')).pathParameters,
        {'tip': 'kvkk'},
      );
    });

    test('sorgu ve sondaki `/` eşleşmeyi değiştirmez', () {
      final match = RouteAccessTable.match(Uri.parse('/clubs/c01/?tab=posts'));
      expect(match.pattern, '/clubs/:clubId');
      expect(match.path, '/clubs/c01');
      expect(
        RouteAccessTable.accessOf(Uri.parse('/login?from=%2Fclubs')),
        RouteAccess.guest,
      );
    });

    test('tabloda olmayan yol korumalıdır', () {
      RouteAccessMatch of(String location) =>
          RouteAccessTable.match(Uri.parse(location));
      expect(of('/bilinmeyen').access, RouteAccess.active);
      expect(of('/bilinmeyen').pattern, isNull);
      expect(of('/').access, RouteAccess.active);
      expect(of('/legal').access, RouteAccess.active);
      expect(of('/legal/kvkk/ek').access, RouteAccess.active);
      expect(of('/admin/bilinmeyen').access, RouteAccess.superAdmin);
      expect(of('/admin/a/b/c').access, RouteAccess.superAdmin);
      final manage = of('/clubs/c09/manage/bilinmeyen');
      expect(manage.access, RouteAccess.managerOrAdvisor);
      expect(manage.clubId, 'c09');
      expect(of('/clubs/c09/bilinmeyen').access, RouteAccess.active);
    });
  });
}
