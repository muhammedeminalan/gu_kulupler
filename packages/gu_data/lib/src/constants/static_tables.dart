import 'package:gu_data/src/models/lookup/category_model.dart';
import 'package:gu_data/src/models/lookup/department_model.dart';
import 'package:gu_data/src/models/lookup/event_type_model.dart';
import 'package:gu_data/src/models/lookup/faculty_model.dart';
import 'package:gu_data/src/models/lookup/interest_model.dart';
import 'package:gu_data/src/models/lookup/place_model.dart';

/// Statik arama tabloları — Firestore **dışı** (PLAN §9.9; domain-model §1.6,
/// §10).
///
/// Kimlikler ve sıra `tool/seed/demo-data.json` (kategori, ilgi alanı, bölüm,
/// mekân) ve `design/extracted/registry.json` (yıl, etkinlik türü, popüler
/// arama) ile **birebirdir**; `static_tables_test.dart` iki dosyayı okuyup
/// sayı, kimlik, bağ ve sıra paritesini doğrular. Tohumlayıcı bu tabloları
/// Firestore'a yazmaz.
///
/// Görünen adlar burada **yoktur**: `gu_data` ARB bilmez; kimlik → metin
/// çözümü uygulama katmanındadır (`lib/product/l10n/static_labels.dart`).
/// Tek istisna [popularSearches]: arama sorgusu dizgileridir, iki dilde aynıdır.
abstract final class StaticTables {
  // ── Kategoriler ──────────────────────────────────────────────────────

  /// Kulüp kategorileri (8; `k01`–`k08`), tasarım sırasıyla.
  static const List<CategoryModel> categories = [
    CategoryModel(id: 'k01', icon: 'cpu'),
    CategoryModel(id: 'k02', icon: 'flask-conical'),
    CategoryModel(id: 'k03', icon: 'mountain'),
    CategoryModel(id: 'k04', icon: 'palette'),
    CategoryModel(id: 'k05', icon: 'heart-handshake'),
    CategoryModel(id: 'k06', icon: 'briefcase'),
    CategoryModel(id: 'k07', icon: 'gamepad-2'),
    CategoryModel(id: 'k08', icon: 'newspaper'),
  ];

  /// [categories] kimlik kümesi (`clubs.categoryId` doğrulaması).
  static final Set<String> categoryIds = Set.unmodifiable(
    categories.map((category) => category.id),
  );

  // ── İlgi alanları ────────────────────────────────────────────────────

  /// İlgi alanları (16; `i01`–`i16`), tasarım sırasıyla.
  static const List<InterestModel> interests = [
    InterestModel(id: 'i01', categoryId: 'k01'),
    InterestModel(id: 'i02', categoryId: 'k01'),
    InterestModel(id: 'i03', categoryId: 'k06'),
    InterestModel(id: 'i04', categoryId: 'k03'),
    InterestModel(id: 'i05', categoryId: 'k03'),
    InterestModel(id: 'i06', categoryId: 'k08'),
    InterestModel(id: 'i07', categoryId: 'k08'),
    InterestModel(id: 'i08', categoryId: 'k04'),
    InterestModel(id: 'i09', categoryId: 'k04'),
    InterestModel(id: 'i10', categoryId: 'k04'),
    InterestModel(id: 'i11', categoryId: 'k07'),
    InterestModel(id: 'i12', categoryId: 'k07'),
    InterestModel(id: 'i13', categoryId: 'k05'),
    InterestModel(id: 'i14', categoryId: 'k04'),
    InterestModel(id: 'i15', categoryId: 'k01'),
    InterestModel(id: 'i16', categoryId: 'k06'),
  ];

  /// [interests] kimlik kümesi (`users.interests` eleman doğrulaması).
  static final Set<String> interestIds = Set.unmodifiable(
    interests.map((interest) => interest.id),
  );

  /// [categoryId] kategorisine bağlı ilgi alanı kimlikleri, tablo sırasıyla.
  ///
  /// `event_new` ilgi-eşleşmeli bildirim alıcılarını bulmak için kullanılır
  /// (CD-38). Bilinmeyen kategori ya da ilgi alanı olmayan kategori (`k02`)
  /// için boş liste döner. Dönen liste değiştirilemez.
  static List<String> interestIdsOf(String categoryId) => List.unmodifiable(
    interests
        .where((interest) => interest.categoryId == categoryId)
        .map((interest) => interest.id),
  );

  // ── Fakülteler ve bölümler ───────────────────────────────────────────

  /// Fakülteler (6; `f1`–`f6`), tasarım sırasıyla.
  static const List<FacultyModel> faculties = [
    FacultyModel(id: 'f1'),
    FacultyModel(id: 'f2'),
    FacultyModel(id: 'f3'),
    FacultyModel(id: 'f4'),
    FacultyModel(id: 'f5'),
    FacultyModel(id: 'f6'),
  ];

  /// [faculties] kimlik kümesi.
  static final Set<String> facultyIds = Set.unmodifiable(
    faculties.map((faculty) => faculty.id),
  );

  /// Bölümler (24; `d01`–`d24`), tasarım sırasıyla.
  static const List<DepartmentModel> departments = [
    DepartmentModel(id: 'd01', facultyId: 'f1'),
    DepartmentModel(id: 'd02', facultyId: 'f1'),
    DepartmentModel(id: 'd03', facultyId: 'f1'),
    DepartmentModel(id: 'd04', facultyId: 'f1'),
    DepartmentModel(id: 'd05', facultyId: 'f1'),
    DepartmentModel(id: 'd06', facultyId: 'f1'),
    DepartmentModel(id: 'd07', facultyId: 'f1'),
    DepartmentModel(id: 'd08', facultyId: 'f2'),
    DepartmentModel(id: 'd09', facultyId: 'f2'),
    DepartmentModel(id: 'd10', facultyId: 'f3'),
    DepartmentModel(id: 'd11', facultyId: 'f3'),
    DepartmentModel(id: 'd12', facultyId: 'f3'),
    DepartmentModel(id: 'd13', facultyId: 'f3'),
    DepartmentModel(id: 'd14', facultyId: 'f3'),
    DepartmentModel(id: 'd15', facultyId: 'f3'),
    DepartmentModel(id: 'd16', facultyId: 'f4'),
    DepartmentModel(id: 'd17', facultyId: 'f4'),
    DepartmentModel(id: 'd18', facultyId: 'f4'),
    DepartmentModel(id: 'd19', facultyId: 'f5'),
    DepartmentModel(id: 'd20', facultyId: 'f5'),
    DepartmentModel(id: 'd21', facultyId: 'f6'),
    DepartmentModel(id: 'd22', facultyId: 'f6'),
    DepartmentModel(id: 'd23', facultyId: 'f6'),
    DepartmentModel(id: 'd24', facultyId: 'f6'),
  ];

  /// [departments] kimlik kümesi (`users.department` doğrulaması).
  static final Set<String> departmentIds = Set.unmodifiable(
    departments.map((department) => department.id),
  );

  /// [facultyId] fakültesinin bölümleri, tablo sırasıyla.
  ///
  /// Bilinmeyen fakülte için boş liste döner. Dönen liste değiştirilemez.
  static List<DepartmentModel> departmentsOf(String facultyId) =>
      List.unmodifiable(
        departments.where((department) => department.facultyId == facultyId),
      );

  // ── Mekânlar ─────────────────────────────────────────────────────────

  /// Kurgusal kampüs mekânları (10; `pl01`–`pl10`), tasarım sırasıyla.
  static const List<PlaceModel> places = [
    PlaceModel(id: 'pl01'),
    PlaceModel(id: 'pl02'),
    PlaceModel(id: 'pl03'),
    PlaceModel(id: 'pl04'),
    PlaceModel(id: 'pl05'),
    PlaceModel(id: 'pl06'),
    PlaceModel(id: 'pl07'),
    PlaceModel(id: 'pl08'),
    PlaceModel(id: 'pl09'),
    PlaceModel(id: 'pl10'),
  ];

  /// [places] kimlik kümesi (`events.placeId` doğrulaması).
  static final Set<String> placeIds = Set.unmodifiable(
    places.map((place) => place.id),
  );

  // ── Yıllar ve etkinlik türleri ───────────────────────────────────────

  /// Sınıf / öğrenim düzeyi kodları (8), tasarım sırasıyla; `users.year` bu
  /// değerlerden birini taşır.
  static const List<String> years = [
    'prep',
    '1',
    '2',
    '3',
    '4',
    '5plus',
    'master',
    'phd',
  ];

  /// Etkinlik türleri (5), tasarım sırasıyla.
  static const List<EventTypeModel> eventTypes = [
    EventTypeModel(id: 'egitim'),
    EventTypeModel(id: 'sosyal'),
    EventTypeModel(id: 'gezi'),
    EventTypeModel(id: 'yarisma'),
    EventTypeModel(id: 'konferans'),
  ];

  // ── Arama ────────────────────────────────────────────────────────────

  /// Popüler arama sorguları (6; CLB-02). Arama kutusuna yazılan dizgilerdir:
  /// çevrilmez, TR ve EN'de aynıdır (ARB anahtarı yoktur).
  static const List<String> popularSearches = [
    'Hackathon',
    'Doğa yürüyüşü',
    'Tiyatro',
    'E-spor',
    'Fotoğraf',
    'Satranç',
  ];
}
