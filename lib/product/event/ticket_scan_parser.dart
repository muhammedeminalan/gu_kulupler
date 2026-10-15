import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';

/// MGT-07 girdisinin ret nedeni (istemci ön denetimi; yazım yapılmaz).
enum TicketScanRejection {
  /// QR yükü `gu:ticket:v1:{eventId}:{code}` değil (yanlış önek / tür /
  /// sürüm, eksik ya da boş parça, kod deseni `GU-XXXX-XXXX` dışında) ya da
  /// elle girilen kod desene uymuyor.
  malformed,

  /// Biçim doğru ama bilet başka bir etkinliğin (`eventId` eşleşmez).
  otherEvent,
}

/// [TicketScanParser] sonucu.
sealed class TicketScanParse extends Equatable {
  const TicketScanParse();
}

/// Girdi bu etkinliğin biçimce geçerli bileti: [payload]
/// `AttendanceRepository.scanTicket(qrPayload:)`'a verilir (kaydın varlığı
/// ve durumu orada denetlenir — `ScanOutcome`).
final class TicketScanAccepted extends TicketScanParse {
  /// [eventId] etkinliğinin [code] bileti.
  const TicketScanAccepted({required this.eventId, required this.code});

  /// Etkinlik kimliği (ekranın etkinliği).
  final String eventId;

  /// Bilet kodu (`GU-XXXX-XXXX`).
  final String code;

  /// Kanonik QR yükü (`FirestoreIds.ticketQrPayload`).
  String get payload => FirestoreIds.ticketQrPayload(eventId, code);

  @override
  List<Object?> get props => [eventId, code];
}

/// Girdi reddedildi; SHT-24 "Geçersiz bilet" ağa çıkmadan gösterilir.
final class TicketScanRejected extends TicketScanParse {
  /// [reason] nedeniyle ret.
  const TicketScanRejected(this.reason);

  /// Ret nedeni.
  final TicketScanRejection reason;

  @override
  List<Object?> get props => [reason];
}

/// MGT-07'de okutulan QR içeriğini ve elle girilen bilet kodunu ekranın
/// etkinliğine göre çözer (D-30; saf Dart).
///
/// Biçim kuralları tek yerdedir — `FirestoreIds.parseTicketQr` (QR) ve
/// `FirestoreIds.ticketCodePattern` (kod); burası yalnızca etkinlik
/// kapsamını ve elle girişin normalleştirmesini ekler. QR v1'dir; v2 kararı
/// Faz H'dedir (W-93).
abstract final class TicketScanParser {
  /// Elle girilen kodun uzunluğu (`GU-XXXX-XXXX`); prototipte "Doğrula"
  /// bundan kısa girdide devre dışıdır (`code.length < 12`).
  static const int manualCodeLength = 12;

  static final RegExp _ticketCode = RegExp(FirestoreIds.ticketCodePattern);

  /// Kameradan okunan ham QR içeriği [raw]: kırpılmaz, harf duyarlıdır
  /// (`FirestoreIds.parseTicketQr`). Çözülemezse `malformed`, başka
  /// etkinliğin biletiyse `otherEvent`.
  static TicketScanParse parseQr(String raw, {required String eventId}) {
    final ticket = FirestoreIds.parseTicketQr(raw);
    if (ticket == null) {
      return const TicketScanRejected(TicketScanRejection.malformed);
    }
    if (ticket.eventId != eventId) {
      return const TicketScanRejected(TicketScanRejection.otherEvent);
    }
    return TicketScanAccepted(eventId: ticket.eventId, code: ticket.code);
  }

  /// Elle girilen kod [input] ("Kodu gir"): [normalizeManual] sonrası
  /// `ticketCodePattern` ile eşleşmeli. Tam QR yükü yapıştırıldıysa
  /// ([parseQr] gibi) yük olarak çözülür.
  static TicketScanParse parseManual(String input, {required String eventId}) {
    final code = normalizeManual(input);
    if (_ticketCode.hasMatch(code)) {
      return TicketScanAccepted(eventId: eventId, code: code);
    }
    final pasted = input.trim();
    if (FirestoreIds.parseTicketQr(pasted) != null) {
      return parseQr(pasted, eventId: eventId);
    }
    return const TicketScanRejected(TicketScanRejection.malformed);
  }

  /// Elle girişin normal biçimi: kırpılmış ve büyük harfli (prototip
  /// `code.trim().toUpperCase()`; alfabe ASCII — yerel ayar dönüşümü
  /// gerekmez).
  static String normalizeManual(String input) => input.trim().toUpperCase();

  /// "Doğrula" etkin mi: normalleştirilmiş girdi en az [manualCodeLength]
  /// karakter.
  static bool canVerify(String input) =>
      normalizeManual(input).length >= manualCodeLength;
}
