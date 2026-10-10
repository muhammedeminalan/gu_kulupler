// T-11 · AppRedirect.resolve — yönlendirme tablosu R1–R14 (PLAN §13.4;
// navigation.md §3; architecture §6). Her satır saf `test()`; tablo burada
// açıkça yazılıdır. Değerlendirme sırası: R1 → R14 → R12 → R2–R7 → R8–R11 →
// R13.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/env/app_environment.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/navigation/app_redirect.dart';

import '../../fakes/fake_session_states.dart';

/// Tablonun bir hücresi: `session` durumunda `location` yoluna girilirse
/// beklenen sonuç (`null` = yönlendirme yok).
typedef _Row = ({
  String label,
  SessionState session,
  String location,
  AppRedirectResult? expected,
});

AppRedirectResult _to(String location, [ToastId? toast]) =>
    AppRedirectResult(location: location, toast: toast);

void _expectRows(List<_Row> rows) {
  for (final row in rows) {
    expect(
      AppRedirect.resolve(row.session, Uri.parse(row.location)),
      row.expected,
      reason: '${row.label}: ${row.session.status.name} @ ${row.location}',
    );
  }
}

/// Oturum guard'ına tabi kabuksuz yollar (R7 `authLocations`).
const _authLocations = [
  '/splash',
  '/onboarding',
  '/login',
  '/login/register',
  '/login/reset',
  '/verify',
  '/setup-profile',
];

void main() {
  final member = FakeSessionStates.activeMember('c01');
  final manager = FakeSessionStates.activeManager('c01');
  final president = FakeSessionStates.activeManager(
    'c01',
    role: ClubRole.president,
  );
  final advisor = FakeSessionStates.activeAdvisor('c01');
  final pending = FakeSessionStates.activePending('c01');
  final rejected = FakeSessionStates.activeRejected('c01');
  const visitor = FakeSessionStates.active;
  const superAdmin = FakeSessionStates.activeSuper;

  group('T-11 · AppRedirect · yönlendirme tablosu', () {
    test('R1 — oturum çözülmedi: her uygulama yolu → /splash', () {
      _expectRows([
        for (final location in [
          '/clubs/c01',
          '/clubs',
          '/admin',
          '/login',
          '/onboarding',
          '/verify',
          '/setup-profile',
          '/bilinmeyen',
        ])
          (
            label: 'R1',
            session: FakeSessionStates.unknown,
            location: location,
            expected: _to('/splash'),
          ),
        (
          label: 'R1 (zaten /splash)',
          session: FakeSessionStates.unknown,
          location: '/splash',
          expected: null,
        ),
      ]);
    });

    test('R2 — oturum yok, ilk açılış: her yol → /onboarding', () {
      _expectRows([
        for (final location in [
          '/clubs',
          '/login',
          '/login/register',
          '/splash',
          '/events/e01',
        ])
          (
            label: 'R2',
            session: FakeSessionStates.signedOutFirstRun,
            location: location,
            expected: _to('/onboarding'),
          ),
        (
          label: 'R2 (zaten /onboarding)',
          session: FakeSessionStates.signedOutFirstRun,
          location: '/onboarding',
          expected: null,
        ),
      ]);
    });

    test('R3 — oturum yok: uygulama rotası → /login?from=<yol>', () {
      _expectRows([
        (
          label: 'R3',
          session: FakeSessionStates.signedOut,
          location: '/clubs/c01/members',
          expected: _to('/login?from=%2Fclubs%2Fc01%2Fmembers'),
        ),
        (
          label: 'R3 (sorgu korunur)',
          session: FakeSessionStates.signedOut,
          location: '/clubs/c01?tab=posts',
          expected: _to('/login?from=%2Fclubs%2Fc01%3Ftab%3Dposts'),
        ),
        (
          label: 'R3 (admin yolu da dönüş adresi olur; R8 girişten sonra)',
          session: FakeSessionStates.signedOut,
          location: '/admin',
          expected: _to('/login?from=%2Fadmin'),
        ),
        // `from` yalnızca uygulama rotası için.
        for (final location in [
          '/splash',
          '/onboarding',
          '/verify',
          '/setup-profile',
          '/bilinmeyen',
        ])
          (
            label: 'R3 (from yok)',
            session: FakeSessionStates.signedOut,
            location: location,
            expected: _to('/login'),
          ),
        // Misafir rotaları serbest.
        for (final location in [
          '/login',
          '/login?from=%2Fclubs',
          '/login/register',
          '/login/reset',
        ])
          (
            label: 'R3 (misafir rotası)',
            session: FakeSessionStates.signedOut,
            location: location,
            expected: null,
          ),
      ]);
    });

    test('R4 — e-posta doğrulanmamış: her yol → /verify', () {
      _expectRows([
        for (final location in [
          '/clubs',
          '/login',
          '/setup-profile',
          '/splash',
          '/admin',
        ])
          (
            label: 'R4',
            session: FakeSessionStates.unverified,
            location: location,
            expected: _to('/verify'),
          ),
        for (final location in ['/verify', '/legal/kvkk'])
          (
            label: 'R4 (serbest)',
            session: FakeSessionStates.unverified,
            location: location,
            expected: null,
          ),
      ]);
    });

    test('R5 — profil eksik: her yol → /setup-profile', () {
      _expectRows([
        for (final location in ['/clubs', '/verify', '/login', '/splash'])
          (
            label: 'R5',
            session: FakeSessionStates.profileIncomplete,
            location: location,
            expected: _to('/setup-profile'),
          ),
        for (final location in ['/setup-profile', '/legal/gizlilik'])
          (
            label: 'R5 (serbest)',
            session: FakeSessionStates.profileIncomplete,
            location: location,
            expected: null,
          ),
      ]);
    });

    test('R6 — askıda: her yol → /login (yan etki oturum katmanında)', () {
      _expectRows([
        for (final location in [
          '/clubs',
          '/clubs/c01/manage',
          '/verify',
          '/splash',
          '/login/register',
        ])
          (
            label: 'R6',
            session: FakeSessionStates.suspended,
            location: location,
            expected: _to('/login'),
          ),
        (
          label: 'R6 (zaten /login)',
          session: FakeSessionStates.suspended,
          location: '/login',
          expected: null,
        ),
      ]);
    });

    test('R7 — aktif oturum oturum-öncesi yolda: from varsa o, yoksa '
        '/clubs', () {
      _expectRows([
        for (final location in _authLocations)
          (
            label: 'R7',
            session: visitor,
            location: location,
            expected: _to('/clubs'),
          ),
        (
          label: 'R7 (from)',
          session: visitor,
          location: '/login?from=%2Fclubs%2Fc01%2Fmembers',
          expected: _to('/clubs/c01/members'),
        ),
        (
          label: 'R7 (from sorgusuyla)',
          session: visitor,
          location: '/login?from=%2Fevents%2Fe01%3FshowCancelled%3Dtrue',
          expected: _to('/events/e01?showCancelled=true'),
        ),
      ]);
    });

    test('R7 — geçersiz from yok sayılır → /clubs', () {
      _expectRows([
        for (final from in [
          'http://example.com',
          'https://example.com/clubs',
          '//example.com/clubs',
          '/login',
          '/splash',
          '/verify',
          '/debug',
          'clubs',
          '',
        ])
          (
            label: 'R7 (from=$from)',
            session: visitor,
            location: '/login?from=${Uri.encodeQueryComponent(from)}',
            expected: _to('/clubs'),
          ),
      ]);
    });

    test('R8 — süper admin değil: /admin/** → /clubs + TST-X18', () {
      _expectRows([
        for (final session in [visitor, member, manager, president, advisor])
          for (final location in [
            '/admin',
            '/admin/users/u01',
            '/admin/clubs/new',
            '/admin/bilinmeyen',
          ])
            (
              label: 'R8',
              session: session,
              location: location,
              expected: _to('/clubs', ToastId.tstX18),
            ),
      ]);
    });

    test('R9 — yönetici / danışman değil: /clubs/:id/manage/** → /clubs/:id '
        '+ TST-X18', () {
      _expectRows([
        for (final session in [visitor, member, pending, rejected])
          for (final location in [
            '/clubs/c01/manage',
            '/clubs/c01/manage/members',
            '/clubs/c01/manage/events/new',
            '/clubs/c01/manage/events/e01/attendance/scan',
            '/clubs/c01/manage/bilinmeyen',
          ])
            (
              label: 'R9',
              session: session,
              location: location,
              expected: _to('/clubs/c01', ToastId.tstX18),
            ),
        // Başka kulübün yöneticisi bu kulübün yönetimine giremez.
        (
          label: 'R9 (başka kulüp)',
          session: manager,
          location: '/clubs/c02/manage',
          expected: _to('/clubs/c02', ToastId.tstX18),
        ),
        // Yazma ekranı yönetimin dışında da olsa (gönderi) aynı karar.
        (
          label: 'R9 (compose, üye)',
          session: member,
          location: '/clubs/c01/compose',
          expected: _to('/clubs/c01', ToastId.tstX18),
        ),
      ]);
    });

    test('R10 — üye değil: /clubs/:id/members ve gönderi → /clubs/:id '
        '(toast yok)', () {
      _expectRows([
        for (final session in [visitor, pending, rejected])
          for (final location in [
            '/clubs/c01/members',
            '/clubs/c01/posts/p01',
          ])
            (
              label: 'R10',
              session: session,
              location: location,
              expected: _to('/clubs/c01'),
            ),
        (
          label: 'R10 (başka kulübün üyesi)',
          session: member,
          location: '/clubs/c02/members',
          expected: _to('/clubs/c02'),
        ),
      ]);
    });

    test('R11 — danışman yazma ekranında: → /clubs/:id/manage + TST-26', () {
      _expectRows([
        for (final location in [
          '/clubs/c01/compose',
          '/clubs/c01/manage/events/new',
          '/clubs/c01/manage/events/e01/edit',
          '/clubs/c01/manage/events/e01/attendance/scan',
        ])
          (
            label: 'R11',
            session: advisor,
            location: location,
            expected: _to('/clubs/c01/manage', ToastId.tst26),
          ),
      ]);
    });

    test('R11 — kulüpte rolü olmayan süper admin yönetimi görür ama '
        'yazamaz (danışman metni gösterilmez)', () {
      _expectRows([
        (
          label: 'R11 (süper admin)',
          session: superAdmin,
          location: '/clubs/c01/compose',
          expected: _to('/clubs/c01/manage', ToastId.tstX18),
        ),
        (
          label: 'R13 (süper admin + yönetici rolü)',
          session: FakeSessionStates.withMembership(
            'c01',
            role: ClubRole.board,
            isSuperAdmin: true,
          ),
          location: '/clubs/c01/compose',
          expected: null,
        ),
      ]);
    });

    test('R12 — geçersiz /legal/:tip her durumda → /not-found (K-06)', () {
      final sessions = [
        FakeSessionStates.unknown,
        FakeSessionStates.signedOutFirstRun,
        FakeSessionStates.signedOut,
        FakeSessionStates.unverified,
        FakeSessionStates.profileIncomplete,
        FakeSessionStates.suspended,
        visitor,
        superAdmin,
      ];
      _expectRows([
        for (final session in sessions) ...[
          for (final location in ['/legal/terms', '/legal/KVKK', '/legal/x'])
            (
              label: 'R12',
              session: session,
              location: location,
              expected: _to('/not-found'),
            ),
          for (final location in [
            '/legal/kosullar',
            '/legal/gizlilik',
            '/legal/kvkk',
          ])
            (
              label: 'R12 (geçerli tip serbest)',
              session: session,
              location: location,
              expected: null,
            ),
        ],
      ]);
    });

    test('R13 — aktif oturum, izinli yol: yönlendirme yok', () {
      _expectRows([
        for (final location in [
          '/clubs',
          '/clubs/c01',
          '/clubs/search',
          '/clubs/user/u01',
          '/events/e01',
          '/events/mine',
          '/notifications',
          '/profile/settings/about',
          '/bilinmeyen',
        ])
          (
            label: 'R13',
            session: visitor,
            location: location,
            expected: null,
          ),
        for (final location in [
          '/admin',
          '/admin/users/u01',
          '/clubs/c01/manage',
          '/clubs/c01/members',
        ])
          (
            label: 'R13 (süper admin)',
            session: superAdmin,
            location: location,
            expected: null,
          ),
        for (final session in [manager, president])
          for (final location in [
            '/clubs/c01/manage',
            '/clubs/c01/manage/members',
            '/clubs/c01/manage/events/new',
            '/clubs/c01/manage/events/e01/edit',
            '/clubs/c01/manage/events/e01/attendance/scan',
            '/clubs/c01/compose',
            '/clubs/c01/members',
            '/clubs/c01/posts/p01',
          ])
            (
              label: 'R13 (yönetici)',
              session: session,
              location: location,
              expected: null,
            ),
        for (final location in [
          '/clubs/c01/manage',
          '/clubs/c01/manage/applications',
          '/clubs/c01/manage/events/e01/attendance',
          '/clubs/c01/members',
        ])
          (
            label: 'R13 (danışman, salt okunur)',
            session: advisor,
            location: location,
            expected: null,
          ),
        for (final location in [
          '/clubs/c01/members',
          '/clubs/c01/posts/p01',
          '/clubs/c01/applied',
        ])
          (
            label: 'R13 (üye)',
            session: member,
            location: location,
            expected: null,
          ),
      ]);
    });

    test('R14 — /debug: bayrak kapalıyken her durumda → /not-found', () {
      // Olağan test koşusunda `ENV` tanımsızdır: bayrak derleme sabiti
      // olarak kapalıdır (CD-69).
      expect(AppEnvironment.debugMenuEnabled, isFalse);
      _expectRows([
        for (final session in [
          FakeSessionStates.unknown,
          FakeSessionStates.signedOutFirstRun,
          FakeSessionStates.signedOut,
          FakeSessionStates.unverified,
          FakeSessionStates.suspended,
          visitor,
          superAdmin,
        ])
          (
            label: 'R14',
            session: session,
            location: '/debug',
            expected: _to('/not-found'),
          ),
      ]);
    });

    test('R14 — /debug: bayrak açıkken oturumsuz dahil her durumda '
        'serbest', () {
      for (final session in [
        FakeSessionStates.unknown,
        FakeSessionStates.signedOutFirstRun,
        FakeSessionStates.signedOut,
        FakeSessionStates.unverified,
        FakeSessionStates.profileIncomplete,
        FakeSessionStates.suspended,
        visitor,
      ]) {
        expect(
          AppRedirect.resolve(
            session,
            Uri.parse('/debug'),
            debugMenuEnabled: true,
          ),
          isNull,
          reason: session.status.name,
        );
      }
    });
  });

  group('T-11 · AppRedirect · sıra ve muafiyetler', () {
    test('R14 ve R12, R2–R7’den önce değerlendirilir', () {
      _expectRows([
        // R2 /onboarding ya da R3 /login değil: önce R14 / R12.
        (
          label: 'R14 < R2',
          session: FakeSessionStates.signedOutFirstRun,
          location: '/debug',
          expected: _to('/not-found'),
        ),
        (
          label: 'R12 < R2',
          session: FakeSessionStates.signedOutFirstRun,
          location: '/legal/terms',
          expected: _to('/not-found'),
        ),
        (
          label: 'R12 < R3',
          session: FakeSessionStates.signedOut,
          location: '/legal/terms',
          expected: _to('/not-found'),
        ),
        (
          label: 'R12 < R4',
          session: FakeSessionStates.unverified,
          location: '/legal/terms',
          expected: _to('/not-found'),
        ),
        (
          label: 'R12 < R6',
          session: FakeSessionStates.suspended,
          location: '/legal/terms',
          expected: _to('/not-found'),
        ),
      ]);
    });

    test('R1–R7, R8–R11’den önce: aktif olmayan oturumda rol kararı '
        'verilmez (toast yok)', () {
      _expectRows([
        (
          label: 'R3 < R8',
          session: FakeSessionStates.signedOut,
          location: '/admin/users',
          expected: _to('/login?from=%2Fadmin%2Fusers'),
        ),
        (
          label: 'R4 < R9',
          session: FakeSessionStates.unverified,
          location: '/clubs/c01/manage',
          expected: _to('/verify'),
        ),
        (
          label: 'R1 < R8',
          session: FakeSessionStates.unknown,
          location: '/admin',
          expected: _to('/splash'),
        ),
      ]);
    });

    test('R9, R11’den önce: yönetimi göremeyen yazma ekranında R9 alır', () {
      _expectRows([
        (
          label: 'R9 < R11',
          session: member,
          location: '/clubs/c01/manage/events/new',
          expected: _to('/clubs/c01', ToastId.tstX18),
        ),
      ]);
    });

    test('kabuksuz sistem ekranları oturum guard’ından muaftır', () {
      // SYS-02 oturum çözülemediğinde, SYS-04 R12 hedefi olarak oturumsuzken
      // de gösterilebilmelidir.
      for (final status in AuthStatus.values) {
        for (final location in [
          '/error',
          '/error?from=%2Fclubs',
          '/offline',
          '/not-found',
        ]) {
          expect(
            AppRedirect.resolve(
              SessionState(status: status, onboardingSeen: true),
              Uri.parse(location),
            ),
            isNull,
            reason: '${status.name} @ $location',
          );
        }
      }
    });

    test('R12 hedefi kararlıdır: /not-found yeniden yönlendirilmez', () {
      for (final session in [
        FakeSessionStates.unknown,
        FakeSessionStates.signedOutFirstRun,
        FakeSessionStates.signedOut,
      ]) {
        final first = AppRedirect.resolve(session, Uri.parse('/legal/terms'));
        expect(first, _to('/not-found'));
        expect(
          AppRedirect.resolve(session, Uri.parse(first!.location)),
          isNull,
        );
      }
    });

    test('her yönlendirme hedefi en çok iki adımda durur (döngü yok)', () {
      final sessions = [
        FakeSessionStates.unknown,
        FakeSessionStates.signedOutFirstRun,
        FakeSessionStates.signedOut,
        FakeSessionStates.unverified,
        FakeSessionStates.profileIncomplete,
        FakeSessionStates.suspended,
        visitor,
        member,
        manager,
        advisor,
        pending,
        superAdmin,
      ];
      const locations = [
        '/splash',
        '/onboarding',
        '/login',
        '/login/register',
        '/verify',
        '/setup-profile',
        '/legal/terms',
        '/debug',
        '/clubs',
        '/clubs/c01/members',
        '/clubs/c01/compose',
        '/clubs/c01/manage/events/new',
        '/admin/users',
        '/login?from=%2Fadmin',
        '/login?from=%2Fclubs%2Fc01%2Fcompose',
        '/bilinmeyen',
      ];
      for (final session in sessions) {
        for (final start in locations) {
          var location = start;
          var hops = 0;
          while (true) {
            final next = AppRedirect.resolve(session, Uri.parse(location));
            if (next == null) break;
            location = next.location;
            hops++;
            expect(
              hops,
              lessThanOrEqualTo(3),
              reason: '${session.status.name} @ $start döngüye girdi',
            );
          }
        }
      }
    });
  });

  group('T-11 · AppRedirectResult', () {
    test('eşitlik yol ve toast üzerindendir', () {
      expect(_to('/clubs'), _to('/clubs'));
      expect(_to('/clubs'), isNot(_to('/login')));
      expect(_to('/clubs', ToastId.tstX18), isNot(_to('/clubs')));
      expect(_to('/clubs', ToastId.tstX18).props, ['/clubs', ToastId.tstX18]);
    });
  });
}
