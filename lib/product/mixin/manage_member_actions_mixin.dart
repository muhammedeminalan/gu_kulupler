import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/member_actions_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/president_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/role_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/dialogs/remove_member_dialog.dart';
import 'package:gu_kulupler/product/feedback/dialogs/transfer_presidency_dialog.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';

/// SHT-21 menüsünden sonra view'a düşen iş.
enum MemberMenuOutcome {
  /// Yapılacak bir şey yok (kapatıldı, vazgeçildi, yazıldı ya da yazılamadı).
  none,

  /// "Profili gör": view CLB-07'yi kulüp bağlamıyla açar.
  viewProfile,

  /// Üye çıkarıldı (TST-47 gösterildi): CLB-07 önceki sayfaya döner.
  removed,
}

/// Üye yönetimi akışlarının **tek yeri** (domain-model §5 hiyerarşi; PLAN
/// §12.6 `ManageMembersViewModel`): SHT-21 üye işlemleri, SHT-22 → DLG-20
/// rol değiştirme, DLG-19 çıkarma (+ TST-47 "Geri al"), SHT-25 → DLG-21
/// başkanlık devri ve yönetici kartındaki e-posta kopyalama (TST-08).
/// MGT-03, CLB-06 (W-20), CLB-07 (W-69), CLB-03 / PRF-03 DLG-09 (W-14) ve
/// SET-03 (W-34) ViewModel'leri kullanır; feature'da kopyası yoktur.
///
/// | Akış | Sonuç | Geri bildirim |
/// |---|---|---|
/// | yetki yok (hiyerarşi, `RolePolicy`) | yazım yok | TST-X18 |
/// | danışman / çevrimdışı | yazım yok | TST-26 / TST-24 |
/// | [changeMemberRole] | SHT-22 → DLG-20 → yazıldı | rozet iyimser; TST-46 |
/// | [removeMember] | DLG-19 → yazıldı | satır iyimser düşer; TST-47 "Geri al" → [undoMemberRemoval] |
/// | [transferPresidency] | SHT-25 → DLG-21 ("DEVRET") → yazıldı | TST-49 |
/// | yazılamadı | iyimser değişiklik geri alınır | TST-24 · TST-X18; çakışmada liste yenilenir ([onMemberListStale]) |
///
/// Sheet ve dialoglar `FeedbackService` ile buradan açılır; gezinme
/// view'dadır ([MemberMenuOutcome]). TST-47 ekrandan uzun yaşar: "Geri al"
/// ViewModel kapandıktan sonra da gelebilir; mixin o yolda yalnızca GetIt
/// bağımlılıklarını ve yakaladığı değerleri kullanır, tüketici kancalarda
/// `ref.mounted` denetler.
///
/// ```dart
/// final class ClubMembersViewModel extends _$ClubMembersViewModel
///     with ProjectDependencyMixin, WriteGuardMixin, ManageMemberActionsMixin {
///   @override
///   SessionState? get memberSession =>
///       ref.mounted ? ref.read(sessionViewModelProvider) : null;
///
///   @override
///   void onMemberRemoved(MembershipModel membership) { … }
/// }
/// ```
///
/// Design: DLG-20
mixin ManageMemberActionsMixin on ProjectDependencyMixin, WriteGuardMixin {
  /// Süren üye yazımları (`userId`): çift dokunuş ikinci yazımı başlatmaz.
  final Set<String> _busyMembers = <String>{};

  // ───────────────────────── tüketicinin verdikleri ─────────────────────────

  /// Oturum (aktörün kimliği, kulüpteki rolü, süper admin bayrağı); ViewModel
  /// kapandıysa `null` (hiçbir şey yazılmaz).
  SessionState? get memberSession;

  /// [membership] iyimser olarak kaldırıldı (DLG-19 onayı): tüketici satırı
  /// listeden düşürür.
  void onMemberRemoved(MembershipModel membership) {}

  /// [membership] geri geldi: çıkarma yazılamadı ya da TST-47 "Geri al".
  /// Tüketici satırı eski yerine koyar.
  void onMemberRestored(MembershipModel membership) {}

  /// [membership] rolü değişti (yeni rolüyle; yazılamazsa eski rolüyle
  /// yeniden çağrılır).
  void onMemberRoleChanged(MembershipModel membership) {}

  /// [clubId] başkanlığı [fromUserId]'den [toUserId]'ye devredildi (eski
  /// başkan yönetim kurulunda).
  void onPresidencyTransferred(
    String clubId, {
    required String fromUserId,
    required String toUserId,
  }) {}

  /// Sunucudaki üyelik durumu ekrandakinden farklı (çakışma): tüketici
  /// listeyi yeniden okur.
  void onMemberListStale(String clubId) {}

  /// SHT-25 satırı [membership] için: varsayılan üyelikteki anlık görüntü
  /// (D-29); güncel kullanıcı belgesini okumuş tüketici onu verir.
  PresidentCandidate memberCandidateOf(MembershipModel membership) =>
      PresidentCandidate.fromMembership(membership);

  // ──────────────────────────────── yetki ───────────────────────────────────

  /// Aktörün kimliği; oturum yoksa `null`.
  String? get memberActorId => memberSession?.uid;

  /// Aktörün [clubId] kulübündeki etkin rolü.
  ClubRole? memberActorRoleIn(String clubId) => memberSession?.roleIn(clubId);

  /// Aktör süper admin mi.
  bool get memberActorIsSuper => memberSession?.isSuperAdmin ?? false;

  /// SHT-21 satır menüsü ("⋮") [membership] için çizilir mi
  /// (`MemberActionsSheet.canOpen`).
  bool canOpenMemberMenu(String clubId, MembershipModel membership) =>
      MemberActionsSheet.canOpen(
        actorRole: memberActorRoleIn(clubId),
        targetRole: membership.role,
        isSuperAdmin: memberActorIsSuper,
      );

  /// Aktör [membership] üyesinin rolünü değiştirebilir mi (başkan / süper
  /// admin; `member` ↔ `board`; kendine değil).
  bool canChangeMemberRole(String clubId, MembershipModel membership) =>
      membership.userId != memberActorId &&
      RolePolicy.canAssignRole(
        memberActorRoleIn(clubId),
        membership.role,
        membership.role == ClubRole.member ? ClubRole.board : ClubRole.member,
        isSuper: memberActorIsSuper,
      );

  /// Aktör [membership] üyesini çıkarabilir mi (yönetim kurulu yalnızca
  /// `member`; başkan / süper admin `member` ve `board`; kendini değil).
  bool canRemoveMember(String clubId, MembershipModel membership) =>
      membership.userId != memberActorId &&
      RolePolicy.canRemove(
        memberActorRoleIn(clubId),
        membership.role,
        isSuper: memberActorIsSuper,
      );

  /// Aktör [clubId] başkanlığını devredebilir mi (başkan / süper admin).
  bool canTransferPresidency(String clubId) => RolePolicy.can(
    ClubPermission.transferPresidency,
    memberActorRoleIn(clubId),
    isSuper: memberActorIsSuper,
  );

  /// Yazmadan önce: danışman → TST-26, çevrimdışı → TST-24 (prototip
  /// `app.guard`). `false` → çağıran hiçbir şey yazmaz.
  bool ensureMemberWritable(String clubId) {
    if (memberSession?.accessTo(clubId) == ClubAccess.advisor) {
      feedback.showToast(ToastId.tst26);
      return false;
    }
    return ensureOnline();
  }

  // ──────────────────────────────── akışlar ─────────────────────────────────

  /// SHT-21 "Üye işlemleri" ([name] başlıkta). "Rolü değiştir" →
  /// [changeMemberRole], "Üyelikten çıkar" → [removeMember]; "Profili gör"
  /// view'a döner. Menü bu hedef için açılamıyorsa TST-X18.
  Future<MemberMenuOutcome> openMemberActions(
    String clubId,
    MembershipModel membership, {
    required String name,
  }) async {
    final session = memberSession;
    if (session == null) return MemberMenuOutcome.none;
    if (!canOpenMemberMenu(clubId, membership)) {
      feedback.showToast(ToastId.tstX18);
      return MemberMenuOutcome.none;
    }
    final action = await feedback.showSheet<MemberAction>(
      SheetId.sht21,
      builder: (_) => MemberActionsSheet(
        membership: membership,
        actorRole: session.roleIn(clubId),
        isSuperAdmin: session.isSuperAdmin,
        isSelf: membership.userId == session.uid,
        userName: name,
      ),
    );
    switch (action) {
      case null:
        return MemberMenuOutcome.none;
      case MemberAction.viewProfile:
        return MemberMenuOutcome.viewProfile;
      case MemberAction.changeRole:
        await changeMemberRole(clubId, membership, name: name);
        return MemberMenuOutcome.none;
      case MemberAction.remove:
        return await removeMember(clubId, membership, name: name)
            ? MemberMenuOutcome.removed
            : MemberMenuOutcome.none;
    }
  }

  /// SHT-22 → DLG-20 → M10 `changeRole` → TST-46. Rozet iyimser değişir
  /// ([onMemberRoleChanged]); yazılamazsa eski role döner. Yazıldıysa `true`.
  Future<bool> changeMemberRole(
    String clubId,
    MembershipModel membership, {
    required String name,
  }) async {
    final actorId = memberActorId;
    if (actorId == null || _busyMembers.contains(membership.userId)) {
      return false;
    }
    if (!canChangeMemberRole(clubId, membership)) {
      feedback.showToast(ToastId.tstX18);
      return false;
    }
    final role = await feedback.showSheet<ClubRole>(
      SheetId.sht22,
      builder: (_) => RolePickerSheet(currentRole: membership.role),
    );
    if (role == null || role == membership.role) return false;
    final confirmed =
        await feedback.showDialog<bool>(
          DialogId.dlg20,
          params: {
            DialogParamKeys.name: name,
            DialogParamKeys.oldRole: membership.role,
            DialogParamKeys.newRole: role,
          },
        ) ??
        false;
    if (!confirmed || !ensureMemberWritable(clubId)) return false;
    _busyMembers.add(membership.userId);
    onMemberRoleChanged(membership.copyWith(role: role));
    final result = await managementRepository.changeRole(
      clubId: clubId,
      userId: membership.userId,
      role: role,
      actorId: actorId,
    );
    _busyMembers.remove(membership.userId);
    switch (result) {
      case FirebaseSuccess():
        feedback.showToast(
          ToastId.tst46,
          params: ToastParams(name: name, role: role.json),
        );
        return true;
      case FirebaseFailure(:final error):
        onMemberRoleChanged(membership);
        _reportFailure(clubId, error, 'Üyenin rolü değiştirilemedi');
        return false;
    }
  }

  /// DLG-19 (isteğe bağlı neden) → M9 `removeMember` → TST-47 "Geri al".
  /// Satır iyimser düşer ([onMemberRemoved]); yazılamazsa geri gelir.
  /// Yazıldıysa `true`.
  Future<bool> removeMember(
    String clubId,
    MembershipModel membership, {
    required String name,
  }) async {
    final actorId = memberActorId;
    if (actorId == null || _busyMembers.contains(membership.userId)) {
      return false;
    }
    if (!canRemoveMember(clubId, membership)) {
      feedback.showToast(ToastId.tstX18);
      return false;
    }
    final actorRole = memberActorRoleIn(clubId);
    final actorIsSuper = memberActorIsSuper;
    final reason = await RemoveMemberDialog.show(feedback, name: name);
    if (reason == null || !ensureMemberWritable(clubId)) return false;
    _busyMembers.add(membership.userId);
    onMemberRemoved(membership);
    final result = await managementRepository.removeMember(
      clubId: clubId,
      userId: membership.userId,
      actorId: actorId,
      // Rol yalnızca süper adminde boş kalır (Rules süper dalı rol istemez).
      actorRole: actorRole ?? ClubRole.member,
      actorIsSuper: actorIsSuper,
      rejectNote: reason,
    );
    _busyMembers.remove(membership.userId);
    switch (result) {
      case FirebaseSuccess():
        feedback.showToast(
          ToastId.tst47,
          params: ToastParams(name: name),
          onAction: () => unawaited(
            undoMemberRemoval(clubId, membership, actorId: actorId),
          ),
        );
        return true;
      case FirebaseFailure(:final error):
        onMemberRestored(membership);
        _reportFailure(clubId, error, 'Üye çıkarılamadı');
        return false;
    }
  }

  /// TST-47 "Geri al" — M12 (b) `undoRemoval` (`Limits.managerUndoWindow`
  /// içinde, çıkaranın kendisi). Satır `member` rolüyle geri gelir
  /// (repository sözleşmesi; [onMemberRestored]); pencere dolmuşsa ya da
  /// yazılamazsa liste yenilenir.
  Future<bool> undoMemberRemoval(
    String clubId,
    MembershipModel membership, {
    required String actorId,
  }) async {
    if (!ensureOnline()) return false;
    final result = await managementRepository.undoRemoval(
      clubId: clubId,
      userId: membership.userId,
      actorId: actorId,
    );
    switch (result) {
      case FirebaseSuccess():
        onMemberRestored(membership.copyWith(role: ClubRole.member));
        return true;
      case FirebaseFailure(:final error):
        _reportFailure(clubId, error, 'Çıkarma geri alınamadı');
        return false;
    }
  }

  /// SHT-25 (devir kipi) → DLG-21 ("DEVRET") → M11 `transferPresidency` →
  /// TST-49. Adaylar [members] verilmezse kulübün aktif üyelerinden okunur
  /// ([loadTransferCandidates]). [fromUserId] mevcut başkandır; verilmezse
  /// aktör (başkanın kendisi). Devredildiyse `true`.
  Future<bool> transferPresidency(
    String clubId, {
    Iterable<MembershipModel>? members,
    String? fromUserId,
  }) async {
    final actorId = memberActorId;
    if (actorId == null || _busyMembers.contains(clubId)) return false;
    if (!canTransferPresidency(clubId)) {
      feedback.showToast(ToastId.tstX18);
      return false;
    }
    final pool = members?.toList() ?? await loadTransferCandidates(clubId);
    if (pool == null) return false;
    final candidates = PresidentPickerSheet.transferCandidates([
      for (final m in pool)
        if (m.userId != actorId && m.userId != fromUserId) m,
    ], candidateOf: memberCandidateOf);
    final toUserId = await feedback.showSheet<String>(
      SheetId.sht25,
      builder: (_) => PresidentPickerSheet(candidates: candidates),
    );
    final target = [
      for (final c in candidates)
        if (c.userId == toUserId) c,
    ].firstOrNull;
    if (target == null) return false;
    final confirmed = await TransferPresidencyDialog.show(
      feedback,
      name: target.name,
    );
    if (!confirmed || !ensureMemberWritable(clubId)) return false;
    final from = fromUserId ?? actorId;
    _busyMembers.add(clubId);
    final result = await managementRepository.transferPresidency(
      clubId: clubId,
      fromUserId: from,
      toUserId: target.userId,
      actorId: actorId,
    );
    _busyMembers.remove(clubId);
    switch (result) {
      case FirebaseSuccess():
        feedback.showToast(
          ToastId.tst49,
          params: ToastParams(name: target.name),
        );
        onPresidencyTransferred(
          clubId,
          fromUserId: from,
          toUserId: target.userId,
        );
        return true;
      case FirebaseFailure(:final error):
        _reportFailure(clubId, error, 'Başkanlık devredilemedi');
        return false;
    }
  }

  /// [clubId] kulübünün bütün aktif üyeleri (sayfa sayfa; SHT-25 adayları).
  /// Okunamazsa TST-24 / TST-X18 gösterir ve `null` döner.
  Future<List<MembershipModel>?> loadTransferCandidates(String clubId) async {
    final all = <MembershipModel>[];
    PageCursor? after;
    do {
      final result = await membershipRepository.listActiveMembers(
        clubId,
        PageRequest(after: after),
      );
      switch (result) {
        case FirebaseSuccess(:final data):
          all.addAll(data.items);
          after = data.next;
        case FirebaseFailure(:final error, :final message):
          AppLogger.warn(
            'Devir adayları okunamadı: ${error.name}',
            error: message,
          );
          if (!showWriteFailureToast(error)) {
            feedback.showToast(ToastId.tst24);
          }
          return null;
      }
    } while (after != null);
    return all;
  }

  /// Yönetici kartı / SHT e-posta "Kopyala": [email] panoya → TST-08. Boşsa
  /// hiçbir şey yapmaz.
  Future<bool> copyMemberEmail(String email) async {
    final text = email.trim();
    if (text.isEmpty) return false;
    if (!await shareService.copyText(text)) return false;
    feedback.showToast(ToastId.tst08);
    return true;
  }

  /// Yazma hatası: ağ → TST-24, yetki yok → TST-X18; çakışma (durum başka
  /// yerde değişmiş) ve başka hata → TST-X18 + liste yenilenir.
  void _reportFailure(String clubId, FirestoreError error, String what) {
    if (showWriteFailureToast(error)) return;
    AppLogger.warn('$what: ${error.name}');
    feedback.showToast(ToastId.tstX18);
    onMemberListStale(clubId);
  }
}
