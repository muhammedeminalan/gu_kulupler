import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';

/// Faaliyet satırı metinlerinin yer tutucu değerleri — prototip
/// `ActivityRow` (`screens-manage.js:35–36`): eylemi yapan (`actor`), hedef
/// kullanıcı (`user`) ve etkinlik (`event`) adları.
///
/// `activity` belgesi metin taşımaz (PLAN §9.6.13): metin istemcide ARB'den,
/// buradaki adlarla üretilir (`ActivityTexts`). Adlar `actorId` /
/// `refs.userId` / `refs.eventId` kimliklerinden toplu okunur (MGT-01 /
/// MGT-10 ViewModel'leri).
///
/// [missing] okunmuş ama bulunamayan (silinmiş, erişilemeyen) hedeflerin
/// kimlikleridir: kullanıcı yerine "Silinmiş kullanıcı", etkinlik yerine
/// "İçerik kaldırıldı" yazılır.
final class ActivityLookups extends Equatable {
  /// Boş tablo (henüz hiçbir ad okunmadı).
  const ActivityLookups({
    this.users = const {},
    this.eventTitles = const {},
    this.missing = const {},
  });

  /// Kullanıcı kimliği → kullanıcı (eylemi yapan + hedef; avatar da buradan).
  final Map<String, UserModel> users;

  /// Etkinlik kimliği → başlık.
  final Map<String, String> eventTitles;

  /// Bulunamayan hedeflerin kimlikleri.
  final Set<String> missing;

  /// [id] çözüldü mü (kayıt ya da "bulunamadı" işareti var mı)?
  bool isResolved(String id) =>
      missing.contains(id) ||
      users.containsKey(id) ||
      eventTitles.containsKey(id);

  /// [other] tablosuyla birleşmiş kopya ([other] üstün).
  ActivityLookups merge(ActivityLookups other) => ActivityLookups(
    users: {...users, ...other.users},
    eventTitles: {...eventTitles, ...other.eventTitles},
    missing: {
      ...missing.where(
        (id) =>
            !other.users.containsKey(id) && !other.eventTitles.containsKey(id),
      ),
      ...other.missing,
    },
  );

  @override
  List<Object?> get props => [users, eventTitles, missing];
}
