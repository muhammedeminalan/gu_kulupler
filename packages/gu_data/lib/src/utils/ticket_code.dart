import 'dart:math';

import 'package:meta/meta.dart';

/// Bilet kodu ve destek talebi numarası üreticisi (PLAN §9.1, §10.3; D-30).
///
/// `gu_data` içinde rastgelelik yalnızca bu arayüzden gelir; repository'ler
/// `Random`'ı doğrudan çağırmaz (testte `FakeTicketCodeGenerator`). Biçim
/// desenleri ve QR yükü `FirestoreIds` içindedir (`ticketCodePattern`,
/// `supportTicketNoPattern`, `ticketQrPayload`, `parseTicketQr`).
abstract interface class TicketCodeGenerator {
  /// Kod alfabesi: 32 karakter, okurken karışan `I`, `O`, `0`, `1` yok.
  static const String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Yeni bilet kodu: `GU-XXXX-XXXX` (`rsvps.ticketCode`).
  String ticketCode();

  /// Yeni destek talebi numarası: `GU-XXXXXX` (`supportTickets.ticketNo`).
  String supportTicketNo();
}

/// Kriptografik rastgele kaynakla ([Random.secure]) kod üretir (D-30).
///
/// Her karakter [TicketCodeGenerator.alphabet] içinden bağımsız ve eşit
/// olasılıkla seçilir: bilet kodu 8 karakter (40 bit), destek numarası
/// 6 karakter (30 bit). Tekillik garantisi vermez; kod yalnızca etkinliğe
/// kapsamlı Firestore aramasıyla doğrulanır.
final class SecureTicketCodeGenerator implements TicketCodeGenerator {
  /// Üretim kurucusu: kaynak [Random.secure].
  SecureTicketCodeGenerator() : _random = Random.secure();

  /// Test kurucusu: tohumlu ya da betikli bir [Random] ile tekrarlanabilir
  /// üretim. Üretim kodunda **kullanılmaz** (kodlar tahmin edilebilir olur).
  @visibleForTesting
  SecureTicketCodeGenerator.withRandom(Random random) : _random = random;

  final Random _random;

  @override
  String ticketCode() =>
      '$_prefix${_group(_ticketGroupLength)}'
      '$_groupSeparator${_group(_ticketGroupLength)}';

  @override
  String supportTicketNo() => '$_prefix${_group(_supportLength)}';

  /// [length] karakterlik rastgele parça.
  String _group(int length) {
    const alphabet = TicketCodeGenerator.alphabet;
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(alphabet[_random.nextInt(alphabet.length)]);
    }
    return buffer.toString();
  }

  static const String _prefix = 'GU-';
  static const String _groupSeparator = '-';
  static const int _ticketGroupLength = 4;
  static const int _supportLength = 6;
}
