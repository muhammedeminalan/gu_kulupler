import 'dart:async';
import 'dart:collection';

import 'package:gu_data/src/core/app_clock.dart';
import 'package:gu_data/src/core/firebase_result.dart';

/// [ReadCache.load] yükleyicisinin sonucu: `result` çağırana aynen döner;
/// `storable` `true` ise (başarı **ve** tüm belgeler sunucudan geldi) değer
/// önbelleğe yazılır.
typedef CacheLoad<V> = ({FirestoreResult<V> result, bool storable});

/// Süreli (TTL), boyutu sınırlı (LRU) bellek içi okuma önbelleği
/// (T-44 · D3-01).
///
/// * Girdi [AppClock] ile yazıldığı andan `ttl` sonra bayatlar ve atılır.
/// * En çok `maxEntries` girdi tutulur; taşınca en eski kullanılan atılır.
/// * Aynı anahtara eşzamanlı gelen [load] çağrıları tek okumada birleşir.
/// * **Nesil koruması:** [invalidate] / [clear] bir sayaç ilerletir. Bir
///   okuma, başladığı andan ([stamp]) sonra anahtarı geçersiz kılınmışsa ya
///   da önbellek temizlenmişse sonucunu **saklamaz** (yazımla yarışan eski
///   okuma taze veriyi ezmez; çıkıştan önce başlamış okuma yeni oturuma
///   sızmaz).
///
/// Yalnızca başarı saklanır; hata, "yok" ve çevrimdışı önbellekten gelen
/// sonuç saklanmaz (yükleyicinin `CacheLoad.storable` bayrağı).
final class ReadCache<K, V> {
  /// `clock` saatine göre `ttl` süreli, en çok `maxEntries` girdilik
  /// önbellek.
  ReadCache({
    required this._clock,
    required this._ttl,
    required this._maxEntries,
  });

  final AppClock _clock;
  final Duration _ttl;
  final int _maxEntries;

  /// Kullanım sırasıyla girdiler: ilk eleman en eski kullanılandır.
  final LinkedHashMap<K, _Entry<V>> _entries = LinkedHashMap<K, _Entry<V>>();

  final Map<K, Completer<FirestoreResult<V>>> _inFlight = {};

  /// Anahtarın son geçersiz kılındığı damga.
  final Map<K, int> _invalidatedAt = {};

  int _tick = 0;
  int _clearedAt = 0;

  /// Şu anki nesil damgası: bir okumadan **önce** alınır ve [put]'a verilir.
  int get stamp => _tick;

  /// Bellekteki girdi sayısı (bayatlar dahil; test ve tanılama).
  int get length => _entries.length;

  /// [key] için taze değer; yoksa ya da süresi dolmuşsa `null` (dolmuş girdi
  /// atılır). İsabet girdiyi en yeni kullanılan yapar.
  V? get(K key) {
    final entry = _entries.remove(key);
    if (entry == null) return null;
    if (!_clock.nowUtc().isBefore(entry.at.add(_ttl))) return null;
    _entries[key] = entry;
    return entry.value;
  }

  /// [value] değerini [key] altına yazar. [since] okumanın başında alınan
  /// [stamp]'tir: o andan sonra anahtar geçersiz kılındıysa, önbellek
  /// temizlendiyse ya da daha yeni bir okuma zaten yazdıysa yazılmaz
  /// (`false`).
  bool put(K key, V value, {required int since}) {
    if (since < _clearedAt || since < (_invalidatedAt[key] ?? 0)) return false;
    final existing = _entries.remove(key);
    if (existing != null && existing.since > since) {
      _entries[key] = existing;
      return false;
    }
    _entries[key] = _Entry(value, _clock.nowUtc(), since);
    while (_entries.length > _maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    return true;
  }

  /// [key] değerini önbellekten verir; yoksa [fetch] ile okur ve saklanabilir
  /// sonucu yazar. Aynı anahtarın süren okuması varsa ona katılır.
  ///
  /// [forceRefresh] `true` ise (çek-yenile, yönetim ekranı) önbellek ve süren
  /// okuma atlanır; yeni okuma her zaman başlar ve sonucu yazılır.
  Future<FirestoreResult<V>> load(
    K key,
    Future<CacheLoad<V>> Function() fetch, {
    bool forceRefresh = false,
  }) {
    if (!forceRefresh) {
      if (get(key) case final hit?) return Future.value(FirebaseSuccess(hit));
      if (_inFlight[key] case final pending?) return pending.future;
    }
    final done = Completer<FirestoreResult<V>>();
    _inFlight[key] = done;
    unawaited(_fetch(key, fetch, stamp, done));
    return done.future;
  }

  /// [fetch] okumasını yapar, saklanabilir sonucu [since] damgasıyla yazar ve
  /// [done]'ı tamamlar; süren okuma kaydını (hâlâ kendisiyse) kaldırır.
  Future<void> _fetch(
    K key,
    Future<CacheLoad<V>> Function() fetch,
    int since,
    Completer<FirestoreResult<V>> done,
  ) async {
    try {
      final loaded = await fetch();
      if (loaded.storable) {
        if (loaded.result case FirebaseSuccess(:final data)) {
          put(key, data, since: since);
        }
      }
      done.complete(loaded.result);
    } on Object catch (error, stack) {
      done.completeError(error, stack);
    } finally {
      if (identical(_inFlight[key], done)) _inFlight.remove(key);
    }
  }

  /// [key] girdisini atar; süren okuması sonucunu yazamaz.
  void invalidate(K key) {
    _entries.remove(key);
    _inFlight.remove(key);
    _invalidatedAt[key] = ++_tick;
  }

  /// Tüm girdileri atar (oturum değişimi); süren okumalar yazamaz.
  void clear() {
    _entries.clear();
    _inFlight.clear();
    _invalidatedAt.clear();
    _clearedAt = ++_tick;
  }
}

final class _Entry<V> {
  const _Entry(this.value, this.at, this.since);

  final V value;

  /// Yazıldığı an (UTC).
  final DateTime at;

  /// Değeri üreten okumanın başladığı damga.
  final int since;
}
