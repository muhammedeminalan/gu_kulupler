// Security Rules'un şikayet yazımındaki davranışını (rules-spec §3.10, §3.18;
// T-45 kullanıcı kararı 3) taklit eden el yazımı `cloud_firestore` SDK çifti.
// `fake_cloud_firestore` kural çalıştırmadığı için "var olan şikayete set =
// update → ret", "şikayet sayacı yalnızca sunucu gününün anahtarıyla ve
// count + 1 ≤ Limits.reportDailyLimit iken geçer" davranışları bununla kurulur.
// SDK sınıfları uygulanır (`FirebaseFirestore` / `WriteBatch`).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gu_data/gu_data.dart';

import 'sdk_firestore_stubs.dart';

/// [inner] veritabanına ileten, batch commit'inde şikayet kurallarını
/// denetleyen `FirebaseFirestore` çifti.
///
/// Ret `permission-denied` fırlatır ve batch'in **hiçbir** yazımı uygulanmaz
/// (iç batch commit edilmez — gerçek batch'in "ya hepsi ya hiçbiri"
/// davranışı). Denetimler, commit anındaki veritabanı durumuna göredir:
///
/// - `reports/…` belgesine `set` belge zaten varsa reddedilir (Rules'ta
///   update, şikayet edene kapalı).
/// - `reportCounters/…` belgesine yazım, [serverDayKey] verildiyse kimlik
///   `_<serverDayKey>` ile bitmiyorsa (gün eşitliği toleranssız — W-50) ya
///   da sayacın şimdiki değeri + 1 `Limits.reportDailyLimit`'i aşıyorsa
///   reddedilir.
/// - [denyAll] `true` ise her batch reddedilir (etkin olmayan hesap vb.).
final class RulesReportFirestore implements FirebaseFirestore {
  /// [inner] veritabanını sarar; sunucunun Istanbul günü [serverDayKey]
  /// (`yyyyMMdd`; `null` → gün denetimi yok).
  RulesReportFirestore(this.inner, {this.serverDayKey});

  /// Yazımların uygulandığı veritabanı.
  final FirebaseFirestore inner;

  /// Sunucunun (Rules'ın) geçerli saydığı gün anahtarı.
  final String? serverDayKey;

  /// `true` → her batch `permission-denied` ile reddedilir.
  bool denyAll = false;

  /// Her commit denetiminden hemen önce çağrılır (eşzamanlı yazımı taklit
  /// etmek için: ön okumadan sonra, commit'ten önce).
  Future<void> Function()? beforeCommit;

  /// `commit` çağrı sayısı (reddedilenler dahil).
  int commits = 0;

  /// Reddedilen batch'lerin ret nedeni olan belge yolları, sırayla.
  final List<String> denied = [];

  @override
  CollectionReference<Json> collection(String collectionPath) =>
      inner.collection(collectionPath);

  @override
  WriteBatch batch() => _RulesBatch(this, inner.batch());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Yazımları iç batch'e hemen ekleyen, yollarını kaydeden ve commit'te
/// [RulesReportFirestore] kurallarını uygulayan batch.
final class _RulesBatch implements WriteBatch {
  _RulesBatch(this._rules, this._inner);

  final RulesReportFirestore _rules;
  final WriteBatch _inner;
  final List<({String path, bool isSet})> _ops = [];

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    _ops.add((path: document.path, isSet: true));
    _inner.set(document, data, options);
  }

  @override
  void update<T>(DocumentReference<T> document, T data) {
    _ops.add((path: document.path, isSet: false));
    _inner.update(document, data);
  }

  @override
  Future<void> commit() async {
    _rules.commits++;
    await _rules.beforeCommit?.call();
    final reason = await _deniedPath();
    if (reason != null) {
      _rules.denied.add(reason);
      throw firestoreException('permission-denied');
    }
    await _inner.commit();
  }

  /// Reddi gerektiren ilk yazımın yolu; geçerse `null`.
  Future<String?> _deniedPath() async {
    for (final op in _ops) {
      if (_rules.denyAll) return op.path;
      final existing = (await _rules.inner.doc(op.path).get()).data();
      if (op.path.startsWith('${FirestoreCollections.reports}/') &&
          op.isSet &&
          existing != null) {
        return op.path;
      }
      if (op.path.startsWith('${FirestoreCollections.reportCounters}/')) {
        final day = _rules.serverDayKey;
        if (day != null && !op.path.endsWith('_$day')) return op.path;
        final count = existing?[FirestoreFields.count] as int? ?? 0;
        if (count + 1 > Limits.reportDailyLimit) return op.path;
      }
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
