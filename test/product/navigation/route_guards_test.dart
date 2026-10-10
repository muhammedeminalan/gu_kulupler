// T-11 · Guard'lar tek tek: AuthGuard (R1–R7), RoleGuard (R8–R11),
// RouteParamGuard (R12), DebugRouteGuard (R14) — PLAN §13.1, §13.4. Tablonun
// bütünü `app_redirect_test.dart`'tadır; burada her guard'ın yalnızca kendi
// satırlarına baktığı ve yardımcıları doğrulanır.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/navigation/route_guards.dart';

import '../../fakes/fake_session_states.dart';

GuardRedirect _to(String location, [ToastId? toast]) =>
    (location: location, toast: toast);

void main() {
  group('T-11 · AuthGuard', () {
    test('rol kararı vermez: aktif oturumda yetkisiz yol serbest kalır', () {
      for (final location in [
        '/admin',
        '/clubs/c01/manage',
        '/clubs/c01/members',
        '/clubs/c01/compose',
      ]) {
        expect(
          AuthGuard.check(FakeSessionStates.active, Uri.parse(location)),
          isNull,
          reason: location,
        );
      }
    });

    test('oturum guard’ından muaf yollara dokunmaz', () {
      for (final location in [
        '/debug',
        '/legal/terms',
        '/legal/kvkk',
        '/error',
        '/offline',
        '/not-found',
      ]) {
        expect(
          AuthGuard.check(FakeSessionStates.unknown, Uri.parse(location)),
          isNull,
          reason: location,
        );
      }
    });

    test('hiçbir satırı toast taşımaz', () {
      for (final session in [
        FakeSessionStates.unknown,
        FakeSessionStates.signedOutFirstRun,
        FakeSessionStates.signedOut,
        FakeSessionStates.unverified,
        FakeSessionStates.profileIncomplete,
        FakeSessionStates.suspended,
      ]) {
        final redirect = AuthGuard.check(session, Uri.parse('/clubs/c01'));
        expect(redirect, isNotNull, reason: session.status.name);
        expect(redirect!.toast, isNull, reason: session.status.name);
      }
    });

    test('loginLocation: yalnızca uygulama rotası dönüş adresi olur', () {
      String of(String location) =>
          AuthGuard.loginLocation(from: Uri.parse(location));
      expect(of('/clubs'), '/login?from=%2Fclubs');
      expect(
        of('/profile/settings/about'),
        '/login?from=%2Fprofile%2Fsettings%2Fabout',
      );
      expect(
        of('/events/e01?showCancelled=true'),
        '/login?from=%2Fevents%2Fe01%3FshowCancelled%3Dtrue',
      );
      expect(of('/splash'), '/login');
      expect(of('/verify'), '/login');
      expect(of('/bilinmeyen'), '/login');
      // Şema ve alan adı dönüş adresine girmez.
      expect(
        of('https://gukulupler.app/clubs/c01'),
        '/login?from=%2Fclubs%2Fc01',
      );
    });

    test('returnLocation: from yalnızca uygulama yoluysa geçerlidir', () {
      String? of(String from) => AuthGuard.returnLocation(
        Uri(path: '/login', queryParameters: {'from': from}),
      );
      expect(of('/clubs/c01'), '/clubs/c01');
      expect(of('/admin/users'), '/admin/users');
      expect(
        of('/events/e01?showCancelled=true'),
        '/events/e01?showCancelled=true',
      );
      expect(of('http://example.com'), isNull);
      expect(of('//example.com/clubs'), isNull);
      expect(of('/login'), isNull);
      expect(of('/not-found'), isNull);
      expect(of('clubs'), isNull);
      expect(of(''), isNull);
      expect(AuthGuard.returnLocation(Uri.parse('/login')), isNull);
    });

    test('loginLocation ↔ returnLocation gidiş-dönüş', () {
      for (final location in [
        '/clubs',
        '/clubs/c01/posts/p01',
        '/clubs/c01?tab=posts',
        '/profile/clubs?tab=pending',
      ]) {
        final login = AuthGuard.loginLocation(from: Uri.parse(location));
        expect(
          AuthGuard.returnLocation(Uri.parse(login)),
          location,
          reason: location,
        );
      }
    });
  });

  group('T-11 · RoleGuard', () {
    test('aktif olmayan oturumda karar vermez', () {
      for (final session in [
        FakeSessionStates.unknown,
        FakeSessionStates.signedOut,
        FakeSessionStates.unverified,
        FakeSessionStates.profileIncomplete,
        FakeSessionStates.suspended,
      ]) {
        for (final location in ['/admin', '/clubs/c01/manage']) {
          expect(
            RoleGuard.check(session, Uri.parse(location)),
            isNull,
            reason: '${session.status.name} @ $location',
          );
        }
      }
    });

    test('rol istemeyen yollara dokunmaz', () {
      for (final location in [
        '/clubs',
        '/clubs/c01',
        '/clubs/c01/applied',
        '/events/e01',
        '/profile',
        '/login',
        '/not-found',
        '/debug',
      ]) {
        expect(
          RoleGuard.check(FakeSessionStates.active, Uri.parse(location)),
          isNull,
          reason: location,
        );
      }
    });

    test('R8: süper admin girer, diğerleri /clubs + TST-X18', () {
      final location = Uri.parse('/admin/reports');
      expect(RoleGuard.check(FakeSessionStates.activeSuper, location), isNull);
      expect(
        RoleGuard.check(FakeSessionStates.activeManager('c01'), location),
        _to('/clubs', ToastId.tstX18),
      );
    });

    test('R9: yönetimi görenler (yönetici, başkan, danışman, süper admin)', () {
      final location = Uri.parse('/clubs/c01/manage/settings');
      for (final session in [
        FakeSessionStates.activeManager('c01'),
        FakeSessionStates.activeManager('c01', role: ClubRole.president),
        FakeSessionStates.activeAdvisor('c01'),
        FakeSessionStates.activeSuper,
      ]) {
        expect(RoleGuard.check(session, location), isNull);
      }
      for (final session in [
        FakeSessionStates.active,
        FakeSessionStates.activeMember('c01'),
        FakeSessionStates.activePending('c01'),
      ]) {
        expect(
          RoleGuard.check(session, location),
          _to('/clubs/c01', ToastId.tstX18),
        );
      }
    });

    test(
      'R10: kulüp içini görenler (üye, yönetici, danışman, süper admin)',
      () {
        final location = Uri.parse('/clubs/c01/posts/p01');
        for (final session in [
          FakeSessionStates.activeMember('c01'),
          FakeSessionStates.activeManager('c01'),
          FakeSessionStates.activeAdvisor('c01'),
          FakeSessionStates.activeSuper,
        ]) {
          expect(RoleGuard.check(session, location), isNull);
        }
        // Başvuru belgesindeki `role: member` üyelik sayılmaz (CD-129).
        for (final session in [
          FakeSessionStates.active,
          FakeSessionStates.activePending('c01'),
          FakeSessionStates.activeRejected('c01'),
          FakeSessionStates.withMembership(
            'c01',
            status: MembershipStatus.removed,
          ),
        ]) {
          expect(RoleGuard.check(session, location), _to('/clubs/c01'));
        }
      },
    );

    test('R11: yazma ekranı yalnızca yöneticiye açıktır', () {
      final location = Uri.parse('/clubs/c01/manage/events/e01/edit');
      expect(
        RoleGuard.check(FakeSessionStates.activeManager('c01'), location),
        isNull,
      );
      expect(
        RoleGuard.check(FakeSessionStates.activeAdvisor('c01'), location),
        _to('/clubs/c01/manage', ToastId.tst26),
      );
      expect(
        RoleGuard.check(FakeSessionStates.activeSuper, location),
        _to('/clubs/c01/manage', ToastId.tstX18),
      );
      expect(
        RoleGuard.check(FakeSessionStates.activeMember('c01'), location),
        _to('/clubs/c01', ToastId.tstX18),
      );
    });
  });

  group('T-11 · RouteParamGuard (R12)', () {
    test('geçerli üç sekme', () {
      expect(RouteParamGuard.legalTabs, {'kosullar', 'gizlilik', 'kvkk'});
      for (final tab in RouteParamGuard.legalTabs) {
        expect(RouteParamGuard.check(Uri.parse('/legal/$tab')), isNull);
      }
    });

    test('geçersiz tip → /not-found', () {
      for (final tab in ['terms', 'privacy', 'KVKK', 'kvkk2']) {
        expect(
          RouteParamGuard.check(Uri.parse('/legal/$tab')),
          _to('/not-found'),
          reason: tab,
        );
      }
    });

    test('yalnızca /legal/:tip yoluna bakar', () {
      for (final location in ['/clubs/terms', '/legal', '/legal/a/b', '/x']) {
        expect(
          RouteParamGuard.check(Uri.parse(location)),
          isNull,
          reason: location,
        );
      }
    });
  });

  group('T-11 · DebugRouteGuard (R14)', () {
    test('bayrak kapalı → /not-found; açık → serbest', () {
      final debug = Uri.parse('/debug');
      // Varsayılan derleme sabitidir; test koşusunda kapalıdır (CD-69).
      expect(DebugRouteGuard.check(debug), _to('/not-found'));
      expect(DebugRouteGuard.check(debug, enabled: true), isNull);
    });

    test('yalnızca /debug yoluna bakar', () {
      for (final location in ['/clubs', '/debug/x', '/not-found']) {
        expect(
          DebugRouteGuard.check(Uri.parse(location)),
          isNull,
          reason: location,
        );
        expect(
          DebugRouteGuard.check(Uri.parse(location), enabled: true),
          isNull,
          reason: location,
        );
      }
    });
  });
}
