import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';

/// SHT-25 atama kipinin aday havuzu — ADM-02 "Başkanı değiştir" ve ADM-03
/// "Başkan ata" için **tek** okuma (prototip `sheets.js:118`).
///
/// `adminRepository.listUsersByName('')` sayfaları en çok
/// [candidatePagesMax] × `Limits.adminSearchMax` kullanıcıya dek taranır;
/// etkin (silinmemiş), personel olmayan kullanıcılar kalır, `excluded`
/// (mevcut başkan, bağlı danışman) çıkarılır. SHT-25 istemcide süzer.
/// Hata bildirimi (toast, claim yenileme) çağıran ViewModel'dedir.
mixin AdminPresidentCandidatesMixin on ProjectDependencyMixin {
  /// Aday okumasının en çok sayfa sayısı.
  static const int candidatePagesMax = 20;

  /// Aday havuzu; ilk okunamayan sayfanın hatasıyla döner.
  Future<FirestoreResult<List<UserModel>>> readPresidentCandidates({
    required Set<String?> excluded,
  }) async {
    final users = <UserModel>[];
    PageCursor? after;
    for (var page = 0; page < candidatePagesMax; page++) {
      final result = await adminRepository.listUsersByName(
        '',
        PageRequest(limit: Limits.adminSearchMax, after: after),
      );
      switch (result) {
        case FirebaseSuccess(:final data):
          users.addAll(data.items);
          after = data.next;
        case FirebaseFailure(:final error, :final message):
          return FirebaseFailure(error, message: message);
      }
      if (after == null) break;
    }
    return FirebaseSuccess([
      for (final user in users)
        if (user.isActive && !user.staff && !excluded.contains(user.uid)) user,
    ]);
  }
}
