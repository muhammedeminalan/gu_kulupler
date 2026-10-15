import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/constants/app_durations.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/scan_state.dart';
import 'package:gu_kulupler/features/management/view/widget/scan_result_sheet.dart';
import 'package:gu_kulupler/product/event/ticket_scan_parser.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/permission_prompt_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:gu_kulupler/product/service/permission_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'scan_view_model.g.dart';

/// MGT-07 "QR tarayıcı" ViewModel'i (PLAN §4.2; prototip `Scanner`,
/// `screens-manage.js:142–157`). Etkinlik başına ayrı örnek (family
/// `clubId`, `eventId`).
///
/// * Kamera oturumu view'dadır (`QrScannerController`); ViewModel yalnızca
///   okunan içeriği ([onCode]) ve elle girilen kodu ([verifyManual]) işler,
///   kameranın açık olup olmayacağını [ScanState.isCameraActive] söyler.
/// * İzin: açılışta `ensureCameraAccess` (DLG-04 → sistem izni; ret →
///   TST-32). Yoksa izin ekranı; "Ayarlara git" [retryPermission], uygulamaya
///   dönüş [recheckPermission].
/// * Okuma: `TicketScanParser` (biçim / başka etkinlik → ağa çıkmadan
///   "Geçersiz bilet") → `attendanceRepository.scanTicket` → SHT-24. Sonuç
///   açıkken ve okutma sürerken okuma yok sayılır; aynı içerik
///   [repeatScanCooldown] içinde yeniden okunursa yok sayılır.
///
/// | Girdi | Sonuç | Geri bildirim |
/// |---|---|---|
/// | biçimsiz / başka etkinliğin QR'ı | yazım yok | SHT-24 "Geçersiz bilet" |
/// | `scanTicket` → valid | `going → attended` | SHT-24 "Geçerli bilet" (2 sn oto-kapanma) |
/// | `scanTicket` → alreadyScanned / invalid | yazım yok | SHT-24 |
/// | pencere dışı (K-G) / çakışma | yazım yok | SHT-24 "Geçersiz bilet" |
/// | çevrimdışı / ağ · yetki | yazım yok | TST-24 · TST-X18 |
/// | danışman (savunma) | yazım yok | TST-26 |
///
/// Design: MGT-07
@riverpod
final class ScanViewModel extends _$ScanViewModel
    with ProjectDependencyMixin, WriteGuardMixin, PermissionPromptMixin {
  /// Aynı içeriğin art arda okunmasının yok sayıldığı süre: son okumadan ya
  /// da SHT-24 kapanıp taramanın sürdüğü andan itibaren (bilet kamerada
  /// kalınca yeniden "Zaten okutulmuş" açılmasın).
  static const Duration repeatScanCooldown = AppDurations.scanRepeatCooldown;

  StreamSubscription<FirestoreResult<List<RsvpModel>>>? _participants;
  final Map<String, UserModel> _users = <String, UserModel>{};
  String? _lastRaw;
  DateTime? _lastAt;

  @override
  ScanState build(String clubId, String eventId) {
    ref
      ..onDispose(() => unawaited(_participants?.cancel()))
      ..listen(sessionViewModelProvider, (_, session) {
        final access = session.accessTo(clubId);
        if (access != state.access) state = state.copyWith(access: access);
      });
    // Okuma ve izin denetimi ilk karede başlar; view ayrıca çağırmaz.
    unawaited(Future<void>.microtask(_start));
    return ScanState(
      access: ref.read(sessionViewModelProvider).accessTo(clubId),
    );
  }

  String? get _uid =>
      ref.mounted ? ref.read(sessionViewModelProvider).uid : null;

  // ───────────────────────────────── izin ───────────────────────────────────

  /// "Ayarlara git" (`MGT-07.permission.retry`): sistem yeniden sorabiliyorsa
  /// izni yeniden ister, sormuyorsa (kalıcı ret) uygulama ayarlarını açar.
  Future<void> retryPermission() async {
    final status = await permissionService.status(Permission.camera);
    if (!ref.mounted) return;
    if (status.isUsable) return _grant();
    if (status.needsSettings) {
      await permissionService.openAppSettings();
      return;
    }
    final requested = await permissionService.requestCamera();
    if (!ref.mounted) return;
    if (requested.isUsable) {
      _grant();
    } else if (requested.needsSettings) {
      await permissionService.openAppSettings();
    }
  }

  /// Uygulamaya dönüldü (ayarlardan): izin verildiyse kamera açılır.
  Future<void> recheckPermission() async {
    if (!ref.mounted || state.cameraAccess != ScanCameraAccess.denied) return;
    if (await permissionService.isGranted(Permission.camera)) _grant();
  }

  void _grant() {
    if (!ref.mounted) return;
    state = state.copyWith(
      cameraAccess: ScanCameraAccess.granted,
      manualOpen: false,
    );
  }

  // ─────────────────────────────── kontroller ───────────────────────────────

  /// Fener (`MGT-07.torch`); kamerayı view çevirir.
  void toggleTorch() => state = state.copyWith(torchOn: !state.torchOn);

  /// Kamera çevir (`MGT-07.flip`); kamerayı view çevirir.
  void flipCamera() => state = state.copyWith(frontCamera: !state.frontCamera);

  /// "Kod gir" (`MGT-07.manualCode`): elle kod alanını açar.
  void openManual() => state = state.copyWith(manualOpen: true);

  /// Kod alanı (`MGT-07.codeInput`): büyük harfli saklanır.
  void setManualCode(String value) =>
      state = state.copyWith(manualCode: value.toUpperCase());

  // ──────────────────────────────── okutma ──────────────────────────────────

  /// Kameradan okunan ham QR içeriği [raw].
  Future<void> onCode(String raw) async {
    if (!ref.mounted || state.isPaused) return;
    final now = appClock.nowUtc();
    final last = _lastAt;
    if (raw == _lastRaw &&
        last != null &&
        now.difference(last) < repeatScanCooldown) {
      return;
    }
    _lastRaw = raw;
    _lastAt = now;
    await _process(TicketScanParser.parseQr(raw, eventId: eventId));
  }

  /// "Doğrula" (`MGT-07.verify`) / klavye "bitti": elle girilen kod.
  /// Bilet bulunduysa (geçerli / zaten okutulmuş) alan temizlenip kapanır;
  /// geçersizde kod düzeltilsin diye kalır (prototip `verify`).
  Future<void> verifyManual() async {
    if (!ref.mounted || !state.canVerify) return;
    final parse = TicketScanParser.parseManual(
      state.manualCode,
      eventId: eventId,
    );
    final outcome = await _process(parse);
    if (!ref.mounted) return;
    if (outcome == ScanOutcome.valid || outcome == ScanOutcome.alreadyScanned) {
      state = state.copyWith(manualCode: '', manualOpen: false);
    }
  }

  /// [parse] sonucunu işler; sunucunun okutma sonucunu (gösterildiyse)
  /// döndürür.
  Future<ScanOutcome?> _process(TicketScanParse parse) async {
    if (state.isReadOnly) {
      feedback.showToast(ToastId.tst26);
      return null;
    }
    switch (parse) {
      case TicketScanRejected(:final reason):
        await _showResult(
          ScanResult(outcome: ScanOutcome.invalid, rejection: reason),
        );
        return null;
      case TicketScanAccepted(:final code, :final payload):
        final uid = _uid;
        if (uid == null || !ensureOnline()) return null;
        state = state.copyWith(isProcessing: true);
        final result = await attendanceRepository.scanTicket(
          eventId: eventId,
          clubId: clubId,
          qrPayload: payload,
          actorId: uid,
        );
        if (!ref.mounted) return null;
        switch (result) {
          case FirebaseSuccess(data: final outcome):
            await _showResult(await _resultOf(outcome, code));
            return outcome;
          case FirebaseFailure(
            error: final FirestoreError error &&
                (FirestoreError.ruleViolation || FirestoreError.conflict),
            :final detail,
          ):
            // Pencere dışı (K-G) ya da kayıt bu arada değişti: okutulmadı.
            AppLogger.info('Bilet okutulamadı: ${error.name} $detail');
            await _showResult(
              ScanResult(
                outcome: ScanOutcome.invalid,
                windowClosed:
                    detail is FirestoreFailureDetail &&
                    detail.code == FirestoreRuleCode.attendanceWindowClosed,
              ),
            );
          case FirebaseFailure(:final error, :final message):
            state = state.copyWith(isProcessing: false);
            if (!showWriteFailureToast(error)) {
              AppLogger.warn(
                'Bilet okutulamadı: ${error.name}',
                error: message,
              );
              await _showResult(
                const ScanResult(outcome: ScanOutcome.invalid),
              );
            }
        }
        return null;
    }
  }

  /// [outcome] sonucunu SHT-24 girdisine çevirir; geçerliyse kayıt listede
  /// hemen `attended` olur (canlı akış sonra uzlaştırır).
  Future<ScanResult> _resultOf(ScanOutcome outcome, String code) async {
    final rsvp = state.findByCode(code);
    switch (outcome) {
      case ScanOutcome.valid:
        if (rsvp != null && rsvp.status != RsvpStatus.attended) {
          final attended = rsvp.copyWith(
            status: RsvpStatus.attended,
            scannedAt: appClock.nowUtc(),
          );
          state = state.copyWith(
            participants: [
              for (final r in state.participants)
                r.id == rsvp.id ? attended : r,
            ],
          );
        }
        return ScanResult(
          outcome: outcome,
          user: await _userOf(rsvp?.userId),
          attended: state.attendedCount,
          registered: state.registeredCount,
        );
      case ScanOutcome.alreadyScanned:
        final scanner = await _userOf(rsvp?.scannedBy);
        return ScanResult(
          outcome: outcome,
          user: await _userOf(rsvp?.userId),
          scannedAt: rsvp?.scannedAt,
          scannedByName: scanner == null || scanner.isAnonymized
              ? null
              : scanner.name,
        );
      case ScanOutcome.invalid:
        return ScanResult(outcome: outcome);
    }
  }

  Future<UserModel?> _userOf(String? uid) async {
    if (uid == null) return null;
    if (_users[uid] case final user?) return user;
    final result = await userRepository.getUser(uid);
    if (result case FirebaseSuccess(data: final user?)) _users[uid] = user;
    return _users[uid];
  }

  /// Geçersiz sonucun SHT-24 açıklaması: biçimsiz QR → okunamadı; pencere
  /// dışı → pencere metni; başka etkinlik / bulunamadı → "bu etkinliğe ait
  /// değil".
  static ScanInvalidReason? _invalidReason(ScanResult result) {
    if (result.outcome != ScanOutcome.invalid) return null;
    if (result.windowClosed) return ScanInvalidReason.windowClosed;
    if (result.rejection == TicketScanRejection.malformed) {
      return ScanInvalidReason.unreadable;
    }
    return ScanInvalidReason.notForEvent;
  }

  /// SHT-24'ü açar; açıkken tarama durur, kapanınca sürer.
  Future<void> _showResult(ScanResult result) async {
    if (!ref.mounted) return;
    state = state.copyWith(
      isProcessing: false,
      isShowingResult: true,
      lastResult: result,
    );
    await feedback.showSheet<ScanResultSheetAction>(
      SheetId.sht24,
      builder: (_) => ScanResultSheet(
        outcome: result.outcome,
        user: result.user,
        scannedAt: result.scannedAt,
        counter: result.counter,
        invalidReason: _invalidReason(result),
        scannedByName: result.scannedByName,
      ),
    );
    if (!ref.mounted) return;
    _lastAt = appClock.nowUtc();
    state = state.copyWith(isShowingResult: false);
  }

  // ───────────────────────────────── okuma ──────────────────────────────────

  Future<void> _start() async {
    if (!ref.mounted) return;
    unawaited(_loadEvent());
    _participants = attendanceRepository
        .watchParticipants(eventId: eventId, clubId: clubId)
        .listen(_onParticipants);
    final granted = await ensureCameraAccess();
    if (!ref.mounted) return;
    state = state.copyWith(
      cameraAccess: granted
          ? ScanCameraAccess.granted
          : ScanCameraAccess.denied,
    );
  }

  Future<void> _loadEvent() async {
    final result = await eventRepository.getEvent(eventId);
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess(:final data) when !data.isDeleted:
        state = state.copyWith(event: data);
      case FirebaseSuccess():
        break;
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn('Etkinlik okunamadı: ${error.name}', error: message);
    }
  }

  void _onParticipants(FirestoreResult<List<RsvpModel>> result) {
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess(:final data):
        state = state.copyWith(participants: data);
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Katılımcılar dinlenemedi: ${error.name}',
          error: message,
        );
    }
  }
}
