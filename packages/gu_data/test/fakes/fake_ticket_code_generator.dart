// El yazımı test çifti (mock kütüphanesi yok — docs/testing.md §1.2).
import 'package:gu_data/gu_data.dart';

/// Sıralı ve tekrarlanabilir kodlar üreten [TicketCodeGenerator] test çifti
/// (PLAN §16.3).
///
/// Kodlar gerçek üreticiyle **aynı biçimdedir** (`FirestoreIds.ticketCodePattern`
/// / `supportTicketNoPattern` ile eşleşir), böylece model validator'ları ve
/// `FirestoreIds.parseTicketQr` testte de çalışır. Sıra numarası
/// [TicketCodeGenerator.alphabet] tabanında (32'lik) yazılır; `A` sıfırdır:
///
/// | Çağrı | [ticketCode]   | [supportTicketNo] |
/// |-------|----------------|-------------------|
/// | 1     | `GU-AAAA-AAAB` | `GU-AAAAAB`       |
/// | 2     | `GU-AAAA-AAAC` | `GU-AAAAAC`       |
/// | 32    | `GU-AAAA-AABA` | `GU-AAAABA`       |
///
/// Onluk sayaç (`GU-AAAA-0001`) kullanılmaz: `0` ve `1` alfabede yoktur, o
/// kod desenle eşleşmez (CD-129). İki sayaç birbirinden bağımsızdır.
final class FakeTicketCodeGenerator implements TicketCodeGenerator {
  final List<String> _ticketCodes = [];
  final List<String> _supportTicketNos = [];

  /// Şimdiye kadar üretilen bilet kodları, üretim sırasıyla.
  List<String> get issuedTicketCodes => List.unmodifiable(_ticketCodes);

  /// Şimdiye kadar üretilen destek talebi numaraları, üretim sırasıyla.
  List<String> get issuedSupportTicketNos =>
      List.unmodifiable(_supportTicketNos);

  @override
  String ticketCode() {
    final code = ticketCodeAt(_ticketCodes.length + 1);
    _ticketCodes.add(code);
    return code;
  }

  @override
  String supportTicketNo() {
    final ticketNo = supportTicketNoAt(_supportTicketNos.length + 1);
    _supportTicketNos.add(ticketNo);
    return ticketNo;
  }

  /// [n]. [ticketCode] çağrısının döndürdüğü kod ([n] 1'den başlar).
  ///
  /// Beklenen değeri testte elle yazmamak içindir. [n] `1 … 32⁴ − 1`
  /// aralığında değilse [RangeError] fırlatır.
  static String ticketCodeAt(int n) =>
      '$_prefix$_fixedGroup$_groupSeparator${_encode(n, _ticketGroupLength)}';

  /// [n]. [supportTicketNo] çağrısının döndürdüğü numara ([n] 1'den başlar).
  ///
  /// [n] `1 … 32⁶ − 1` aralığında değilse [RangeError] fırlatır.
  static String supportTicketNoAt(int n) =>
      '$_prefix${_encode(n, _supportLength)}';

  /// [n] sayısını alfabe tabanında, [width] karaktere soldan `A` ile
  /// doldurarak yazar.
  static String _encode(int n, int width) {
    const alphabet = TicketCodeGenerator.alphabet;
    var capacity = 1;
    for (var i = 0; i < width; i++) {
      capacity *= alphabet.length;
    }
    RangeError.checkValueInInterval(n, 1, capacity - 1, 'n');

    final chars = List.filled(width, alphabet[0]);
    var rest = n;
    for (var i = width - 1; i >= 0; i--) {
      chars[i] = alphabet[rest % alphabet.length];
      rest ~/= alphabet.length;
    }
    return chars.join();
  }

  static const String _prefix = 'GU-';
  static const String _fixedGroup = 'AAAA';
  static const String _groupSeparator = '-';
  static const int _ticketGroupLength = 4;
  static const int _supportLength = 6;
}
