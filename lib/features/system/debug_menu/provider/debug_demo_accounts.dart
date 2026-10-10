/// Demo hesabın rolü — `design/extracted/registry.json#demoAccounts[].roleKey`
/// (`role.<ad>`).
enum DebugDemoRole {
  /// `role.student` — hiçbir kulüpte üyeliği olmayan öğrenci.
  student,

  /// `role.member` — kulüp üyesi.
  member,

  /// `role.board` — yönetim kurulu üyesi.
  board,

  /// `role.president` — kulüp başkanı.
  president,

  /// `role.advisor` — kulüp danışmanı.
  advisor,

  /// `role.superadmin` — süper admin.
  superadmin,
}

/// Emülatör demo hesabı: [id] seed'deki kullanıcı kimliğidir (Auth `uid` ve
/// `users/{id}` belgesi), [email] `tool/seed/demo-data.json#users[id].email`.
final class DebugDemoAccount {
  /// Demo hesabı oluşturur.
  const DebugDemoAccount({
    required this.id,
    required this.email,
    required this.role,
  });

  /// Kullanıcı kimliği (`u_ayse` …).
  final String id;

  /// Giriş e-postası.
  final String email;

  /// Hesabın rolü (satır etiketi).
  final DebugDemoRole role;
}

/// DebugMenu demo hesapları (PLAN §4.5 `debug_menu/`; prototip kontrol
/// panelinin hesap değiştiricisi, mock — K-02).
///
/// **Yalnızca emülatörde** kullanılır (`AppEnvironment.isEmulator`):
/// hesapları `tool/seed/seed_emulator.js` yerel Auth emülatörüne yazar; gerçek
/// projede bu hesaplar yoktur. Liste ve [password] seed dosyasının kopyasıdır;
/// eşitliği `debug_demo_accounts_test.dart` doğrular (seed değişirse test
/// kırılır).
abstract final class DebugDemoAccounts {
  /// Emülatör demo parolası — `tool/seed/demo-data.json#meta.demoPassword`.
  /// Gerçek bir kimlik bilgisi değildir: yalnızca yerel emülatördeki kurgusal
  /// hesaplarda geçerlidir.
  static const String password = 'Demo1234!';

  /// `registry.json#demoAccounts` sırasıyla altı hesap.
  static const List<DebugDemoAccount> all = [
    DebugDemoAccount(
      id: 'u_ayse',
      email: 'ayse.demir@ogr.gumushane.edu.tr',
      role: DebugDemoRole.student,
    ),
    DebugDemoAccount(
      id: 'u_mehmet',
      email: 'mehmet.kaya@ogr.gumushane.edu.tr',
      role: DebugDemoRole.member,
    ),
    DebugDemoAccount(
      id: 'u_elif',
      email: 'elif.yildiz@ogr.gumushane.edu.tr',
      role: DebugDemoRole.board,
    ),
    DebugDemoAccount(
      id: 'u_burak',
      email: 'burak.sahin@ogr.gumushane.edu.tr',
      role: DebugDemoRole.president,
    ),
    DebugDemoAccount(
      id: 'u_zeynep',
      email: 'zeynep.arslan@gumushane.edu.tr',
      role: DebugDemoRole.advisor,
    ),
    DebugDemoAccount(
      id: 'u_admin',
      email: 'admin@gumushane.edu.tr',
      role: DebugDemoRole.superadmin,
    ),
  ];
}
