import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/page_request.dart';
import 'package:gu_data/src/core/page_result.dart';
import 'package:gu_data/src/models/activity_model.dart';
import 'package:gu_data/src/models/enums/activity_category.dart';

/// Kulüp faaliyet günlüğü — `activity/{id}` (PLAN §10.4; rules-spec §3.11,
/// domain-model §2.11).
///
/// Günlük **değiştirilemez**: kayıt güncellenmez ve silinmez; okuma kulüp
/// yönetimine (yönetici, danışman, süper admin) açıktır. Kayıt ekleme bu
/// arayüzde değildir: eylemi yapan repository kaydı kendi yazımıyla aynı
/// batch / transaction'a ekler (`FirebaseActivityRepository.addToBatch`,
/// `addToTransaction` — SDK tipi aldıkları için uygulama sınıfındadır).
// Tek üyeli arayüz bilerek sınıftır: GetIt'e kaydedilir, testte fake ile
// değiştirilir ve sonraki sürümlerde okuma üyeleri eklenir (PLAN §10.4).
// ignore: one_member_abstracts
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
}
