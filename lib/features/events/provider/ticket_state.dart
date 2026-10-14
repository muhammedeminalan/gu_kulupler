import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';

/// EVT-03 "Bilet" durumu (PLAN §12.6 `TicketViewModel`).
///
/// Sınıf adı `TicketViewState`'tir: `gu_data`'daki rozet enum'u
/// `TicketState` (valid / used / voided) ile çakışmasın diye. Bilet durumu
/// [status] ile türetilir (`RsvpModel.ticketState(event)`).
///
/// * [event] bir kez okunur (`eventRepository.getEvent`); [rsvp] canlıdır
///   (`rsvpRepository.watchMine` — PLAN §10.6 #4).
/// * [isNotFound]: etkinlik yok / silinmiş / görünmüyor → SYS-04.
/// * [hasNoTicket]: kayıt yok ya da bekleme listesinde (bilet yok) → view
///   EVT-02'ye döner (§13.3.3).
final class TicketViewState extends Equatable {
  /// Varsayılan: içerik yok.
  const TicketViewState({
    this.event,
    this.club,
    this.rsvp,
    this.isFetching = false,
    this.isError = false,
    this.isNotFound = false,
    this.hasNoTicket = false,
    this.isLeaving = false,
  });

  /// Etkinlik; okunmadıysa `null`.
  final EventModel? event;

  /// Düzenleyen kulüp (kartın üst satırı); okunamadıysa `null`.
  final ClubModel? club;

  /// Kullanıcının katılım kaydı (canlı); ilk olay gelmediyse ya da bilet
  /// yoksa `null`.
  final RsvpModel? rsvp;

  /// Etkinlik / ilk kayıt olayı bekleniyor (iskelet).
  final bool isFetching;

  /// Okunamadı (hata görünümü + "Yeniden dene").
  final bool isError;

  /// Etkinlik yok, silinmiş ya da okuma yetkisi yok → SYS-04.
  final bool isNotFound;

  /// Kullanıcının bu etkinlikte bileti yok (kayıt yok / bekleme listesi).
  final bool hasNoTicket;

  /// "Vazgeç" yazımı sürüyor (düğme meşgul).
  final bool isLeaving;

  /// Bilet rozeti durumu; etkinlik ya da kayıt yoksa `null`.
  TicketState? get status {
    final event = this.event;
    final rsvp = this.rsvp;
    if (event == null || rsvp == null) return null;
    return rsvp.ticketState(event);
  }

  /// QR yükü (`gu:ticket:v1:{eventId}:{ticketCode}` — D-30); kayıt yoksa
  /// `null`.
  String? get qrPayload => rsvp?.qrPayload;

  /// "Vazgeç" gösterilir mi: bilet geçerli ve etkinlik [nowUtc] anında
  /// bitmemiş (prototip `screens-events.js:86`; W-81 (b)).
  bool canLeaveAt(DateTime nowUtc) {
    final event = this.event;
    return status == TicketState.valid &&
        event != null &&
        event.endsAt.isAfter(nowUtc);
  }

  @override
  List<Object?> get props => [
    event,
    club,
    rsvp,
    isFetching,
    isError,
    isNotFound,
    hasNoTicket,
    isLeaving,
  ];

  /// Verilen alanları değiştirilmiş kopya. [clearRsvp] kaydı `null` yapar ve
  /// [rsvp] parametresinden önce gelir.
  TicketViewState copyWith({
    EventModel? event,
    ClubModel? club,
    RsvpModel? rsvp,
    bool clearRsvp = false,
    bool? isFetching,
    bool? isError,
    bool? isNotFound,
    bool? hasNoTicket,
    bool? isLeaving,
  }) => TicketViewState(
    event: event ?? this.event,
    club: club ?? this.club,
    rsvp: clearRsvp ? null : rsvp ?? this.rsvp,
    isFetching: isFetching ?? this.isFetching,
    isError: isError ?? this.isError,
    isNotFound: isNotFound ?? this.isNotFound,
    hasNoTicket: hasNoTicket ?? this.hasNoTicket,
    isLeaving: isLeaving ?? this.isLeaving,
  );
}
