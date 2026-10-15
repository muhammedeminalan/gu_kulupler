// MGT-07 testlerinin ortak verisi: tasarım yakalaması — `u_elif` (c01
// yönetim kurulu) → e17 "Veri Bilimi Söyleşisi" (5 katıldı / 52 kayıtlı).
// Saat yoklama penceresinin içindedir (e17 16:30–18:00 UTC; şimdi 17:00).
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/features/management/provider/scan_state.dart';
import 'package:gu_kulupler/product/service/permission_service.dart';

import '../../fakes/fake_event_repository.dart';
import '../../fakes/fake_permission_service.dart';
import '../../fakes/fake_rsvp_repository.dart';
import '../../fakes/fake_user_repository.dart';
import '../../fixtures/event_model_fixtures.dart';
import '../../fixtures/membership_model_fixtures.dart';
import '../../fixtures/rsvp_model_fixtures.dart';
import '../../fixtures/user_model_fixtures.dart';
import '../../helpers/fake_app_clock.dart';

/// Testlerdeki kulüp (`c01`).
const String kScanClubId = 'c01';

/// Testlerdeki etkinlik (`e17`).
const String kScanEventId = 'e17';

/// Oturumdaki yönetici (`u_elif`, c01 yönetim kurulu).
const String kScanUid = 'u_elif';

/// Yoklama penceresinin içindeki "şimdi".
final DateTime kScanNow = DateTime.utc(2026, 10, 8, 17);

/// e17 etkinliği.
final EventModel kScanEvent = EventModelFixtures.byId(kScanEventId);

/// e17 katılım kayıtları (5 `attended`, 47 `going`).
final List<RsvpModel> kScanRsvps = RsvpModelFixtures.ofEvent(kScanEventId);

/// İlk `going` kayıt (geçerli okutma).
RsvpModel get goingRsvp =>
    kScanRsvps.firstWhere((r) => r.status == RsvpStatus.going);

/// İlk `attended` kayıt (zaten okutulmuş).
RsvpModel get attendedRsvp =>
    kScanRsvps.firstWhere((r) => r.status == RsvpStatus.attended);

/// `c01` kulübünde [role] rolüyle aktif oturum (`u_elif`).
SessionState scanSession({ClubRole role = ClubRole.board}) => SessionState(
  status: AuthStatus.active,
  uid: kScanUid,
  onboardingSeen: true,
  user: UserModelFixtures.byId(kScanUid),
  memberships: {
    kScanClubId: MembershipModelFixtures.byId(
      FirestoreIds.membership(kScanClubId, kScanUid),
    ).copyWith(role: role),
  },
);

/// Tasarımdaki dolu durum (izin var, kamera açık).
ScanState loadedScanState({
  ScanCameraAccess cameraAccess = ScanCameraAccess.granted,
  bool manualOpen = false,
  String manualCode = '',
  bool torchOn = false,
}) => ScanState(
  access: ClubAccess.manager,
  event: kScanEvent,
  participants: kScanRsvps,
  cameraAccess: cameraAccess,
  manualOpen: manualOpen,
  manualCode: manualCode,
  torchOn: torchOn,
);

/// Kayıtlı fake'lere e17'yi, kayıtlarını, iki bilet sahibini ve okutanı
/// yazar; saati pencereye alır; kamera iznini [camera] yapar (`null` → izin
/// yok).
void seedScan({PermissionStatus? camera = PermissionStatus.granted}) {
  (GetIt.I<AppClock>() as FakeAppClock).set(kScanNow);
  (GetIt.I<EventRepository>() as FakeEventRepository).put(kScanEvent);
  kScanRsvps.forEach((GetIt.I<RsvpRepository>() as FakeRsvpRepository).put);
  (GetIt.I<UserRepository>() as FakeUserRepository).users.addAll({
    for (final uid in [
      goingRsvp.userId,
      attendedRsvp.userId,
      ?attendedRsvp.scannedBy,
    ])
      uid: UserModelFixtures.byId(uid),
  });
  final permissions = GetIt.I<PermissionService>() as FakePermissionService;
  if (camera != null) permissions.results[Permission.camera] = camera;
}
