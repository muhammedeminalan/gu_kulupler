/// Etkinlik bileti rozet durumu (PLAN §9.7; türetilmiş, kalıcı değil).
///
/// Firestore'a **yazılmaz**: katılım kaydı ve etkinlik durumundan türetilir
/// (`RsvpModel.ticketState`; EVT-03). Destek talebi durumu ayrı enum'dur
/// (`TicketStatus`).
enum TicketState {
  /// Geçerli bilet (katılım `going`).
  valid,

  /// Kullanılmış bilet (katılım `attended`).
  used,

  /// Geçersiz bilet (katılım ya da etkinlik `cancelled`).
  voided,
}
