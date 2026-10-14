import 'dart:async';
import 'dart:ui' show VoidCallback;

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_detail_state.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/report_reason_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/share_sheet.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/club_join_mixin.dart';
import 'package:gu_kulupler/product/mixin/external_link_mixin.dart';
import 'package:gu_kulupler/product/mixin/membership_dialogs_mixin.dart';
import 'package:gu_kulupler/product/mixin/report_received_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/club_detail_tab.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'club_detail_view_model.g.dart';

/// CLB-03 "Kulüp" ekranının ViewModel'i (kulüp başına bir örnek; PLAN §12.6,
/// prototip `S['CLB-03']`, `screens-clubs.js:77–112`).
///
/// * Kulübü açılışta okur; erişim kipi ve üyelik belgesi oturumdan canlı
///   gelir (`SessionState.accessTo` / `.memberships`). Yönetim kurulu herkese
///   yüklenir (Rules yönetici üyeliklerini doğrulanmış her kullanıcıya açar —
///   CD-139); üye önizlemesi kulübün içini görende (`ClubDetailState
///   .seesInside`) üye listesinden, görmeyende yöneticilerden kurulur.
/// * Sheet açma ve gezinme view'dadır; ViewModel hangisinin gerektiğini
///   sonuç değeriyle söyler. Onay dialogları (DLG-08, DLG-09, DLG-12, DLG-32)
///   ve toast'lar buradan gösterilir.
///
/// | İşlem | Sonuç | Geri bildirim |
/// |---|---|---|
/// | [startJoin] | başvuru kapalı | TST-X1 |
/// | | bekleme sürüyor | view → CLB-05 |
/// | | onay gerekli / yeniden başvuru | view → SHT-05 |
/// | | onaysız kulüp | [joinInstant] |
/// | [joinInstant] | katıldı | TST-34 ("Kulübe git") |
/// | | kapalı · bekleme · inceleme gerekli | TST-X1 · TST-X4 · view → SHT-05 |
/// | [leave] | onay → ayrıldı | DLG-08 → TST-39 |
/// | | başkan | DLG-09 |
/// | [share] | kopyala · WhatsApp / e-posta · diğer | TST-35 · DLG-32 · sistem paylaşımı |
/// | [openEmail] · [openInstagram] · [openWeb] | onay → açıldı | DLG-32 |
/// | | e-posta açılamadı | adres kopyalanır, TST-08 |
/// | [submitReport] → [showReportReceived] | yazıldı / zaten bildirilmiş | DLG-12 |
/// | [fetchEvents] | etkinlikler + kullanıcının kayıtları | sekme içi hata |
/// | [showRegistrationClosed] | "Kayıtlar kapalı" kartı | TST-X2 |
/// | yazan her işlem | çevrimdışı / ağ · yetki yok | TST-24 · TST-X18 |
///
/// Design: CLB-03
@riverpod
final class ClubDetailViewModel extends _$ClubDetailViewModel
    with
        ProjectDependencyMixin,
        WriteGuardMixin,
        ClubJoinMixin,
        ExternalLinkMixin,
        MembershipDialogsMixin,
        ReportReceivedMixin {
  /// Kulübün olmadığını söyleyen okuma hataları (→ SYS-04).
  static const Set<FirestoreError> _missingErrors = {
    FirestoreError.notFound,
    FirestoreError.parse,
  };

  bool _isLoading = false;
  bool _isConfirmingLeave = false;

  /// Etkinlik okumalarının sırası: eski kipin (ziyaretçi ↔ üye) geç gelen
  /// sonucu yenisinin üstüne yazılmaz.
  int _eventsGeneration = 0;

  @override
  ClubDetailState build(String clubId) {
    ref.listen(sessionViewModelProvider, (_, session) {
      final access = session.accessTo(clubId);
      final membership = session.memberships[clubId];
      if (access == state.access && membership == state.membership) return;
      _onSession(access, membership);
    });
    // Kulüp ilk karede okunmaya başlar; view ayrıca çağırmaz.
    unawaited(Future<void>.microtask(_load));
    final session = ref.read(sessionViewModelProvider);
    return ClubDetailState(
      access: session.accessTo(clubId),
      membership: session.memberships[clubId],
      isFetching: true,
    );
  }

  /// Şikayet hedefi: bu kulüp (SHT-10).
  ReportTarget get reportTarget =>
      (type: ReportTargetType.club, id: clubId, clubId: clubId);

  /// Kulübün paylaşım bağlantısı (`AppConstants.shareBaseUrl` + yol; SHT-15).
  String shareUrl() => '${AppConstants.shareBaseUrl}${AppPaths.clubs}/$clubId';

  /// Kulübü yeniden okur — hata görünümündeki "Yeniden dene". Süren okuma
  /// varken gelen çağrı yok sayılır.
  Future<void> fetch() async {
    if (!ref.mounted || _isLoading) return;
    state = state.copyWith(isFetching: true, isError: false, isNotFound: false);
    await _load();
  }

  /// Görünen kulübü iskelet göstermeden yeniler (katılma / ayrılma sonrası
  /// üye sayısı ve kişi listeleri). Okunamazsa var olan içerik kalır; kulüp
  /// artık yoksa `isNotFound`.
  Future<void> refresh() async {
    if (!ref.mounted || _isLoading || state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true);
    final result = await clubRepository.getClub(clubId);
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess(:final data):
        state = state.copyWith(club: data, isRefreshing: false, isError: false);
        await _loadPeople();
      case FirebaseFailure(:final error) when _missingErrors.contains(error):
        state = state.copyWith(isRefreshing: false, isNotFound: true);
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn('Kulüp yenilenemedi: ${error.name}', error: message);
        state = state.copyWith(isRefreshing: false);
    }
  }

  /// "Etkinlikler" sekmesini yeniden okur — sekme içi hata görünümündeki
  /// "Yeniden dene" ve karttan katılım / bekleme listesi akışı sonrası
  /// (kart durumları).
  ///
  /// Okuma kullanıcının kipine göre sınırlıdır (Rules süzgeç değildir —
  /// `EventRepository.listClubEvents`): kulübün içini gören (üye, yönetici,
  /// danışman, süper admin) yayındaki ve iptal edilmiş tüm etkinlikleri,
  /// görmeyen yalnızca herkese açık olanları okur; taslaklar hiç okunmaz
  /// (CLB-03 taslak göstermez — `screens-clubs.js:81`). Kullanıcının katılım
  /// kayıtları (`rsvpRepository.listMine`) aynı anda okunur; okunamazsa
  /// kartlar durum rozetsiz çizilir.
  Future<void> fetchEvents() => _loadEvents();

  /// Devre dışı "Kayıtlar kapalı" kart düğmesi (`CLB-03.join.<eventId>`) →
  /// TST-X2.
  void showRegistrationClosed() => feedback.showToast(ToastId.tstX2);

  /// Sekme değişti (`CLB-03.tab.*`, `CLB-03.memberCount`, `?tab=`).
  void setTab(ClubDetailTab tab) {
    if (tab == state.tab) return;
    state = state.copyWith(tab: tab);
  }

  /// "Katıl" (`CLB-03.join.*`): katılım akışının girişi (prototip
  /// `startJoin`, `cards.js:12–18`).
  ///
  /// Karar ortak çekirdektedir (`ClubJoinMixin.joinGate`): başvurular kapalı
  /// → TST-X1; yeniden başvuru beklemesi sürüyor → [JoinOutcome.waiting]
  /// (view CLB-05'e gider); kulüp onay istiyor ya da kullanıcının eski kaydı
  /// var (ret / çıkarma / iptal — anında katılamaz) →
  /// [JoinOutcome.needsApplication] (view SHT-05'i açar); aksi halde
  /// [joinInstant].
  ///
  /// [formatDate] TST-X4'ün `{date}` metnini üretir (yerel ayara göre
  /// biçimleme view'dadır); [onOpenClub] TST-34'ün "Kulübe git" eylemidir.
  Future<JoinOutcome> startJoin({
    required String Function(DateTime retryAfter) formatDate,
    VoidCallback? onOpenClub,
  }) async {
    final club = state.club;
    if (club == null || club.isSuspended || state.isActing) {
      return JoinOutcome.failed;
    }
    if (joinGate(club, state.membership) case final outcome?) return outcome;
    return joinInstant(formatDate: formatDate, onOpenClub: onOpenClub);
  }

  /// Onay gerektirmeyen kulübe doğrudan katılır
  /// (`membershipRepository.joinInstant`); başarıda TST-34 gösterir ve
  /// kulübü yeniler (üye sayısı).
  ///
  /// Sunucu reddederse: başvurular kapalı → TST-X1; bekleme süresi → TST-X4;
  /// eski kayıt incelemeye gitmeli ya da kulüp artık onay istiyor →
  /// [JoinOutcome.needsApplication]; çevrimdışı / ağ → TST-24; yetki yok →
  /// TST-X18. Süren işlem varken gelen çağrı yok sayılır.
  Future<JoinOutcome> joinInstant({
    required String Function(DateTime retryAfter) formatDate,
    VoidCallback? onOpenClub,
  }) async {
    if (state.club == null || state.isActing) return JoinOutcome.failed;
    if (!ensureOnline()) return JoinOutcome.failed;
    final applicant = ref.read(sessionViewModelProvider).user;
    final email = authRepository.currentUser?.email;
    if (applicant == null || email == null) {
      AppLogger.warn('Kulübe katılınamadı: oturumda profil / e-posta yok');
      return JoinOutcome.failed;
    }

    state = state.copyWith(isActing: true);
    final result = await membershipRepository.joinInstant(
      clubId: clubId,
      applicant: applicant,
      email: email,
    );
    if (!ref.mounted) {
      return result.isSuccess ? JoinOutcome.joined : JoinOutcome.failed;
    }
    state = state.copyWith(isActing: false);
    switch (result) {
      case FirebaseSuccess():
        showJoined(onOpenClub: onOpenClub);
        return JoinOutcome.joined;
      case FirebaseFailure(:final error, :final message, :final detail):
        return _joinFailed(error, message, detail, formatDate);
    }
  }

  /// Katılım bildirimi: TST-34 "Kulübe katıldın!" ([onOpenClub] verilirse
  /// "Kulübe git" eylemiyle) ve kulübün yenilenmesi. SHT-05 onaysız kulüpte
  /// katılımla kapanınca da view bunu çağırır.
  void showJoined({VoidCallback? onOpenClub}) {
    feedback.showToast(ToastId.tst34, onAction: onOpenClub);
    unawaited(refresh());
  }

  /// "Kulüpten ayrıl" (SHT-06): DLG-08 onayı → `membershipRepository.leave`
  /// → TST-39. Başkan devretmeden ayrılamaz: onay sorulmadan DLG-09
  /// gösterilir (`sheets.js:35`); sunucu aynı kuralı söylerse yine DLG-09.
  ///
  /// DLG-09'da "Başkanlığı devret" seçilirse [LeaveOutcome.transferRequested]
  /// döner; devir akışını çağıran başlatır.
  Future<LeaveOutcome> leave() async {
    final club = state.club;
    final uid = ref.read(sessionViewModelProvider).uid;
    if (club == null || uid == null || state.isActing || _isConfirmingLeave) {
      return LeaveOutcome.failed;
    }
    _isConfirmingLeave = true;
    try {
      if (state.activeRole == ClubRole.president) return await _solePresident();
      if (!await confirmLeaveClub(clubName: club.name)) {
        return LeaveOutcome.cancelled;
      }
    } finally {
      _isConfirmingLeave = false;
    }
    if (!ref.mounted) return LeaveOutcome.failed;
    if (!ensureOnline()) return LeaveOutcome.failed;

    state = state.copyWith(isActing: true);
    final result = await membershipRepository.leave(
      clubId: clubId,
      userId: uid,
    );
    if (!ref.mounted) {
      return result.isSuccess ? LeaveOutcome.left : LeaveOutcome.failed;
    }
    state = state.copyWith(isActing: false);
    switch (result) {
      case FirebaseSuccess():
        feedback.showToast(ToastId.tst39);
        unawaited(refresh());
        return LeaveOutcome.left;
      case FirebaseFailure(
        error: FirestoreError.ruleViolation,
        detail: FirestoreFailureDetail(
          code: FirestoreRuleCode.presidentCannotLeave,
        ),
      ):
        return _solePresident();
      case FirebaseFailure(:final error, :final message):
        _showWriteFailure(error, message, 'Kulüpten ayrılınamadı');
        return LeaveOutcome.failed;
    }
  }

  /// SHT-15'te seçilen paylaşım yolunu uygular: kopyala → TST-35; WhatsApp /
  /// e-posta → harici bağlantı onayı (DLG-32); "Diğer…" → sistem paylaşım
  /// sayfası.
  Future<void> share(ShareChoice choice) async {
    final club = state.club;
    if (club == null) return;
    final url = shareUrl();
    switch (choice) {
      case ShareChoice.copyLink:
        if (await shareService.copyText(url)) {
          feedback.showToast(ToastId.tst35);
        }
      case ShareChoice.whatsapp:
        await openExternal(ShareLinks.whatsApp(url));
      case ShareChoice.email:
        await openExternal(ShareLinks.email(club.name));
      case ShareChoice.other:
        await shareService.shareText(url, subject: club.name);
    }
  }

  /// [uri] adresini harici bağlantı onayıyla (DLG-32) açar.
  Future<ExternalLinkResult> openExternal(Uri uri) => openExternalLink(uri);

  /// Kulübün e-postası (`CLB-03.about.link.email`): DLG-32 → e-posta
  /// uygulaması. Adres cihazda açılamazsa (e-posta uygulaması yok) adres
  /// panoya kopyalanır ([copyEmail]).
  Future<void> openEmail() async {
    final uri = ExternalLinks.mail(state.club?.social.email ?? '');
    if (uri == null) return;
    final result = await openExternal(uri);
    if (result == ExternalLinkResult.failed) await copyEmail();
  }

  /// Kulübün e-posta adresini panoya kopyalar → TST-08.
  Future<void> copyEmail() async {
    final email = state.club?.social.email?.trim() ?? '';
    if (email.isEmpty) return;
    if (await shareService.copyText(email)) feedback.showToast(ToastId.tst08);
  }

  /// Kulübün Instagram profili (`CLB-03.about.link.instagram`) → DLG-32.
  Future<void> openInstagram() async {
    final uri = ExternalLinks.instagram(state.club?.social.instagram ?? '');
    if (uri != null) await openExternal(uri);
  }

  /// Kulübün web sitesi (`CLB-03.about.link.web`) → DLG-32.
  Future<void> openWeb() async {
    final uri = ExternalLinks.web(state.club?.social.web ?? '');
    if (uri != null) await openExternal(uri);
  }

  /// SHT-10'da doğrulanan şikayeti yazar (`reportRepository.report`).
  /// `true` → sheet kapanır ve view [showReportReceived] çağırır; aynı hedef
  /// daha önce bildirilmişse de `true` (DLG-12 yine gösterilir). `false` →
  /// sheet açık kalır: çevrimdışı / ağ (TST-24), yetki yok (TST-X18),
  /// beklenmeyen hata.
  Future<bool> submitReport(ReportReasonResult report) async {
    final uid = ref.read(sessionViewModelProvider).uid;
    if (uid == null) return false;
    if (!ensureOnline()) return false;
    final result = await reportRepository.report(
      reporterId: uid,
      target: report.target,
      reason: report.reason,
      note: report.note,
    );
    switch (result) {
      case FirebaseSuccess():
      case FirebaseFailure(error: FirestoreError.alreadyExists):
        return true;
      case FirebaseFailure(:final error, :final message):
        _showWriteFailure(error, message, 'Şikayet gönderilemedi');
        return false;
    }
  }

  /// DLG-12 "Şikayetin alındı". Kulüp şikayetinde engellenecek kullanıcı
  /// yoktur: tek "Tamam".
  Future<void> showReportReceived() async {
    await showReportReceivedDialog();
  }

  /// Başkan ve yönetim kurulu, başkan önde; kalanların sırası korunur
  /// (`actions.js:35`).
  static List<MembershipModel> presidentFirst(List<MembershipModel> all) => [
    for (final m in all)
      if (m.role == ClubRole.president) m,
    for (final m in all)
      if (m.role != ClubRole.president) m,
  ];

  /// Oturumdaki erişim kipi / üyelik değişti: state'e yazılır; kulübün içini
  /// görme hakkı değiştiyse kişi listeleri yeniden kurulur.
  void _onSession(ClubAccess access, MembershipModel? membership) {
    final sawInside = state.seesInside;
    state = state.copyWith(
      access: access,
      membership: membership,
      clearMembership: membership == null,
    );
    if (state.seesInside != sawInside) {
      unawaited(_loadPeople());
      unawaited(_loadEvents());
    }
  }

  /// Kulübü okur ve ilk yüklemeyi bitirir.
  Future<void> _load() async {
    if (!ref.mounted || _isLoading) return;
    _isLoading = true;
    final result = await clubRepository.getClub(clubId);
    _isLoading = false;
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess(:final data):
        state = state.copyWith(club: data, isFetching: false, isError: false);
        await (_loadPeople(), _loadEvents()).wait;
      case FirebaseFailure(:final error) when _missingErrors.contains(error):
        state = state.copyWith(isFetching: false, isNotFound: true);
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn('Kulüp okunamadı: ${error.name}', error: message);
        state = state.copyWith(isFetching: false, isError: true);
    }
  }

  /// Yönetim kurulunu ve üye önizlemesini okur. Yöneticiler doğrulanmış her
  /// kullanıcıya açıktır (Rules üyelik okuma dalı (d), CD-139); üye listesi
  /// yalnızca kulübün içini görene okunur — görmeyen kullanıcıda önizleme
  /// yöneticilerden kurulur ("+N" `memberCount`'tan gelir). Okuma hatası
  /// sayfayı bozmaz: önceki liste kalır.
  Future<void> _loadPeople() async {
    final inside = state.seesInside;
    final (managers, members) = await (
      membershipRepository.listManagers(clubId),
      inside
          ? membershipRepository.listActiveMembers(
              clubId,
              const PageRequest(limit: ClubDetailState.memberPreviewLimit),
            )
          : Future<FirestoreResult<PageResult<MembershipModel>>?>.value(),
    ).wait;
    // Okuma sürerken erişim kipi değişmiş olabilir (katıldı / ayrıldı): yeni
    // kipin okuması `_onSession`'dan ayrıca başlar.
    if (!ref.mounted || state.seesInside != inside) return;
    final board = switch (managers) {
      FirebaseSuccess(:final data) => presidentFirst(data),
      FirebaseFailure() => state.managers,
    };
    state = state.copyWith(
      managers: board,
      memberPreview: switch (members) {
        null => board.take(GuSizes.avatarGroupMax).toList(growable: false),
        FirebaseSuccess(:final data) => data.items,
        FirebaseFailure() => state.memberPreview,
      },
    );
  }

  /// Etkinlikleri ve kullanıcının bu kulüpteki katılım kayıtlarını okur
  /// ([fetchEvents]). Okuma hatası var olan listeyi silmez.
  Future<void> _loadEvents() async {
    final generation = ++_eventsGeneration;
    final inside = state.seesInside;
    final uid = ref.read(sessionViewModelProvider).uid;
    state = state.copyWith(isEventsFetching: true, isEventsError: false);
    final (events, rsvps) = await (
      eventRepository.listClubEvents(
        clubId,
        const PageRequest(),
        publicOnly: !inside,
      ),
      uid == null
          ? Future<FirestoreResult<List<RsvpModel>>?>.value()
          : rsvpRepository.listMine(uid),
    ).wait;
    if (!ref.mounted || generation != _eventsGeneration) return;
    if (rsvps case FirebaseFailure(:final error, :final message)) {
      AppLogger.warn(
        'Katılım kayıtları okunamadı: ${error.name}',
        error: message,
      );
    }
    switch (events) {
      case FirebaseSuccess(:final data):
        state = state.copyWith(
          events: data.items,
          rsvps: switch (rsvps) {
            FirebaseSuccess(:final data) => {
              for (final rsvp in data)
                if (rsvp.clubId == clubId) rsvp.eventId: rsvp,
            },
            _ => state.rsvps,
          },
          isEventsFetching: false,
        );
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Kulüp etkinlikleri okunamadı: ${error.name}',
          error: message,
        );
        state = state.copyWith(isEventsFetching: false, isEventsError: true);
    }
  }

  /// DLG-09 "Ayrılamazsın".
  Future<LeaveOutcome> _solePresident() async => await showSolePresidentDialog()
      ? LeaveOutcome.transferRequested
      : LeaveOutcome.solePresident;

  Future<JoinOutcome> _joinFailed(
    FirestoreError error,
    String? message,
    Object? detail,
    String Function(DateTime retryAfter) formatDate,
  ) async {
    final outcome = await joinRuleOutcome(
      error: error,
      detail: detail,
      membership: state.membership,
      formatDate: formatDate,
      reloadClub: () async {
        await refresh();
        return ref.mounted ? state.club : null;
      },
    );
    if (outcome != null) return outcome;
    if (!ref.mounted) return JoinOutcome.failed;
    if (_missingErrors.contains(error)) {
      state = state.copyWith(isNotFound: true);
      return JoinOutcome.failed;
    }
    _showWriteFailure(error, message, 'Kulübe katılınamadı');
    return JoinOutcome.failed;
  }

  /// Yazma hatalarının ortak bildirimi: ağ → TST-24, yetki → TST-X18;
  /// diğerleri günlüğe düşer ve kulüp yenilenir (ekran gerçek durumu
  /// gösterir).
  void _showWriteFailure(FirestoreError error, String? message, String what) {
    if (showWriteFailureToast(error)) return;
    AppLogger.warn('$what: ${error.name}', error: message);
    unawaited(refresh());
  }
}
