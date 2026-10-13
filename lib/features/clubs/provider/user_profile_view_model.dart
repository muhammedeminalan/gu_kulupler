import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/user_profile_state.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/report_reason_sheet.dart';
import 'package:gu_kulupler/product/mixin/block_user_mixin.dart';
import 'package:gu_kulupler/product/mixin/report_received_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_profile_view_model.g.dart';

/// CLB-07 "Profil" ekranının ViewModel'i (kullanıcı + açılış kulübü başına
/// bir örnek; PLAN §12.6, prototip `S['CLB-07']`, `screens-clubs.js:151–162`).
///
/// * Kullanıcıyı açılışta okur. Bakanın **aktif** üyesi olduğu her kulüp için
///   kullanıcının üyelik belgesine bakar (`membershipRepository
///   .getMembership`): ikisinin de aktif olduğu kulüpler ortak kulüplerdir.
///   Rules, bakanın göremeyeceği (ya da var olmayan) üyelik belgesini
///   `permission-denied` ile reddeder — bu "ortak değil" sayılır.
/// * **Gizlilik (D-29, S-1):** ortak kulüp yoksa ve bakan süper admin, açılış
///   kulübünün (`clubId`) yöneticisi (kullanıcının o kulüpte kaydı varken)
///   ya da kullanıcının kendisi değilse profil gizlidir
///   (`UserProfileState.isHiddenByPrivacy`). `users/{uid}` Rules'ta açıktır;
///   kural yalnızca arayüzde uygulanır.
/// * Engel durumu oturumdan gelir ve iyimser güncellenir; yazım oturumdaki
///   engel kümesine `SessionViewModel.setBlocked` ile yansır.
/// * Sheet açma ve gezinme view'dadır. Onay dialogları (DLG-13, DLG-12) ve
///   toast'lar buradan gösterilir.
///
/// | İşlem | Sonuç | Geri bildirim |
/// |---|---|---|
/// | [fetch] | belge yok / geçersiz kimlik | `isNotFound` (→ SYS-04) |
/// | | okunamadı (ağ dahil) | `isError` |
/// | [toggleBlock] | engelle: onay → yazıldı | DLG-13 → TST-09 ("Geri al") |
/// | | engeli kaldır: yazıldı | TST-09 ("Geri al") |
/// | [submitReport] → [showReportReceived] | yazıldı / zaten bildirilmiş | DLG-12 (→ DLG-13) |
/// | yazan her işlem | çevrimdışı / ağ · yetki yok | TST-24 · TST-X18 |
///
/// Design: CLB-07
@riverpod
final class UserProfileViewModel extends _$UserProfileViewModel
    with
        ProjectDependencyMixin,
        WriteGuardMixin,
        BlockUserMixin,
        ReportReceivedMixin {
  bool _isLoading = false;

  /// Oturum; TST-09 "Geri al" ekran kapandıktan sonra da gelebildiği için
  /// engel işlemi başlarken alınır (`ref` kapanınca okunamaz).
  SessionViewModel? _session;

  @override
  UserProfileState build(String userId, {String? clubId}) {
    // Oturumdaki engel kümesi değişince (yazım sonrası yenileme, başka
    // ekrandaki engelleme) state eşitlenir; oturumun başka alanlarındaki
    // değişiklik iyimser değeri ezmez.
    ref.listen(sessionViewModelProvider, (previous, session) {
      final isBlocked = session.isBlocked(userId);
      if (previous?.isBlocked(userId) == isBlocked) return;
      if (isBlocked != state.isBlocked) {
        state = state.copyWith(isBlocked: isBlocked);
      }
    });
    // Kullanıcı ilk karede okunmaya başlar; view ayrıca çağırmaz.
    unawaited(Future<void>.microtask(_load));
    final session = ref.read(sessionViewModelProvider);
    return UserProfileState(
      isSelf: session.uid == userId,
      isBlocked: session.isBlocked(userId),
      isFetching: true,
    );
  }

  /// Şikayet hedefi: bu kullanıcı (SHT-10; kullanıcı hedefinde kulüp yok).
  ReportTarget get reportTarget =>
      (type: ReportTargetType.user, id: userId, clubId: null);

  @override
  String? get blockerId =>
      ref.mounted ? ref.read(sessionViewModelProvider).uid : null;

  @override
  void onBlockChanged(String userId, {required bool isBlocked}) {
    if (!ref.mounted || userId != this.userId) return;
    state = state.copyWith(isBlocked: isBlocked);
  }

  /// Yazım oturumdaki engel kümesine anında yansıtılır (SHT-27 satırı, CLB-06
  /// süzgeci, akış): `SessionViewModel.setBlocked`.
  @override
  void onBlockSaved(String userId, {required bool isBlocked}) =>
      _session?.setBlocked(userId, isBlocked: isBlocked);

  /// Kullanıcıyı yeniden okur — hata görünümündeki "Yeniden dene". Süren
  /// okuma varken gelen çağrı yok sayılır.
  Future<void> fetch() async {
    if (!ref.mounted || _isLoading) return;
    state = state.copyWith(isFetching: true, isError: false, isNotFound: false);
    await _load();
  }

  /// "Engelle" / "Engeli kaldır" (SHT-27 `SHT-27.block`, bant
  /// `CLB-07.unblock`): engelliyse engeli kaldırır
  /// (`blockRepository.softDeleteBlock`), değilse DLG-13 onayıyla engeller
  /// (`blockRepository.block`). İkisi de TST-09'u "Geri al" ile gösterir;
  /// yazım, onay ve geri alma `BlockUserMixin`'dedir.
  ///
  /// Kullanıcı okunmadıysa, kendisiyse ya da süren bir işlem varsa etkisizdir.
  Future<void> toggleBlock() async {
    final user = state.user;
    if (user == null || state.isSelf || state.isActing) return;
    _session = ref.read(sessionViewModelProvider.notifier);
    state = state.copyWith(isActing: true);
    if (state.isBlocked) {
      await unblockUser(userId: userId, name: user.name);
    } else {
      await blockUser(userId: userId, name: user.name);
    }
    if (ref.mounted) state = state.copyWith(isActing: false);
  }

  /// SHT-10'da doğrulanan şikayeti yazar (`ReportReceivedMixin.sendReport`).
  /// `true` → sheet kapanır ve view [showReportReceived] çağırır; aynı
  /// kullanıcı daha önce bildirilmişse de `true` (DLG-12 yine gösterilir).
  /// `false` → sheet açık kalır: çevrimdışı / ağ (TST-24), yetki yok
  /// (TST-X18), beklenmeyen hata.
  Future<bool> submitReport(ReportReasonResult report) => sendReport(
    reporterId: ref.read(sessionViewModelProvider).uid,
    report: report,
  );

  /// DLG-12 "Şikayetin alındı". Kullanıcı henüz engelli değilse altında
  /// "{ad} kullanıcısını da engelle" çizilir; seçilirse engelleme onayı
  /// (DLG-13) açılır (`dialogs.js:28`).
  Future<void> showReportReceived() async {
    final user = state.user;
    final canBlock = user != null && !state.isSelf && !state.isBlocked;
    final wantsBlock = await showReportReceivedDialog(
      blockableUserName: canBlock ? user.name : null,
    );
    if (wantsBlock && ref.mounted) await toggleBlock();
  }

  static bool _isNetwork(FirestoreError error) =>
      WriteGuardMixin.networkErrors.contains(error);

  /// Kullanıcıyı ve bakanla ilişkisini okur; ilk yüklemeyi bitirir.
  Future<void> _load() async {
    if (!ref.mounted || _isLoading) return;
    _isLoading = true;
    try {
      final result = await userRepository.getUser(userId);
      if (!ref.mounted) return;
      switch (result) {
        // Belge yok ya da kimlik geçersiz (bozuk bağlantı) → SYS-04.
        case FirebaseSuccess(data: null):
        case FirebaseFailure(error: FirestoreError.invalidArgument):
          state = state.copyWith(isFetching: false, isNotFound: true);
        case FirebaseFailure(:final error, :final message):
          AppLogger.warn('Kullanıcı okunamadı: ${error.name}', error: message);
          state = state.copyWith(isFetching: false, isError: true);
        case FirebaseSuccess(data: final user?):
          await _loadRelations(user);
      }
    } finally {
      _isLoading = false;
    }
  }

  /// Ortak kulüpleri, rolleri ve açılış kulübündeki üyeliği okur; gizlilik
  /// kararını verir (prototip `visible`, `screens-clubs.js:153`).
  Future<void> _loadRelations(UserModel user) async {
    final session = ref.read(sessionViewModelProvider);
    final isSelf = session.uid == userId;
    final contextClubId = clubId;
    final managesContext =
        contextClubId != null &&
        switch (session.accessTo(contextClubId)) {
          ClubAccess.manager || ClubAccess.superAdmin => true,
          _ => false,
        };
    final mine = [
      for (final membership in session.memberships.values)
        if (membership.isActiveMember) membership,
    ];

    // Silinmiş kullanıcının ilişkileri okunmaz: yalnızca adı gösterilir.
    if (user.isDeleted || user.isAnonymized) {
      state = state.copyWith(
        user: user,
        sharedClubIds: const [],
        sharedClubs: const [],
        roles: const [],
        clearContextMembership: true,
        isSelf: isSelf,
        isSuperAdmin: false,
        isHiddenByPrivacy: false,
        isFetching: false,
        isError: false,
      );
      return;
    }

    // Kulüp → kullanıcının o kulüpteki üyeliği (yoksa / görülemiyorsa yok).
    final theirs = <String, MembershipModel>{};
    if (isSelf) {
      for (final membership in mine) {
        theirs[membership.clubId] = membership;
      }
    } else {
      final clubIds = {
        for (final membership in mine) membership.clubId,
        if (managesContext) contextClubId,
      }.toList(growable: false);
      final results = await [
        for (final id in clubIds)
          membershipRepository.getMembership(id, userId),
      ].wait;
      if (!ref.mounted) return;
      for (final (index, result) in results.indexed) {
        switch (result) {
          case FirebaseSuccess(:final data):
            if (data != null && !data.isDeleted) theirs[clubIds[index]] = data;
          // Bağlantı hatasında gizlilik kararı verilemez: hata durumu.
          case FirebaseFailure(:final error, :final message)
              when _isNetwork(error):
            AppLogger.warn('Üyelik okunamadı: ${error.name}', error: message);
            state = state.copyWith(isFetching: false, isError: true);
            return;
          // Rules, bakanın göremediği (ya da olmayan) belgeyi reddeder:
          // ortak değil.
          case FirebaseFailure():
            break;
        }
      }
    }

    final shared = [
      for (final membership in mine)
        if (theirs[membership.clubId] case final theirMembership?
            when theirMembership.isActiveMember)
          theirMembership,
    ];
    final contextMembership = managesContext && !isSelf
        ? theirs[contextClubId]
        : null;
    final isHidden =
        shared.isEmpty &&
        contextMembership == null &&
        !session.isSuperAdmin &&
        !isSelf;
    final sharedClubIds = [for (final membership in shared) membership.clubId];

    var sharedClubs = const <ClubModel>[];
    if (sharedClubIds.isNotEmpty) {
      final result = await clubRepository.getClubs(sharedClubIds);
      if (!ref.mounted) return;
      switch (result) {
        case FirebaseSuccess(:final data):
          sharedClubs = data;
        case FirebaseFailure(:final error, :final message):
          // Çipler çizilemez; profil yine görünür.
          AppLogger.warn(
            'Ortak kulüpler okunamadı: ${error.name}',
            error: message,
          );
      }
    }

    state = state.copyWith(
      user: user,
      sharedClubIds: sharedClubIds,
      sharedClubs: sharedClubs,
      roles: [
        for (final membership in shared)
          if (membership.role != ClubRole.member) membership.role,
      ],
      contextMembership: contextMembership,
      clearContextMembership: contextMembership == null,
      isSelf: isSelf,
      isSuperAdmin: isSelf && session.isSuperAdmin,
      isHiddenByPrivacy: isHidden,
      isFetching: false,
      isError: false,
    );
  }
}
