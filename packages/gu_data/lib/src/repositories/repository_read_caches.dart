import 'dart:async';

import 'package:gu_data/src/constants/cache_policy.dart';
import 'package:gu_data/src/constants/firestore_collections.dart';
import 'package:gu_data/src/core/app_clock.dart';
import 'package:gu_data/src/core/read_cache.dart';
import 'package:gu_data/src/models/club_model.dart';
import 'package:gu_data/src/models/user_model.dart';

/// Kulüp ve kullanıcı repository'lerinin paylaştığı bellek içi okuma
/// önbellekleri (T-44 · D3-01).
///
/// Kompozisyon kökü tek örnek kurar, `FirebaseClubRepository` ve
/// `FirebaseUserRepository`'ye verir; servisin yazım kancasını [onWrite]'a,
/// oturum akışını [bindSession]'a bağlar.
///
/// * [activeClubs]: etkin kulüp listesi (`fetchActiveClubs`), tek anahtar.
/// * [clubs]: kulüp belgesi (`getClub` / `getClubs`; liste okuması da her
///   kulübü kimliğiyle yazar).
/// * [users]: başka kullanıcının herkese açık profili (`getUsers`).
///
/// Süreler [CachePolicy]'dedir.
final class RepositoryReadCaches {
  /// [clock] saatine göre süreli önbellekleri kurar.
  RepositoryReadCaches(AppClock clock)
    : activeClubs = ReadCache(
        clock: clock,
        ttl: CachePolicy.clubTtl,
        maxEntries: 1,
      ),
      clubs = ReadCache(
        clock: clock,
        ttl: CachePolicy.clubTtl,
        maxEntries: CachePolicy.clubMax,
      ),
      users = ReadCache(
        clock: clock,
        ttl: CachePolicy.userTtl,
        maxEntries: CachePolicy.userMax,
      );

  /// [activeClubs] önbelleğinin tek anahtarı.
  static const String activeClubsKey = 'active';

  /// Etkin kulüp listesi.
  final ReadCache<String, List<ClubModel>> activeClubs;

  /// Kimliğe göre kulüp belgeleri.
  final ReadCache<String, ClubModel> clubs;

  /// uid'ye göre herkese açık kullanıcı profilleri.
  final ReadCache<String, UserModel> users;

  StreamSubscription<String?>? _session;
  String? _uid;

  /// Yazılan [path] belgesinin girdisini atar: `clubs/{id}` (yeni kulüp
  /// dahil) kulübü ve etkin listeyi, `users/{uid}` kullanıcıyı. Alt
  /// koleksiyon ve başka koleksiyon yolları yok sayılır.
  void onWrite(String path) {
    final segments = path.split('/');
    if (segments.length != 2) return;
    final [collection, id] = segments;
    switch (collection) {
      case FirestoreCollections.clubs:
        clubs.invalidate(id);
        activeClubs.invalidate(activeClubsKey);
      case FirestoreCollections.users:
        users.invalidate(id);
    }
  }

  /// Tüm önbellekleri boşaltır; süren okumalar sonuç yazamaz.
  void clear() {
    activeClubs.clear();
    clubs.clear();
    users.clear();
  }

  /// [uids] oturum akışını dinler: uid değişince ya da çıkışta (`null`)
  /// tüm önbelleği temizler — hesaplar arası sızıntı olmaz. Önceki bağ
  /// varsa kapatılır.
  void bindSession(Stream<String?> uids) {
    unawaited(_session?.cancel());
    _session = uids.listen((uid) {
      if (uid == _uid) return;
      _uid = uid;
      clear();
    });
  }

  /// Oturum aboneliğini kapatır ve önbelleği boşaltır (GetIt sıfırlaması).
  Future<void> dispose() async {
    await _session?.cancel();
    _session = null;
    clear();
  }
}
