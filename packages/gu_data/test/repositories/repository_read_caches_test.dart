// T-44 · D3-01 · RepositoryReadCaches: yazım yolu eşlemesi (clubs/{id} →
// kulüp + etkin liste, users/{uid} → kullanıcı; alt koleksiyon yok sayılır)
// ve oturum değişiminde (uid değişti / çıkış) tüm önbelleğin temizlenmesi.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/fake_app_clock.dart';

const ClubModel _club = ClubModel(
  id: 'c01',
  name: 'Kulüp',
  nameLower: 'kulüp',
  categoryId: 'k01',
  iconName: 'code-xml',
  palette: ClubPalette.red,
  pattern: ClubPattern.dots,
  founded: 2015,
  presidentId: 'u_pres',
);

const UserModel _user = UserModel(
  uid: 'u1',
  name: 'Ayşe',
  nameLower: 'ayşe',
  avatarSeed: 's',
);

void main() {
  late RepositoryReadCaches caches;

  void fill() {
    final since = caches.clubs.stamp;
    caches.clubs.put('c01', _club, since: since);
    caches.activeClubs.put(
      RepositoryReadCaches.activeClubsKey,
      const [_club],
      since: since,
    );
    caches.users.put('u1', _user, since: since);
  }

  setUp(() {
    caches = RepositoryReadCaches(FakeAppClock(DateTime.utc(2026, 10, 15)));
    addTearDown(caches.dispose);
    fill();
  });

  test('clubs/{id} yazımı kulübü ve etkin listeyi atar; kullanıcıya '
      'dokunmaz', () {
    caches.onWrite('clubs/c01');

    expect(caches.clubs.get('c01'), isNull);
    expect(caches.activeClubs.get(RepositoryReadCaches.activeClubsKey), isNull);
    expect(caches.users.get('u1'), _user);
  });

  test('users/{uid} yazımı yalnızca kullanıcıyı atar; alt koleksiyon ve '
      'başka koleksiyon yolları yok sayılır', () {
    caches
      ..onWrite('users/u1/private/account')
      ..onWrite('clubs/c01/private/counter')
      ..onWrite('posts/p01');
    expect(caches.users.get('u1'), _user);
    expect(caches.clubs.get('c01'), _club);

    caches.onWrite('users/u1');
    expect(caches.users.get('u1'), isNull);
    expect(caches.clubs.get('c01'), _club);
  });

  test('oturum: uid değişince ve çıkışta tüm önbellek temizlenir; aynı uid '
      'temizlemez', () async {
    final uids = StreamController<String?>();
    addTearDown(uids.close);
    caches.bindSession(uids.stream);

    uids.add(null);
    await pumpEventQueue();
    expect(caches.clubs.get('c01'), _club);

    uids.add('u1');
    await pumpEventQueue();
    expect(caches.clubs.get('c01'), isNull);
    expect(caches.users.get('u1'), isNull);

    fill();
    uids.add('u1');
    await pumpEventQueue();
    expect(caches.clubs.get('c01'), _club);

    uids.add('u2');
    await pumpEventQueue();
    expect(caches.clubs.get('c01'), isNull);

    fill();
    uids.add(null);
    await pumpEventQueue();
    expect(caches.activeClubs.get(RepositoryReadCaches.activeClubsKey), isNull);
    expect(caches.users.get('u1'), isNull);
  });
}
