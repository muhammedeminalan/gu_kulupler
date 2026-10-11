import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/services/firestore_types.dart';
import 'package:gu_data/src/utils/field_validators.dart';

/// Repository uygulamalarının (`firebase_<alan>_repository.dart`) ortak ön
/// koşul ve çeviri yardımcıları (borç W-54, CD-131).
///
/// Üç iş tek yerde durur; her repository aynısını kullanır:
/// - **Kimlik doğrulama:** rota parametresi, QR ya da derin bağlantıdan gelen
///   kimlik `FirestoreService.doc()` çağrısından **önce** denetlenir
///   ([rejectInvalidIds]); geçersiz kimlik `ArgumentError` olarak sızmaz,
///   [FirestoreError.invalidArgument] döner.
/// - **Alan doğrulama:** `FieldValidators` sonuçları tek başarısızlığa
///   çevrilir ([rejectInvalidFields]).
/// - **Modele çeviri:** `fromJson` hatası [FirestoreError.parse] olur
///   ([parse], [parseOrNull], [parseAll]); "silinmiş tekil belge = yok" kuralı
///   da buradadır (PLAN §10.3).
abstract final class RepositoryHelpers {
  /// Firestore `whereIn` / `arrayContainsAny` süzgecinin kabul ettiği en çok
  /// değer sayısı (platform sınırı; iş kuralı değildir).
  static const int whereInMax = 30;

  /// [id] tek ve geçerli bir Firestore yol parçası mı?
  ///
  /// Boş, `/` içeren, `.` ya da `..` olan ve `__…__` biçimindeki (Firestore'a
  /// ayrılmış) kimlikler geçersizdir.
  static bool isValidId(String id) =>
      id.isNotEmpty &&
      !id.contains(_pathSeparator) &&
      id != _currentDir &&
      id != _parentDir &&
      !_reservedId.hasMatch(id);

  /// [id] noktalı alan yolunun (`clubs.<clubId>`) tek parçası olabilir mi?
  ///
  /// [isValidId] koşullarına ek olarak `.` ve alan yolunda ayrılmış
  /// karakterleri (`~ * [ ]`) içeremez: aksi halde yol başka bir alana
  /// dönüşür.
  static bool isFieldPathSegment(String id) =>
      isValidId(id) && !_fieldPathReserved.hasMatch(id);

  /// `<parent>/<id>/<sub>` alt koleksiyon yolu
  /// (`users/{uid}/private`). [id] önceden [isValidId] ile doğrulanmış
  /// olmalıdır.
  static String subcollectionPath(String parent, String id, String sub) =>
      '$parent$_pathSeparator$id$_pathSeparator$sub';

  /// [ids] (parametre adı → değer) içindeki ilk geçersiz kimlik için
  /// [FirestoreError.invalidArgument]; hepsi geçerliyse `null`.
  ///
  /// ```dart
  /// if (RepositoryHelpers.rejectInvalidIds<UserModel?>({'uid': uid})
  ///     case final rejected?) {
  ///   return rejected;
  /// }
  /// ```
  static FirestoreResult<T>? rejectInvalidIds<T>(Map<String, String> ids) {
    for (final MapEntry(key: name, value: id) in ids.entries) {
      if (!isValidId(id)) return invalidArgument('geçersiz kimlik: $name');
    }
    return null;
  }

  /// [checks] (alan adı → doğrulama sonucu) içindeki ilk hata için
  /// [FirestoreError.invalidArgument]; hepsi `null` ise `null`.
  static FirestoreResult<T>? rejectInvalidFields<T>(
    Map<String, FieldError?> checks,
  ) {
    for (final MapEntry(key: field, value: error) in checks.entries) {
      if (error != null) {
        return invalidArgument('geçersiz alan: $field (${error.name})');
      }
    }
    return null;
  }

  /// [message] açıklamalı [FirestoreError.invalidArgument] sonucu.
  static FirestoreResult<T> invalidArgument<T>(String message) =>
      FirebaseFailure(FirestoreError.invalidArgument, message: message);

  /// [doc] belgesi soft delete edilmiş mi (`isDeleted == true`)?
  static bool isSoftDeleted(FirestoreDoc doc) =>
      doc.data[FirestoreFields.isDeleted] == true;

  /// [doc] belgesini [fromDoc] ile modele çevirir; çeviri herhangi bir hata
  /// fırlatırsa [FirestoreError.parse] döner (PLAN §10.1). Ham hata yalnızca
  /// `message` alanında (günlük için) taşınır.
  static FirestoreResult<T> parse<T>(
    FirestoreDoc doc,
    T Function(FirestoreDoc doc) fromDoc,
  ) {
    try {
      return FirebaseSuccess(fromDoc(doc));
    } on Object catch (error) {
      return FirebaseFailure(
        FirestoreError.parse,
        message: '${doc.path}: $error',
      );
    }
  }

  /// Tekil okuma sonucunu modele çevirir: belge yoksa başarı `null`.
  ///
  /// Soft delete edilmiş belge "yok" sayılır ve [FirestoreError.notFound]
  /// döner (PLAN §10.3). [includeDeleted] yalnızca silinmiş belgenin de
  /// gösterildiği okumalarda `true` verilir (`UserRepository.getUser`:
  /// anonim yazar).
  static FirestoreResult<T?> parseOrNull<T extends Object>(
    FirestoreResult<FirestoreDoc?> result,
    T Function(FirestoreDoc doc) fromDoc, {
    bool includeDeleted = false,
  }) => switch (result) {
    FirebaseFailure(:final error, :final message, :final detail) =>
      FirebaseFailure(error, message: message, detail: detail),
    FirebaseSuccess(data: null) => const FirebaseSuccess(null),
    FirebaseSuccess(data: final doc?) =>
      !includeDeleted && isSoftDeleted(doc)
          ? FirebaseFailure(
              FirestoreError.notFound,
              message: '${doc.path}: silinmiş',
            )
          : parse<T?>(doc, fromDoc),
  };

  /// Liste okuma sonucunu modellere çevirir. Tek bir belge bile
  /// ayrıştırılamazsa tüm sonuç [FirestoreError.parse] olur (hata yutulmaz,
  /// eksik liste dönmez).
  static FirestoreResult<List<T>> parseAll<T>(
    FirestoreResult<List<FirestoreDoc>> result,
    T Function(FirestoreDoc doc) fromDoc,
  ) {
    switch (result) {
      case FirebaseFailure(:final error, :final message, :final detail):
        return FirebaseFailure(error, message: message, detail: detail);
      case FirebaseSuccess(data: final docs):
        final items = <T>[];
        for (final doc in docs) {
          switch (parse(doc, fromDoc)) {
            case FirebaseSuccess(:final data):
              items.add(data);
            case FirebaseFailure(:final error, :final message):
              return FirebaseFailure(error, message: message);
          }
        }
        return FirebaseSuccess(items);
    }
  }

  static const String _pathSeparator = '/';
  static const String _currentDir = '.';
  static const String _parentDir = '..';
  static final RegExp _reservedId = RegExp(r'^__.*__$');
  static final RegExp _fieldPathReserved = RegExp(r'[.~*\[\]]');
}
