import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

/// Sayfalı sorguda "kaldığın yer" imleci (PLAN §10.2, §10.3).
///
/// Uygulama katmanı için **opaktır**: ViewModel imleci yalnızca saklar ve bir
/// sonraki `PageRequest.after` olarak geri verir; içindeki Firestore belgesini
/// görmez. Belgeli kurucu ve [snapshot] yalnızca `gu_data` içinden kullanılır
/// (`@internal`).
///
/// Testlerde belgesiz bir imleç gerekir (fake repository'lerin "sonraki sayfa
/// var" demesi için): [PageCursor.fake] yalnızca test dizinlerinden
/// çağrılabilir (`@visibleForTesting`) ve gerçek sorguya verilemez.
///
/// Eşitlik kimliğe göredir: her sayfa çekimi yeni bir imleç üretir, aynı
/// belgeyi gösteren iki ayrı imleç eşit sayılmaz.
final class PageCursor {
  /// [snapshot] belgesinden sonrasını gösteren imleç oluşturur.
  @internal
  const PageCursor(DocumentSnapshot<Map<String, Object?>> snapshot)
    : _snapshot = snapshot;

  /// Belge taşımayan test imleci (PLAN §16.3 "`PageCursor` sahte").
  ///
  /// Fake repository'ler `PageResult.next` olarak döndürür; ViewModel onu
  /// gerçek imleç gibi taşır. Kurucu bilerek `const` değildir: her çağrı ayrı
  /// kimlikli bir imleç üretir, böylece fake hangi imlecin hangi sayfayı
  /// gösterdiğini kimlikle ayırt edebilir. [snapshot] okunursa [StateError]
  /// fırlatır.
  @visibleForTesting
  PageCursor.fake() : _snapshot = null;

  final DocumentSnapshot<Map<String, Object?>>? _snapshot;

  /// Sorgunun `startAfterDocument` ile devam edeceği son belge.
  ///
  /// [PageCursor.fake] ile üretilmiş imleçte belge yoktur: [StateError]
  /// fırlatır (test imleci gerçek sorguya verilmiştir — programlama hatası).
  @internal
  DocumentSnapshot<Map<String, Object?>> get snapshot =>
      _snapshot ??
      (throw StateError(
        'PageCursor.fake() belge taşımaz; gerçek sorguda kullanılamaz.',
      ));
}
