import 'package:cloud_firestore/cloud_firestore.dart';

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
  static FirestoreDoc? fromSnapshot(DocumentSnapshot<Json> snapshot) {
    final data = snapshot.exists ? snapshot.data() : null;
    if (data == null) return null;
    return FirestoreDoc(
      id: snapshot.id,
      path: snapshot.reference.path,
      data: data,
      snapshot: snapshot,
    );
  }

  /// Belge kimliği (yolun son parçası).
  final String id;

  /// Belgenin tam yolu (`posts/p01`).
  final String path;

  /// Belgenin alanları.
  final Json data;

  /// SDK belgesi; sayfalama imleci (`PageCursor`) ve transaction okumaları
  /// için.
  final DocumentSnapshot<Json> snapshot;

  @override
  String toString() => 'FirestoreDoc($path)';
}
