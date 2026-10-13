// `BlockRepository` fake'i (PLAN §16.3): engel kayıtlarını bellekte tutar.
//
//   final blocks = FakeBlockRepository();
//   await blocks.block(blockerId: 'u1', blockedId: 'u2');
//   expect(blocks.blocks.values.single.isDeleted, isFalse);
//
// Gerçek repository gibi: engeli kaldırmak kaydı silmez, silinmiş olarak
// işaretler (D-10); yeniden engelleme aynı kaydı geri yükler; yürürlükteki
// engelin yeniden engellenmesi yazımsız başarıdır; olmayan kaydın
// kaldırılması / geri yüklenmesi `notFound`; kendini engelleme ve geçersiz
// kimlik `invalidArgument`.
import 'dart:async';

import 'package:gu_data/gu_data.dart';

import 'fake_base.dart';

final class FakeBlockRepository extends FakeBase implements BlockRepository {
  /// `blocks/{blockerId}_{blockedId}` belgeleri (anahtar = belge kimliği;
  /// kaldırılmış engeller `isDeleted` ile durur). Test ön veriyi [put] ile
  /// yazar.
  final Map<String, BlockModel> blocks = <String, BlockModel>{};

  /// Verilirse [fetchActiveBlocks] sonuç dönmeden önce bunu bekler: okuma
  /// sürerken araya giren olayların (yarış) sırası testte elle kurulur.
  Completer<void>? fetchActiveBlocksGate;

  /// [blockerId] adına [blockedId] için yürürlükte bir engel kurar.
  void put(String blockerId, String blockedId) =>
      blocks[_key(
        blockerId,
        blockedId,
      )] = BlockModel(
        blockerId: blockerId,
        blockedId: blockedId,
      );

  @override
  Future<FirestoreResult<Set<String>>> fetchActiveBlocks(
    String blockerId,
  ) async {
    record('fetchActiveBlocks', [blockerId]);
    // Bekleyen hata ve sonuç çağrı anında alınır: kapıda beklerken yapılan
    // değişiklik bu okumaya yansımaz.
    final rejected = _rejected<Set<String>>([blockerId]);
    final blocked = {for (final block in _active(blockerId)) block.blockedId};
    if (fetchActiveBlocksGate case final gate?) await gate.future;
    return rejected ?? FirebaseSuccess(blocked);
  }

  @override
  Future<FirestoreResult<List<BlockModel>>> listBlocked(
    String blockerId,
  ) async {
    record('listBlocked', [blockerId]);
    if (_rejected<List<BlockModel>>([blockerId]) case final failure?) {
      return failure;
    }
    return FirebaseSuccess(_active(blockerId));
  }

  @override
  Future<FirestoreResult<void>> block({
    required String blockerId,
    required String blockedId,
  }) async {
    record('block', [blockerId, blockedId]);
    if (_rejectedPair(blockerId, blockedId) case final failure?) return failure;
    final key = _key(blockerId, blockedId);
    final existing = blocks[key];
    blocks[key] = existing == null
        ? BlockModel(blockerId: blockerId, blockedId: blockedId)
        : _restored(existing);
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> softDeleteBlock({
    required String blockerId,
    required String blockedId,
  }) async {
    record('softDeleteBlock', [blockerId, blockedId]);
    if (_rejectedPair(blockerId, blockedId) case final failure?) return failure;
    final key = _key(blockerId, blockedId);
    final existing = blocks[key];
    if (existing == null) return const FirebaseFailure(FirestoreError.notFound);
    blocks[key] = existing.copyWith(isDeleted: true, deletedBy: blockerId);
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> restoreBlock({
    required String blockerId,
    required String blockedId,
  }) async {
    record('restoreBlock', [blockerId, blockedId]);
    if (_rejectedPair(blockerId, blockedId) case final failure?) return failure;
    final key = _key(blockerId, blockedId);
    final existing = blocks[key];
    if (existing == null) return const FirebaseFailure(FirestoreError.notFound);
    blocks[key] = _restored(existing);
    return const FirebaseSuccess(null);
  }

  List<BlockModel> _active(String blockerId) => [
    for (final block in blocks.values)
      if (block.blockerId == blockerId && !block.isDeleted) block,
  ];

  static BlockModel _restored(BlockModel block) => block.copyWith(
    isDeleted: false,
    clearDeletedAt: true,
    clearDeletedBy: true,
  );

  static String _key(String blockerId, String blockedId) =>
      FirestoreIds.block(blockerId, blockedId);

  FirestoreResult<void>? _rejectedPair(String blockerId, String blockedId) =>
      _rejected<void>([blockerId, blockedId]) ??
      (blockerId == blockedId
          ? const FirebaseFailure(FirestoreError.invalidArgument)
          : null);

  /// Bekleyen hata ya da geçersiz kimlik varsa başarısızlık; yoksa `null`.
  FirestoreResult<T>? _rejected<T>(List<String> ids) {
    final failure = switch (takeFailure()) {
      null => null,
      final FirestoreError error => error,
      _ => FirestoreError.unknown,
    };
    if (failure != null) return FirebaseFailure(failure);
    if (!ids.every(RepositoryHelpers.isValidId)) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    return null;
  }
}
