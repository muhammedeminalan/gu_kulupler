// Security Rules'ın duyuru sayacı gün denetimini (rules-spec §3.16, CD-129)
// taklit eden el yazımı `cloud_firestore` SDK çifti. `fake_cloud_firestore`
// kural çalıştırmadığı ve transaction yazımlarını anında uyguladığı için
// "yanlış gün anahtarı → permission-denied, hiçbir şey yazılmaz" davranışı
// bununla kurulur.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gu_data/gu_data.dart';

import 'sdk_firestore_stubs.dart';

/// [inner] veritabanına ileten, transaction'larda **sunucu gününü** denetleyen
/// `FirebaseFirestore` çifti.
///
/// Bir transaction `announcementCounters/…` belgesine yazıyorsa belge kimliği
/// `_<serverDayKey>` ile bitmelidir (Rules gün eşitliği toleranssızdır);
/// bitmiyorsa işlem `permission-denied` ile reddedilir ve gövdenin **hiçbir**
/// yazımı uygulanmaz (yazımlar gövde bitene kadar bekletilir — gerçek
/// transaction'ın "ya hepsi ya hiçbiri" davranışı).
final class RulesDayFirestore implements FirebaseFirestore {
  /// [inner] veritabanını sarar; sunucunun Istanbul günü [serverDayKey]
  /// (`yyyyMMdd`) olur.
  RulesDayFirestore(this.inner, {required this.serverDayKey});

  /// Yazımların uygulandığı veritabanı.
  final FirebaseFirestore inner;

  /// Sunucunun (Rules'ın) geçerli saydığı gün anahtarı.
  final String serverDayKey;

  /// Gün denetimine takılıp reddedilen sayaç belgelerinin yolları, sırayla.
  final List<String> denied = [];

  @override
  CollectionReference<Json> collection(String collectionPath) =>
      inner.collection(collectionPath);

  @override
  WriteBatch batch() => inner.batch();

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) => inner.runTransaction((tx) async {
    final buffered = _BufferedTransaction(tx);
    final result = await transactionHandler(buffered);
    for (final path in buffered.paths) {
      if (path.startsWith('${FirestoreCollections.announcementCounters}/') &&
          !path.endsWith('_$serverDayKey')) {
        denied.add(path);
        throw firestoreException('permission-denied');
      }
    }
    buffered.flush();
    return result;
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Okumaları hemen ileten, yazımları [flush] çağrılana kadar bekleten
/// transaction.
final class _BufferedTransaction implements Transaction {
  _BufferedTransaction(this._inner);

  final Transaction _inner;
  final List<void Function()> _pending = [];

  /// Kuyruğa giren yazımların belge yolları, sırayla.
  final List<String> paths = [];

  /// Bekleyen yazımları sırayla uygular.
  void flush() {
    for (final write in _pending) {
      write();
    }
  }

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) => _inner.get(documentReference);

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    paths.add(documentReference.path);
    _pending.add(() => _inner.set(documentReference, data, options));
    return this;
  }

  @override
  Transaction update(
    DocumentReference<Object?> documentReference,
    Map<Object, Object?> data,
  ) {
    paths.add(documentReference.path);
    _pending.add(() => _inner.update(documentReference, data));
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
