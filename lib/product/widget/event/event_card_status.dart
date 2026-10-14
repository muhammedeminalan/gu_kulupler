import 'package:gu_data/gu_data.dart';

/// Etkinlik kartı ve EVT-02 başlığındaki durum rozeti — prototip
/// `eventStatusFor` (`cards.js:48–57`). Saklanmaz; etkinlik + kullanıcının
/// katılım kaydı + kulübün içini görme hakkından türetilir.
///
/// Rozet eşlemesi (`GuStatusBadgeKind`) çağıran tarafta
/// `role_badge_mapper.dart` üzerinden yapılır.
enum EventCardStatus {
  /// Etkinlik iptal edildi.
  cancelled,

  /// Taslak (yalnızca yönetim görür).
  draft,

  /// Bitti; kullanıcının yoklaması alındı.
  attended,

  /// Bitti; kullanıcı kayıtlıydı ama gelmedi.
  absent,

  /// Bitti; kullanıcının kaydı yok.
  past,

  /// Kullanıcı bekleme listesinde.
  waitlist,

  /// Kullanıcı kayıtlı (bilet geçerli).
  going,

  /// Yalnızca üyelere açık; kullanıcı kulübün içini görmüyor.
  members,

  /// Yeni katılım bekleme listesine düşer — `EventModel.joinsWaitlist`
  /// (kontenjan dolu **ya da** önde bekleyen var; W-81 (a), CD-144).
  full;

  /// [event] için kullanıcının durumu; rozet yoksa `null`.
  ///
  /// [rsvp] kullanıcının katılım kaydıdır (`cancelled` kayıt yok sayılır);
  /// [canSeeInside] `SessionState.accessTo(clubId)` içini görme hakkı;
  /// [nowUtc] `AppClock.nowUtc()`.
  static EventCardStatus? of({
    required EventModel event,
    required RsvpModel? rsvp,
    required bool canSeeInside,
    required DateTime nowUtc,
  }) {
    if (event.status == EventStatus.cancelled) return cancelled;
    if (event.status == EventStatus.draft) return draft;
    final rsvpStatus = rsvp?.status;
    if (event.endsAt.isBefore(nowUtc)) {
      return switch (rsvpStatus) {
        RsvpStatus.attended => attended,
        RsvpStatus.going => absent,
        _ => past,
      };
    }
    switch (rsvpStatus) {
      case RsvpStatus.waitlist:
        return waitlist;
      case RsvpStatus.going || RsvpStatus.attended:
        return going;
      case RsvpStatus.cancelled || null:
        break;
    }
    if (event.visibility == EventVisibility.membersOnly && !canSeeInside) {
      return members;
    }
    if (event.joinsWaitlist) return full;
    return null;
  }
}
