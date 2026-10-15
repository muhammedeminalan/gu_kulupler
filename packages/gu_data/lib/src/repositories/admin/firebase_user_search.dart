import 'package:gu_data/src/constants/firestore_collections.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/page_request.dart';
import 'package:gu_data/src/core/page_result.dart';
import 'package:gu_data/src/models/enums/club_role.dart';
import 'package:gu_data/src/models/enums/membership_status.dart';
import 'package:gu_data/src/models/user_model.dart';
import 'package:gu_data/src/repositories/query_x.dart';
import 'package:gu_data/src/repositories/repository_helpers.dart';
import 'package:gu_data/src/repositories/user_repository.dart';
import 'package:gu_data/src/services/firestore_service.dart';
import 'package:gu_data/src/services/firestore_types.dart';

/// `AdminRepository`'nin kullanıcı arama üyeleri (ADM-05;
/// `docs/plans/T-37.md` §4 b): ada göre sayfa, e-postaya göre arama ve
/// yönetici kümesi.
///
/// `FirebaseAdminRepository` bu sınıfa tek satırla devreder; imzalar
/// `AdminRepository` ile aynıdır. E-posta yalnızca
/// `users/{uid}/private/account` belgesindedir (D-29): arama
/// `collectionGroup('private')` ile yapılır ve Rules bu sorguyu **yalnızca
/// süper admine** açar (`list: isSuper()`); sınıf claim'i denetlemez.
/// Koleksiyon grubu üyelik iletişim belgelerini
/// (`memberships/{id}/private/contact`) de döndürür — sonuçtan yalnızca
/// hesap belgeleri alınır, uid'ler tekilleştirilir ve profiller
/// [UserRepository.getUsers] ile okunur.
final class FirebaseUserSearch {
  /// Sorguları `firestore` ile yapar; profilleri `users` ile okur.
  FirebaseUserSearch({required this._firestore, required this._users});

  final FirestoreService _firestore;
  final UserRepository _users;

  /// Önek aralığının üst sınır karakteri (`p` ≤ x < `p` + U+F8FF).
  static const String _prefixEnd = '';

  /// E-posta aramasında okunan en çok sayfa (sayfa başına
  /// [Limits.adminSearchMax] belge): üyelik iletişim belgelerinin araya
  /// girdiği aralıkta hesap belgelerine ulaşmak için; okuma üst sınırı
  /// `4 × 50` belgedir.
  static const int _maxEmailPages = 4;

  /// `users/{uid}/private/account` yolunun parça sayısı.
  static const int _accountPathParts = 4;

  /// Yönetici rolleri (`listManagerUserIds`).
  static const List<ClubRole> _managerRoles = [
    ClubRole.board,
    ClubRole.president,
  ];

  /// `AdminRepository.listUsersByName`: adı [prefixLower] ile başlayan
  /// silinmemiş kullanıcılardan bir sayfa (`nameLower` artan; indeks
  /// `users (isDeleted, nameLower)`). Boş önek aralık süzgeci koymaz, ilk
  /// sayfayı döndürür.
  Future<FirestoreResult<PageResult<UserModel>>> listUsersByName(
    String prefixLower,
    PageRequest page,
  ) async {
    var query = _firestore.collection(FirestoreCollections.users).notDeleted();
    if (prefixLower.isNotEmpty) {
      query = query
          .where(FirestoreFields.nameLower, isGreaterThanOrEqualTo: prefixLower)
          .where(
            FirestoreFields.nameLower,
            isLessThan: '$prefixLower$_prefixEnd',
          );
    }
    return RepositoryHelpers.parsePage(
      await _firestore.getPage(query.orderBy(FirestoreFields.nameLower), page),
      _userOf,
    );
  }

  /// `AdminRepository.findUserByEmail`: e-postası [emailLower] ile başlayan
  /// kullanıcıların profilleri, e-posta sırasıyla (en çok
  /// [Limits.adminSearchMax] kullanıcı). Boş girdi sorgu yapmadan boş döner
  /// (silinmiş hesapların boş `emailLower` değeri eşleşmez).
  ///
  /// Aynı e-postada üyelik iletişim belgeleri (`memberships/…`) yol
  /// sırasında hesap belgesinin (`users/…`) önüne düşer; tek sayfa hesap
  /// belgelerini dışarıda bırakabilirdi (güvenlik incelemesi T-37). Bu
  /// yüzden [Limits.adminSearchMax] belgelik sayfalar imleçle okunur:
  /// [Limits.adminSearchMax] tekil hesaba, son sayfaya ya da
  /// [_maxEmailPages] sayfaya ulaşınca durur.
  Future<FirestoreResult<List<UserModel>>> findUserByEmail(
    String emailLower,
  ) async {
    if (emailLower.isEmpty) return const FirebaseSuccess([]);
    final query = _firestore
        .collectionGroup(FirestoreCollections.privateSub)
        .where(FirestoreFields.emailLower, isGreaterThanOrEqualTo: emailLower)
        .where(FirestoreFields.emailLower, isLessThan: '$emailLower$_prefixEnd')
        .orderBy(FirestoreFields.emailLower);
    final uids = <String>{};
    var page = const PageRequest(limit: Limits.adminSearchMax);
    for (var read = 0; read < _maxEmailPages; read++) {
      final found = await _firestore.getPage(query, page);
      final PageResult<FirestoreDoc> result;
      switch (found) {
        case FirebaseFailure(:final error, :final message, :final detail):
          return FirebaseFailure(error, message: message, detail: detail);
        case FirebaseSuccess(:final data):
          result = data;
      }
      for (final doc in result.items) {
        if (uids.length == Limits.adminSearchMax) break;
        if (_accountOwner(doc) case final uid?) uids.add(uid);
      }
      final next = result.next;
      if (next == null || uids.length == Limits.adminSearchMax) break;
      page = PageRequest(limit: Limits.adminSearchMax, after: next);
    }
    if (uids.isEmpty) return const FirebaseSuccess([]);
    return _users.getUsers(uids.toList());
  }

  /// `AdminRepository.listManagerUserIds`: herhangi bir kulüpte etkin
  /// `board` / `president` üyeliği olan kullanıcıların kimlikleri (tek
  /// sorgu; yalnızca eşitlik süzgeçleri, bileşik indeks gerekmez).
  Future<FirestoreResult<Set<String>>> listManagerUserIds() async =>
      RepositoryHelpers.parseAll(
        await _firestore.getList(
          _firestore
              .collection(FirestoreCollections.memberships)
              .where(
                FirestoreFields.status,
                isEqualTo: MembershipStatus.active.json,
              )
              .where(
                FirestoreFields.role,
                whereIn: [for (final role in _managerRoles) role.json],
              ),
        ),
        _userIdOf,
      ).map((ids) => ids.toSet());

  /// [doc] bir hesap belgesiyse (`users/{uid}/private/account`) sahibinin
  /// uid'i; başka `private` belgesi (üyelik iletişimi, sayaç) `null`.
  static String? _accountOwner(FirestoreDoc doc) {
    final parts = doc.path.split('/');
    if (parts.length != _accountPathParts) return null;
    final [root, uid, sub, name] = parts;
    return root == FirestoreCollections.users &&
            sub == FirestoreCollections.privateSub &&
            name == FirestoreCollections.accountDoc
        ? uid
        : null;
  }

  static UserModel _userOf(FirestoreDoc doc) =>
      UserModel.fromJson(doc.data, id: doc.id);

  static String _userIdOf(FirestoreDoc doc) =>
      doc.data[FirestoreFields.userId]! as String;
}
