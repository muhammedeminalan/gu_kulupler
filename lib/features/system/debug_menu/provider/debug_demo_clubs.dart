/// Demo kulübün katılım biçimi (satır etiketi).
enum DebugDemoClubKind {
  /// Onay gerektirmez: "Katıl" doğrudan üye yapar (TST-34).
  instant,

  /// Onay gerekir: "Katıl" başvuru formunu açar (SHT-05 → CLB-04).
  approval,

  /// Başvurular kapalı: düğme devre dışıdır (TST-X1).
  closed,
}

/// Emülatör demo kulübü: [id] seed'deki kulüp kimliğidir
/// (`tool/seed/demo-data.json#clubs[id]`).
final class DebugDemoClub {
  /// Demo kulüp kaydı oluşturur.
  const DebugDemoClub({required this.id, required this.kind});

  /// Kulüp kimliği (`c03` …).
  final String id;

  /// Kulübün katılım biçimi.
  final DebugDemoClubKind kind;
}

/// DebugMenu "Demo kulüpler" kısayolları — CLB-03'e doğrudan giriş.
///
/// **Yalnızca emülatörde** kullanılır (`AppEnvironment.isEmulator`): kulüpleri
/// `tool/seed/seed_emulator.js` yerel emülatöre yazar. Her katılım biçiminden
/// bir kulüp vardır; biçimlerin seed ile eşliğini
/// `debug_demo_clubs_test.dart` doğrular (seed değişirse test kırılır).
// TODO(T-17): Kulüpler listesi (CLB-01) gelince kulübe oradan ulaşılır; bu
// kısayollar kaldırılır.
abstract final class DebugDemoClubs {
  /// Üç kulüp: anında katılım, onay gerekli (not zorunlu), başvuru kapalı.
  static const List<DebugDemoClub> all = [
    DebugDemoClub(id: 'c07', kind: DebugDemoClubKind.instant),
    DebugDemoClub(id: 'c03', kind: DebugDemoClubKind.approval),
    DebugDemoClub(id: 'c05', kind: DebugDemoClubKind.closed),
  ];
}
