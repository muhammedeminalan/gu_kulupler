import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/event/ticket_scan_parser.dart';

/// MGT-07 kamera erişimi.
enum ScanCameraAccess {
  /// İzin henüz denetleniyor / DLG-04 açık (önizleme yok, katman çizilir).
  checking,

  /// İzin var: kamera açılabilir.
  granted,

  /// İzin yok (DLG-04'te vazgeçildi ya da sistem reddetti): izin ekranı
  /// ("Kamera izni gerekli" · "Kod gir" · "Ayarlara git").
  denied,
}

/// SHT-24'te gösterilen son okutma sonucu (`ScanResultSheet` girdisi).
final class ScanResult extends Equatable {
  /// [outcome] sonucu.
  const ScanResult({
    required this.outcome,
    this.user,
    this.scannedAt,
    this.attended,
    this.registered,
    this.rejection,
    this.windowClosed = false,
    this.scannedByName,
  });

  /// Okutma sonucu.
  final ScanOutcome outcome;

  /// Biletin sahibi (geçerli / zaten okutulmuş); bilinmiyorsa `null`.
  final UserModel? user;

  /// Önceki okutma anı (UTC; zaten okutulmuş).
  final DateTime? scannedAt;

  /// Geçerli sonuçta katılan sayısı (sayaç).
  final int? attended;

  /// Geçerli sonuçta kayıtlı sayısı (sayaç).
  final int? registered;

  /// İstemci ön denetiminin ret nedeni (ağa çıkılmadı); sunucu sonucu ise
  /// `null`.
  final TicketScanRejection? rejection;

  /// Sunucu yoklama penceresi dışında reddetti (K-G).
  final bool windowClosed;

  /// Önceki okutmayı yapanın adı (zaten okutulmuş); bilinmiyorsa `null`.
  final String? scannedByName;

  /// SHT-24 sayacı; yalnızca geçerli sonuçta.
  ({int attended, int registered})? get counter =>
      outcome == ScanOutcome.valid && attended != null && registered != null
      ? (attended: attended!, registered: registered!)
      : null;

  @override
  List<Object?> get props => [
    outcome,
    user,
    scannedAt,
    attended,
    registered,
    rejection,
    windowClosed,
    scannedByName,
  ];
}

/// MGT-07 "QR tarayıcı" ekranının durumu (PLAN §4.2 `ScanViewModel`).
///
/// * [participants] etkinliğin katılım kayıtları (canlı —
///   `attendanceRepository.watchParticipants`): sayaç ("Katıldı a/b") ve
///   okutulan biletin sahibi / önceki okutma anı buradan okunur.
/// * Kamera yalnızca [isCameraActive] iken açıktır: izin var ve sonuç
///   (SHT-24) ya da okutma sürmüyor ([isPaused]).
final class ScanState extends Equatable {
  /// Varsayılan: izin denetleniyor, içerik yok.
  const ScanState({
    this.access = ClubAccess.visitor,
    this.event,
    this.participants = const [],
    this.cameraAccess = ScanCameraAccess.checking,
    this.torchOn = false,
    this.frontCamera = false,
    this.manualOpen = false,
    this.manualCode = '',
    this.isProcessing = false,
    this.isShowingResult = false,
    this.lastResult,
  });

  /// Oturumdaki kullanıcının kulübe erişimi.
  final ClubAccess access;

  /// Etkinlik (üst satır başlığı); okunamadıysa `null`.
  final EventModel? event;

  /// Etkinliğin katılım kayıtları.
  final List<RsvpModel> participants;

  /// Kamera izni.
  final ScanCameraAccess cameraAccess;

  /// Fener açık mı (`MGT-07.torch`).
  final bool torchOn;

  /// Ön kamera mı (`MGT-07.flip`).
  final bool frontCamera;

  /// Elle kod alanı açık mı (`MGT-07.manualCode`).
  final bool manualOpen;

  /// Elle girilen kod (büyük harfli).
  final String manualCode;

  /// Okutma sunucuya gidiyor (yeni okuma yok sayılır).
  final bool isProcessing;

  /// SHT-24 açık (tarama durur; kapanınca sürer).
  final bool isShowingResult;

  /// Son gösterilen sonuç.
  final ScanResult? lastResult;

  /// Danışman bakışı (Q-09): okutamaz (guard `M`; savunma amaçlı).
  bool get isReadOnly => access == ClubAccess.advisor;

  /// Okuma durdu: okutma ya da sonuç sürüyor.
  bool get isPaused => isProcessing || isShowingResult;

  /// Kamera açık olmalı mı.
  bool get isCameraActive =>
      cameraAccess == ScanCameraAccess.granted && !isPaused;

  /// İzin ekranı çizilir: izin yok ve elle giriş seçilmedi.
  bool get showPermissionScreen =>
      cameraAccess == ScanCameraAccess.denied && !manualOpen;

  /// "Doğrula" etkin mi (`TicketScanParser.canVerify`).
  bool get canVerify => TicketScanParser.canVerify(manualCode) && !isPaused;

  /// Katılan sayısı (`attended`).
  int get attendedCount =>
      participants.where((r) => r.status == RsvpStatus.attended).length;

  /// Kayıtlı sayısı (`going` + `attended`; prototip `sel().registered`).
  int get registeredCount => participants
      .where(
        (r) => r.status == RsvpStatus.going || r.status == RsvpStatus.attended,
      )
      .length;

  /// [code] biletinin kaydı; yoksa `null`.
  RsvpModel? findByCode(String code) {
    for (final rsvp in participants) {
      if (rsvp.ticketCode == code) return rsvp;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    access,
    event,
    participants,
    cameraAccess,
    torchOn,
    frontCamera,
    manualOpen,
    manualCode,
    isProcessing,
    isShowingResult,
    lastResult,
  ];

  /// Kopya; `clearLastResult` / `clearEvent` alanı boşaltır.
  ScanState copyWith({
    ClubAccess? access,
    EventModel? event,
    List<RsvpModel>? participants,
    ScanCameraAccess? cameraAccess,
    bool? torchOn,
    bool? frontCamera,
    bool? manualOpen,
    String? manualCode,
    bool? isProcessing,
    bool? isShowingResult,
    ScanResult? lastResult,
    bool clearLastResult = false,
    bool clearEvent = false,
  }) => ScanState(
    access: access ?? this.access,
    event: clearEvent ? null : event ?? this.event,
    participants: participants ?? this.participants,
    cameraAccess: cameraAccess ?? this.cameraAccess,
    torchOn: torchOn ?? this.torchOn,
    frontCamera: frontCamera ?? this.frontCamera,
    manualOpen: manualOpen ?? this.manualOpen,
    manualCode: manualCode ?? this.manualCode,
    isProcessing: isProcessing ?? this.isProcessing,
    isShowingResult: isShowingResult ?? this.isShowingResult,
    lastResult: clearLastResult ? null : lastResult ?? this.lastResult,
  );
}
