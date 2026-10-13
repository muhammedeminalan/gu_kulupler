import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';

/// TST-09 "Geri al" ile geri alınabilecek son engel değişikliği
/// (`ClubMembersState.pendingUndo`).
final class BlockUndo extends Equatable {
  /// [userId] için yapılan değişiklik; [unblocked] `true` → engel kaldırıldı
  /// (geri al = `restoreBlock`), `false` → engellendi (geri al =
  /// `softDeleteBlock`).
  const BlockUndo({
    required this.userId,
    required this.name,
    this.unblocked = false,
  });

  /// Engellenen / engeli kaldırılan kullanıcı.
  final String userId;

  /// Toast metnindeki ad.
  final String name;

  /// Engel kaldırıldı mı (değilse engellendi).
  final bool unblocked;

  @override
  List<Object?> get props => [userId, name, unblocked];
}

/// Bir ekranda yapılan, oturuma henüz yansımamış engel değişiklikleri
/// (kimlik → engelli mi). Engellenenler oturumdan gelir
/// (`SessionState.blockedUserIds`); ekran iyimser değişikliği burada tutar ve
/// listesini [applyTo] ile süzer (CLB-06, FED-01, FED-02).
///
/// ```dart
/// void onBlockChanged(String userId, {required bool isBlocked}) {
///   _blocks.mark(userId, isBlocked: isBlocked);
///   state = state.copyWith(blockedUserIds: _blocks.applyTo(sessionBlocks));
/// }
///
/// void onBlockSaved(String userId, {required bool isBlocked}) {
///   session.setBlocked(userId, isBlocked: isBlocked);
///   _blocks.settle(userId);
/// }
/// ```
final class BlockOverrides {
  final Map<String, bool> _changes = <String, bool>{};

  /// [userId] bu ekranda engellendi / engeli kaldırıldı (iyimser).
  void mark(String userId, {required bool isBlocked}) =>
      _changes[userId] = isBlocked;

  /// [userId] değişikliği oturuma işlendi: yerel kayıt artık gerekmez.
  void settle(String userId) => _changes.remove(userId);

  /// Oturumdaki [session] kümesine bu ekrandaki değişiklikler uygulanmış
  /// engel kümesi.
  Set<String> applyTo(Set<String> session) => {
    for (final userId in session)
      if (_changes[userId] ?? true) userId,
    for (final MapEntry(:key, :value) in _changes.entries)
      if (value) key,
  };
}

/// Kullanıcı engelleme akışının ortak çekirdeği — SHT-27 "Engelle" /
/// "Engeli kaldır" satırı olan her ViewModel (CLB-06 `ClubMembersViewModel`,
/// CLB-07 `UserProfileViewModel`; ileride SHT-09, SET-02, ADM-05) aynı
/// onayı, yazımı ve toast'ı buradan alır (prototip `sheets.js:132`,
/// `dialogs.js:29`).
///
/// | İşlem | Yazım | Geri bildirim | "Geri al" |
/// |---|---|---|---|
/// | [blockUser] | DLG-13 onayı → `block` | TST-09 "… engellendi." | `softDeleteBlock` |
/// | [unblockUser] | `softDeleteBlock` (onaysız) | TST-09 "… için engel kaldırıldı." | `restoreBlock` |
/// | yazma hatası | iyimser değişiklik geri alınır | ağ → TST-24 · yetki → TST-X18 | — |
///
/// Kendi kendini engelleme yoktur (`userId == blockerId` → `false`, hiçbir
/// şey sorulmaz). Çevrimdışıyken hiçbir şey yazılmaz
/// (`WriteGuardMixin.ensureOnline`, TST-24). Süren bir engel işlemi varken
/// gelen çağrı yok sayılır.
///
/// Tüketici `WriteGuardMixin`'i bu mixin'den **önce** karıştırır ve iki üyeyi
/// verir; [onBlockSaved] isteğe bağlıdır:
///
/// ```dart
/// final class ClubMembersViewModel extends _$ClubMembersViewModel
///     with ProjectDependencyMixin, WriteGuardMixin, BlockUserMixin {
///   @override
///   String? get blockerId => ref.read(sessionViewModelProvider).uid;
///
///   @override
///   void onBlockChanged(String userId, {required bool isBlocked}) { … }
/// }
/// ```
///
/// TST-09 ekrandan uzun yaşar: "Geri al" ViewModel kapandıktan sonra da
/// gelebilir. Mixin o yolda yalnızca GetIt bağımlılıklarını kullanır;
/// tüketici [onBlockChanged] / [onBlockSaved] içinde `ref.mounted` denetler.
///
/// Design: DLG-13
mixin BlockUserMixin on ProjectDependencyMixin, WriteGuardMixin {
  bool _isChangingBlock = false;

  /// Engelleyen: oturumdaki kullanıcı; oturum yoksa `null` (hiçbir şey
  /// yazılmaz).
  String? get blockerId;

  /// [userId] için engel durumu değişti. İyimser çağrılır (yazmadan önce);
  /// yazma başarısızsa ya da "Geri al" seçilirse ters değerle yeniden
  /// çağrılır. Tüketici kendi state'ini burada günceller.
  void onBlockChanged(String userId, {required bool isBlocked});

  /// [userId] için engel yazımı (ya da geri alınması) sunucuya işlendi;
  /// [isBlocked] yazılan durumdur. Varsayılan etkisizdir: tüketici oturumdaki
  /// engel kümesini burada eşitler (`SessionViewModel.setBlocked`).
  void onBlockSaved(String userId, {required bool isBlocked}) {}

  /// DLG-13 "{name} engellensin mi?" → onaylanırsa
  /// `blockRepository.block` → TST-09 ("Geri al" → `softDeleteBlock`).
  ///
  /// `true` → engel yazıldı. `false` → vazgeçildi, oturum yok, kullanıcının
  /// kendisi, çevrimdışı (TST-24) ya da yazma hatası (iyimser değişiklik geri
  /// alınır).
  Future<bool> blockUser({
    required String userId,
    required String name,
  }) async {
    final uid = blockerId;
    if (uid == null || uid == userId || _isChangingBlock) return false;
    _isChangingBlock = true;
    try {
      final confirmed =
          await feedback.showDialog<bool>(
            DialogId.dlg13,
            params: {DialogParamKeys.name: name},
          ) ??
          false;
      if (!confirmed || !ensureOnline()) return false;
      return await _save(BlockUndo(userId: userId, name: name), uid);
    } finally {
      _isChangingBlock = false;
    }
  }

  /// Engeli kaldırır: `blockRepository.softDeleteBlock` → TST-09
  /// (`unblocked`; "Geri al" → `restoreBlock`). Onay sorulmaz
  /// (`sheets.js:132`).
  ///
  /// `true` → engel kaldırıldı. `false` → oturum yok, çevrimdışı (TST-24) ya
  /// da yazma hatası (iyimser değişiklik geri alınır).
  Future<bool> unblockUser({
    required String userId,
    required String name,
  }) async {
    final uid = blockerId;
    if (uid == null || uid == userId || _isChangingBlock) return false;
    if (!ensureOnline()) return false;
    _isChangingBlock = true;
    try {
      return await _save(
        BlockUndo(userId: userId, name: name, unblocked: true),
        uid,
      );
    } finally {
      _isChangingBlock = false;
    }
  }

  /// [change] değişikliğini iyimser uygular, yazar ve TST-09'u gösterir.
  Future<bool> _save(BlockUndo change, String uid) async {
    final isBlocked = !change.unblocked;
    onBlockChanged(change.userId, isBlocked: isBlocked);
    final result = isBlocked
        ? await blockRepository.block(blockerId: uid, blockedId: change.userId)
        : await blockRepository.softDeleteBlock(
            blockerId: uid,
            blockedId: change.userId,
          );
    if (result case FirebaseFailure(:final error, :final message)) {
      onBlockChanged(change.userId, isBlocked: !isBlocked);
      _showBlockFailure(error, message);
      return false;
    }
    onBlockSaved(change.userId, isBlocked: isBlocked);
    feedback.showToast(
      ToastId.tst09,
      params: ToastParams(name: change.name, unblocked: change.unblocked),
      onAction: () => unawaited(_undo(change, uid)),
    );
    return true;
  }

  /// TST-09 "Geri al": [change] değişikliğini tersine çevirir — engelleme
  /// geri alınıyorsa kayıt silinmiş olarak işaretlenir (`softDeleteBlock`),
  /// engel kaldırma geri alınıyorsa kayıt geri yüklenir (`restoreBlock`).
  Future<void> _undo(BlockUndo change, String uid) async {
    if (!ensureOnline()) return;
    final isBlocked = change.unblocked;
    onBlockChanged(change.userId, isBlocked: isBlocked);
    final result = isBlocked
        ? await blockRepository.restoreBlock(
            blockerId: uid,
            blockedId: change.userId,
          )
        : await blockRepository.softDeleteBlock(
            blockerId: uid,
            blockedId: change.userId,
          );
    if (result case FirebaseFailure(:final error, :final message)) {
      onBlockChanged(change.userId, isBlocked: !isBlocked);
      _showBlockFailure(error, message);
      return;
    }
    onBlockSaved(change.userId, isBlocked: isBlocked);
  }

  /// Yazma hatasının bildirimi: ağ → TST-24, yetki yok → TST-X18
  /// (`WriteGuardMixin.showWriteFailureToast`); diğerleri günlüğe düşer.
  void _showBlockFailure(FirestoreError error, String? message) {
    if (showWriteFailureToast(error)) return;
    AppLogger.warn('Engel yazılamadı: ${error.name}', error: message);
  }
}
