import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';

/// "Katıl" akışının sonucu. Sheet açma ve gezinme view'dadır (PLAN §12.1);
/// ViewModel yalnızca hangisinin gerektiğini söyler.
enum JoinOutcome {
  /// Onaysız kulübe anında katılındı (TST-34 gösterildi).
  joined,

  /// Başvuru formu gerekli: view SHT-05'i açar (kulüp onay istiyor ya da
  /// kullanıcı yeniden başvuruyor).
  needsApplication,

  /// Yeniden başvuru bekleme süresi dolmadı: view başvuru durumuna (CLB-05)
  /// gider.
  waiting,

  /// Bekleme süresini sunucu söyledi (oturumdaki üyelik eskiydi): TST-X4
  /// gösterildi.
  cooldown,

  /// Kulüp başvuru almıyor (TST-X1 gösterildi).
  closed,

  /// Katılım olmadı: kulüp yüklenmedi, süren işlem var, çevrimdışı (TST-24),
  /// yetki yok (TST-X18) ya da beklenmeyen hata.
  failed,
}

/// `JoinApplicationViewModel.submit` çağrısının sonucu (SHT-05). Sheet
/// yalnızca [applied] ve [joined] ile kapanır (`pop` değeri budur);
/// diğerlerinde açık kalır. Sheet'i açan her ekran (CLB-01, CLB-02, CLB-03,
/// CLB-05) sonucu bu türle okur.
enum JoinApplicationOutcome {
  /// Başvuru yazıldı (`pending`) → çağıran CLB-04'e gider.
  applied,

  /// Onaysız kulübe anında katılındı (`active`) → çağıran TST-34 gösterir.
  joined,

  /// Not eksik / geçersiz; alan hatası yazıldı.
  invalid,

  /// Çevrimdışı ya da ağ hatası (TST-24 gösterildi).
  offline,

  /// Kulüp başvuru almıyor (TST-X1 gösterildi).
  closed,

  /// Yeniden başvuru bekleme süresi dolmadı (TST-X4 gösterildi).
  cooldown,

  /// Sunucu reddetti; `submitError` yazıldı.
  failed,

  /// Kulüp henüz yüklenmedi ya da süren bir gönderim var.
  ignored,
}

/// Kulübe katılım akışının ortak çekirdeği — "Katıl" düğmesi olan her
/// ViewModel (CLB-02 `SearchViewModel`; CLB-03 `ClubDetailViewModel`, CLB-01
/// `ClubListViewModel`) aynı kararı ve aynı hata eşlemesini buradan alır
/// (CD-138 (4)(m); prototip `startJoin`, `cards.js:12–18`).
///
/// Mixin durum tutmaz ve yazmaz: giriş kararını ([joinGate]) ve
/// `membershipRepository.joinInstant` hatasının sonucunu
/// ([joinRuleOutcome], [showWriteFailureToast]) verir. Yazımı, çevrimdışı
/// kapısını (`WriteGuardMixin.ensureOnline`), iyimser güncellemeyi ve TST-34'ü
/// tüketici yapar:
///
/// ```dart
/// if (joinGate(club, membership) case final outcome?) return outcome;
/// if (!ensureOnline()) return JoinOutcome.failed;
/// final result = await membershipRepository.joinInstant(…);
/// ```
mixin ClubJoinMixin on ProjectDependencyMixin {
  /// Bağlantı kaynaklı yazma hataları (→ TST-24).
  static const Set<FirestoreError> networkErrors = {
    FirestoreError.offline,
    FirestoreError.unavailable,
    FirestoreError.timeout,
  };

  /// Reddedilmiş, çıkarılmış ya da başvurusunu geri çekmiş kullanıcı onaysız
  /// kulübe de başvuruyla girer (`MembershipRepository.joinInstant` →
  /// `reapplyNeedsReview`).
  static bool needsReview(MembershipStatus? status) =>
      status == MembershipStatus.rejected ||
      status == MembershipStatus.removed ||
      status == MembershipStatus.cancelled;

  /// Devre dışı "Başvurular kapalı" düğmesine dokunma (`cards.js:22`) →
  /// TST-X1.
  void showApplicationsClosed() => feedback.showToast(ToastId.tstX1);

  /// "Katıl" girişindeki karar; `null` → kulübe doğrudan katılınabilir
  /// (çağıran `joinInstant` yazar).
  ///
  /// Sıra: başvurular kapalı → TST-X1 + [JoinOutcome.closed]; yeniden başvuru
  /// beklemesi sürüyor → [JoinOutcome.waiting] (view CLB-05'e gider); kulüp
  /// onay istiyor ya da kullanıcının eski kaydı var (ret / çıkarma / iptal)
  /// → [JoinOutcome.needsApplication] (view SHT-05'i açar).
  JoinOutcome? joinGate(ClubModel club, MembershipModel? membership) {
    if (!club.applicationsOpen) {
      showApplicationsClosed();
      return JoinOutcome.closed;
    }
    final retryAfter = membership?.retryAfter;
    if (retryAfter != null && retryAfter.isAfter(appClock.nowUtc())) {
      return JoinOutcome.waiting;
    }
    if (club.approvalRequired || needsReview(membership?.status)) {
      return JoinOutcome.needsApplication;
    }
    return null;
  }

  /// `joinInstant` hatasının katılım kurallarına düşen sonucu; hata bir
  /// katılım kuralı değilse `null` (çağıran [showWriteFailureToast] ile
  /// sürdürür).
  ///
  /// * Başvurular kapalı → TST-X1, [reloadClub] (beklenmez),
  ///   [JoinOutcome.closed].
  /// * Bekleme süresi → TST-X4 (`{date}` = [formatDate]; an sunucudan, yoksa
  ///   [membership]'ten), [JoinOutcome.cooldown].
  /// * Eski kayıt incelemeye gitmeli → [JoinOutcome.needsApplication].
  /// * Çakışma (kulüp bu arada onaya geçmiş ya da üyelik başka cihazda
  ///   değişmiş olabilir) → [reloadClub] beklenir; güncel kulüp onay
  ///   istiyorsa [JoinOutcome.needsApplication], değilse
  ///   [JoinOutcome.failed].
  ///
  /// [reloadClub] kulübün güncel halini okur; okunamazsa / ViewModel
  /// kapandıysa `null` döner.
  Future<JoinOutcome?> joinRuleOutcome({
    required FirestoreError error,
    required Object? detail,
    required MembershipModel? membership,
    required String Function(DateTime retryAfter) formatDate,
    required Future<ClubModel?> Function() reloadClub,
  }) async {
    final rule =
        error == FirestoreError.ruleViolation &&
            detail is FirestoreFailureDetail
        ? detail
        : null;
    switch (rule?.code) {
      case FirestoreRuleCode.applicationsClosed:
        showApplicationsClosed();
        unawaited(reloadClub());
        return JoinOutcome.closed;
      case FirestoreRuleCode.retryCooldown:
        final until = rule?.retryAfter ?? membership?.retryAfter;
        if (until != null) {
          feedback.showToast(
            ToastId.tstX4,
            params: ToastParams(date: formatDate(until)),
          );
        }
        return JoinOutcome.cooldown;
      case FirestoreRuleCode.reapplyNeedsReview:
        return JoinOutcome.needsApplication;
      case _:
        break;
    }
    if (error != FirestoreError.conflict) return null;
    final club = await reloadClub();
    return (club?.approvalRequired ?? false)
        ? JoinOutcome.needsApplication
        : JoinOutcome.failed;
  }

  /// Yazma hatasının bildirimi: ağ → TST-24, yetki yok → TST-X18. Toast
  /// gösterildiyse `true`; başka hatada `false` (çağıran günlüğe yazar ve
  /// ekranı yeniler).
  bool showWriteFailureToast(FirestoreError error) {
    if (networkErrors.contains(error)) {
      feedback.showToast(ToastId.tst24);
      return true;
    }
    if (error == FirestoreError.permissionDenied) {
      feedback.showToast(ToastId.tstX18);
      return true;
    }
    return false;
  }
}
