import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';

/// Ham Firestore belge verisi (PLAN §10.2).
typedef Json = Map<String, Object?>;

/// Okunmuş bir Firestore belgesi (PLAN §10.2).
///
/// Yalnızca `gu_data` içinde dolaşır: servis döndürür, repository
/// `XModel.fromJson(doc.data)` ile modele çevirir. ViewModel bu tipi (ve
/// taşıdığı SDK [snapshot] değerini) **görmez**.
final class FirestoreDoc {
  /// Alanları verilen belgeyi oluşturur.
  const FirestoreDoc({
    required this.id,
    required this.path,
    required this.data,
    required this.snapshot,
  });

  /// Var olan bir [snapshot] belgesinden üretir; belge yoksa `null`.
  ///
  /// Henüz sunucuya ulaşmamış yerel yazımda (`hasPendingWrites`) sunucu
  /// zamanı alanları (`createdAt`, `updatedAt`) SDK'da `null` gelir; canlı
  /// dinlemede yeni yorum / gönderi bu yüzden ayrıştırılamıyor ve listenin
  /// tamamı hata oluyordu. Bu alanlar yerel saatle tahmin edilir
  /// (`ServerTimestampBehavior.estimate` karşılığı); sunucu onayıyla gelen
  /// sonraki olay gerçek değeri taşır.
  static FirestoreDoc? fromSnapshot(DocumentSnapshot<Json> snapshot) {
    final raw = snapshot.exists ? snapshot.data() : null;
    if (raw == null) return null;
    var data = raw;
    final missing = [
      for (final field in _serverTimeFields)
        if (raw.containsKey(field) && raw[field] == null) field,
    ];
    if (missing.isNotEmpty && snapshot.metadata.hasPendingWrites) {
      final now = Timestamp.now();
      data = {...raw, for (final field in missing) field: now};
    }
    return FirestoreDoc(
      id: snapshot.id,
      path: snapshot.reference.path,
      data: data,
      snapshot: snapshot,
    );
  }

  /// Yazımda `FieldValue.serverTimestamp()` alan ortak zaman alanları
  /// (`BaseFieldsPayload`).
  static const List<String> _serverTimeFields = [
    FirestoreFields.createdAt,
    FirestoreFields.updatedAt,
  ];

  /// Belge kimliği (yolun son parçası).
  final String id;

  /// Belgenin tam yolu (`posts/p01`).
  final String path;

  /// Belgenin alanları.
  final Json data;

  /// SDK belgesi; sayfalama imleci (`PageCursor`) ve transaction okumaları
  /// için.
  final DocumentSnapshot<Json> snapshot;

  /// Belge sunucu yerine yerel (kalıcı) önbellekten mi geldi? Bellek içi
  /// okuma önbelleği yalnızca sunucudan gelen belgeyi saklar (T-44 · D3-01).
  bool get isFromCache => snapshot.metadata.isFromCache;

  @override
  String toString() => 'FirestoreDoc($path)';
}
