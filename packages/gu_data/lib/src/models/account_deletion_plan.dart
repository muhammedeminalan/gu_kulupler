import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/models/membership_model.dart';
import 'package:gu_data/src/models/rsvp_model.dart';

// Hesap silme (SET-03) değer nesneleri — `AccountDeletionRepository`
// sözleşmesi (PLAN §10.4; domain-model §11; sözleşme `docs/plans/T-29.md` §4).

/// SET-03 ön denetiminin sonucu (PLAN §10.4 adım 0).
///
/// Kullanıcı herhangi bir kulübün **etkin başkanıysa** dizi başlamaz
/// ([DeletionBlockedByPresidency] → TST-X10; devir MGT-03 / SHT-25, T-33).
/// Aksi halde [DeletionReady] döner. Silinecek belgelerin planı burada
/// **çıkarılmaz**: plan `markDeleted` kesinleştikten sonra
/// (`AccountDeletionRepository.buildPlan`) okunur — o andan sonra kullanıcı
/// yeni üyelik / katılım / engel / kayıt oluşturamaz (Rules `activeUser()`),
/// bu yüzden plan bayatlamaz.
sealed class DeletionPrecheck extends Equatable {
  const DeletionPrecheck._();

  /// Dizi başlayabilir.
  const factory DeletionPrecheck.ready() = DeletionReady;

  /// Kullanıcı [clubIds] kulüplerinin etkin başkanıdır; önce devretmeli.
  const factory DeletionPrecheck.blockedByPresidency(List<String> clubIds) =
      DeletionBlockedByPresidency;
}

/// Ön koşul sağlandı: başkanlık yok.
final class DeletionReady extends DeletionPrecheck {
  /// Başkanlık engeli olmayan ön denetim sonucu.
  const DeletionReady() : super._();

  @override
  List<Object?> get props => const [];
}

/// Kullanıcı en az bir kulübün etkin başkanı (`role == president`,
/// `status == active`).
final class DeletionBlockedByPresidency extends DeletionPrecheck {
  /// [clubIds] başkanı olunan kulüplerdir (boş değil, kimlik sırasıyla).
  const DeletionBlockedByPresidency(this.clubIds) : super._();

  /// Başkanı olunan kulüplerin kimlikleri.
  final List<String> clubIds;

  @override
  List<Object?> get props => [clubIds];
}

/// Hesap silmede soft delete edilen kişisel belgenin koleksiyonu
/// (domain-model §11 adım 3: `notifications`, `savedPosts`, `blocks`).
enum PersonalDocKind {
  /// `notifications/{id}` — kullanıcının gelen kutusu (`userId == uid`).
  notification,

  /// `savedPosts/{uid}_{postId}` — kaydedilen gönderiler.
  savedPost,

  /// `blocks/{uid}_{blockedId}` — kullanıcının koyduğu engeller.
  block,
}

/// Soft delete edilecek tek kişisel belge: koleksiyon + belge kimliği.
///
/// Firestore SDK tipi (`DocumentReference`) arayüze sızmasın diye yol
/// koleksiyon türünden ve kimlikten repository içinde kurulur (CLAUDE.md §1).
final class PersonalDocRef extends Equatable {
  /// [kind] koleksiyonundaki [id] belgesi.
  const PersonalDocRef(this.kind, this.id);

  /// Belgenin koleksiyonu.
  final PersonalDocKind kind;

  /// Belge kimliği (koleksiyon içi; yol değil).
  final String id;

  @override
  List<Object?> get props => [kind, id];
}

/// `markDeleted` sonrasında kalan temizlik işleri (PLAN §10.4 adım 2…son;
/// sözleşme §4 a).
///
/// Plan her çağrıda **güncel durumdan** yeniden çıkarılır; tamamlanmış iş
/// plana girmez (idempotent yeniden başlatma). Boş plan = temizlik bitti.
final class DeletionPlan extends Equatable {
  /// Kalan işler; varsayılan boş plan.
  const DeletionPlan({
    this.rsvps = const [],
    this.unreadableRsvps = const [],
    this.memberships = const [],
    this.personalRefs = const [],
  });

  /// Vazgeçilecek katılım kayıtları: `going` / `waitlist` ve etkinliği
  /// bitmemiş (`endsAt > now + Limits.clockSkewTolerance`) — W-80.
  final List<RsvpModel> rsvps;

  /// Etkinliği okunamayan açık (`going` / `waitlist`) kayıtlar: ayrılınan
  /// kulübün üyelere özel etkinliği, taslağa çekilmiş, silinmiş ya da var
  /// olmayan etkinlik. Bitişi bilinemez; etkinlik okunmadan kayıt başına
  /// denenir (`AccountDeletionRepository.cancelUnreadableRsvp`) — bitmişse
  /// Rules reddeder ve kayıt korunur (W-80).
  final List<RsvpModel> unreadableRsvps;

  /// Anonimleştirilecek üyelikler: `active` (başkan hariç) / `pending`
  /// olanlar ya da `applicant` anlık görüntüsü henüz anonimleşmemiş olanlar
  /// (her durumda; etkin başkan üyeliği durumu değişmeden anonimleşir).
  final List<MembershipModel> memberships;

  /// Soft delete edilecek silinmemiş kişisel belgeler.
  final List<PersonalDocRef> personalRefs;

  /// [rsvps] — `Limits.accountDeletionChunk`'lık parçalar.
  List<List<RsvpModel>> get rsvpChunks =>
      _chunk(rsvps, Limits.accountDeletionChunk);

  /// [memberships] — `Limits.accountDeletionChunk`'lık parçalar.
  List<List<MembershipModel>> get membershipChunks =>
      _chunk(memberships, Limits.accountDeletionChunk);

  /// [personalRefs] — `Limits.batchMaxWrites`'lık parçalar.
  List<List<PersonalDocRef>> get personalChunks =>
      _chunk(personalRefs, Limits.batchMaxWrites);

  /// Toplam parça (batch) sayısı — ilerleme göstergesinin paydası
  /// ([unreadableRsvps] kayıt başına bir parçadır).
  int get chunkCount =>
      rsvpChunks.length +
      unreadableRsvps.length +
      membershipChunks.length +
      personalChunks.length;

  /// Kalan iş yok mu?
  bool get isEmpty =>
      rsvps.isEmpty &&
      unreadableRsvps.isEmpty &&
      memberships.isEmpty &&
      personalRefs.isEmpty;

  static List<List<T>> _chunk<T>(List<T> items, int size) => [
    for (var i = 0; i < items.length; i += size)
      items.sublist(i, i + size > items.length ? items.length : i + size),
  ];

  @override
  List<Object?> get props => [
    rsvps,
    unreadableRsvps,
    memberships,
    personalRefs,
  ];
}

/// Hesap silme ilerlemesi (SET-03 `DeleteAccountState.progress`; PLAN
/// §12.6): [done] / [total] kesinleşmiş parça (batch) sayısı.
final class DeleteProgress extends Equatable {
  /// [total] parçadan [done] tanesi kesinleşti (`0 <= done <= total`).
  const DeleteProgress({required this.done, required this.total});

  /// Kesinleşmiş parça sayısı.
  final int done;

  /// Toplam parça sayısı (plan çıkarıldığı andaki).
  final int total;

  @override
  List<Object?> get props => [done, total];
}

/// `AccountDeletionRepository.resumeCleanup` ilerleme bildirimi; her parça
/// kesinleştikçe çağrılır.
typedef DeleteProgressCallback = void Function(DeleteProgress progress);
