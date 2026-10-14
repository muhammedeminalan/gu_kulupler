import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';

/// Bildirim metinlerinin yer tutucu değerleri — prototip `notifParams`
/// (`cards.js:136`): kulüp / etkinlik / gönderi / başvuran adları.
///
/// Bildirim belgesi metin taşımaz (T-25 şeması); metin istemcide ARB'den,
/// buradaki adlarla üretilir (`NotificationTexts`). Adlar `refs`
/// kimliklerinden toplu okunur (`NotificationsViewModel`).
///
/// [missing] okunmuş ama bulunamayan (silinmiş, gizlenmiş, erişilemeyen)
/// hedeflerin kimlikleridir: metinde "İçerik kaldırıldı" yazılır.
final class NotificationLookups extends Equatable {
  /// Boş tablo (henüz hiçbir ad okunmadı).
  const NotificationLookups({
    this.clubNames = const {},
    this.events = const {},
    this.postTitles = const {},
    this.userNames = const {},
    this.missing = const {},
  });

  /// Kulüp kimliği → ad.
  final Map<String, String> clubNames;

  /// Etkinlik kimliği → etkinlik (başlık, saat, iptal nedeni).
  final Map<String, EventModel> events;

  /// Gönderi kimliği → başlık (başlık yoksa metnin başı).
  final Map<String, String> postTitles;

  /// Kullanıcı kimliği → ad (silinmiş kullanıcı anonim adıyla döner).
  final Map<String, String> userNames;

  /// Bulunamayan hedeflerin kimlikleri.
  final Set<String> missing;

  /// Gönderi başlığı yoksa metnin ilk bu kadar karakteri
  /// (`post.title || post.text.slice(0, 60)`).
  static const int postSnippetLength = 60;

  /// [post] gönderisinin bildirimde görünen adı.
  static String postTitleOf(PostModel post) {
    final title = post.title?.trim() ?? '';
    if (title.isNotEmpty) return title;
    final text = post.text;
    return text.length <= postSnippetLength
        ? text
        : text.substring(0, postSnippetLength);
  }

  /// [id] çözüldü mü (ad ya da "bulunamadı" kaydı var mı)?
  bool isResolved(String id) =>
      missing.contains(id) ||
      clubNames.containsKey(id) ||
      events.containsKey(id) ||
      postTitles.containsKey(id) ||
      userNames.containsKey(id);

  /// [other] tablosuyla birleşmiş kopya ([other] üstün).
  NotificationLookups merge(NotificationLookups other) => NotificationLookups(
    clubNames: {...clubNames, ...other.clubNames},
    events: {...events, ...other.events},
    postTitles: {...postTitles, ...other.postTitles},
    userNames: {...userNames, ...other.userNames},
    missing: {
      ...missing.where((id) => !other.isResolvedByName(id)),
      ...other.missing,
    },
  );

  /// [id] için ad kaydı var mı ("bulunamadı" kaydı sayılmaz)?
  bool isResolvedByName(String id) =>
      clubNames.containsKey(id) ||
      events.containsKey(id) ||
      postTitles.containsKey(id) ||
      userNames.containsKey(id);

  @override
  List<Object?> get props => [
    clubNames,
    events,
    postTitles,
    userNames,
    missing,
  ];
}
