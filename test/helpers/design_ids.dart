// Tasarım kimlikleri: `design/extracted/registry.json` +
// `design/extracted/screens-actions.json` (PLAN §16.2). Envanter (L2)
// testleri, aksiyon envanteri ve tasarım-ID'li test adları buradan okur.
import 'package:equatable/equatable.dart';

import 'design_files.dart';

/// Bir ekranın tasarım üst verisi (registry `screens[]` + screens-actions).
final class ScreenMeta extends Equatable {
  const ScreenMeta({
    required this.id,
    required this.tab,
    required this.titleKey,
    required this.path,
    required this.roles,
    required this.user,
    required this.actions,
  });

  /// Ekran kimliği (`<ÖNEK>-<nn>`).
  final String id;

  /// Sekme (`clubs`, `events`, …); sekmesiz ekranlarda `null`.
  final String? tab;

  /// Prototip başlık anahtarı (`sys.splash.title`).
  final String titleKey;

  /// Prototip rotası (`/clubs/:id`).
  final String path;

  /// Envanter rol alanı: `all` · `guest` · `member` · `manager` · `admin`.
  final String roles;

  /// Yakalamadaki demo kullanıcı (`u_ayse`); misafir ekranlarında `null`.
  final String? user;

  /// 390×844 yakalamasındaki aksiyon anahtarları (D-18).
  final List<String> actions;

  @override
  List<Object?> get props => [id, tab, titleKey, path, roles, user, actions];
}

abstract final class DesignIds {
  static final Map<String, dynamic> _registry = readJsonMap(
    'design/extracted/registry.json',
  );

  static final Map<String, dynamic> _inventory = readJsonMap(
    'design/extracted/screens-actions.json',
  );

  static List<String> _ids(String section) => [
    for (final e in _registry[section] as List<dynamic>)
      (e as Map<String, dynamic>)['id'] as String,
  ];

  /// 51 ekran kimliği (registry sırası).
  static List<String> get screens => _ids('screens');

  /// 34 sheet kimliği.
  static List<String> get sheets => _ids('sheets');

  /// 32 dialog kimliği.
  static List<String> get dialogs => _ids('dialogs');

  /// 78 toast kimliği (enum dışı muaf toast dahil; muafiyet katalogda).
  static List<String> get toasts => _ids('toasts');

  /// 2 menü kimliği (`registry.menus`).
  static List<String> get menus =>
      (_registry['menus'] as List<dynamic>).cast<String>();

  /// Sekme → kök ekran (`registry.tabRoot`; 5 sekme).
  static Map<String, String> get tabRoots =>
      (_registry['tabRoot'] as Map<String, dynamic>).cast<String, String>();

  /// Ekran kimliği → [ScreenMeta] (registry sırası).
  static final Map<String, ScreenMeta> screenMeta = {
    for (final e
        in (_registry['screens'] as List<dynamic>).cast<Map<String, dynamic>>())
      e['id'] as String: _meta(e),
  };

  static ScreenMeta _meta(Map<String, dynamic> screen) {
    final id = screen['id'] as String;
    final inv = _inventory[id] as Map<String, dynamic>?;
    if (inv == null) {
      throw StateError('screens-actions.json içinde $id yok');
    }
    return ScreenMeta(
      id: id,
      tab: screen['tab'] as String?,
      titleKey: screen['titleKey'] as String,
      path: inv['path'] as String,
      roles: inv['roles'] as String,
      user: inv['user'] as String?,
      actions: List.unmodifiable(
        (inv['actions'] as List<dynamic>).cast<String>(),
      ),
    );
  }
}
