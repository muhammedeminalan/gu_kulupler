import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/page_request.dart';
import 'package:gu_data/src/core/page_result.dart';
import 'package:gu_data/src/models/activity_model.dart';
import 'package:gu_data/src/models/enums/activity_category.dart';
import 'package:gu_data/src/models/enums/activity_kind.dart';

/// Kulüp faaliyet günlüğü — `activity/{id}` (PLAN §10.4; rules-spec §3.11,
/// domain-model §2.11).
///
/// Günlük **değiştirilemez**: kayıt güncellenmez ve silinmez; okuma kulüp
/// yönetimine (yönetici, danışman, süper admin) açıktır. Kayıt ekleme bu
/// arayüzde değildir: eylemi yapan repository kaydı kendi yazımıyla aynı
/// batch / transaction'a ekler (`FirebaseActivityRepository.addToBatch`,
/// `addToTransaction` — SDK tipi aldıkları için uygulama sınıfındadır).
abstract interface class ActivityRepository {
  /// [clubId] kulübünün günlüğünden bir sayfa, en yeni kayıt üstte (MGT-10).
  ///
  /// [category] verilirse yalnızca o kategorinin türleri döner
  /// (`ActivityCategory.kinds`). Geçersiz [clubId]
  /// [FirestoreError.invalidArgument]; ayrıştırılamayan kayıt
  /// [FirestoreError.parse].
  Future<FirestoreResult<PageResult<ActivityModel>>> listActivity(
    String clubId,
    PageRequest page, {
    ActivityCategory? category,
  });

  /// ADM-01 grafiği (CD-46, T-38): **tüm kulüplerde** [kinds] türündeki
  /// kayıtların [weeks] haftalık kovadaki sayıları, en eski solda.
  ///
  /// Kova `i` = `[fromUtc + i·7 gün, fromUtc + (i+1)·7 gün)`; çağıran
  /// [fromUtc]'yi Istanbul gün başına hizalar (`AppClock.istanbulStartOfDay`).
  /// Her kova tek `count()` toplama sorgusudur (`kind in kinds`, `createdAt`
  /// aralığı; belge okunmaz) — 8 hafta = 8 sorgu; indeks `activity (kind,
  /// createdAt↓)`. `clubId` süzgeci yoktur: Rules yalnızca süper admine açar
  /// (rules-spec §3.11), başkası [FirestoreError.permissionDenied] alır.
  /// Boş [kinds], `RepositoryHelpers.whereInMax` üstü tür ya da pozitif
  /// olmayan [weeks] → [FirestoreError.invalidArgument]; kovalardan biri
  /// okunamazsa çağrı o hatayla başarısız olur.
  Future<FirestoreResult<List<int>>> countByWeek({
    required Set<ActivityKind> kinds,
    required DateTime fromUtc,
    required int weeks,
  });
}
