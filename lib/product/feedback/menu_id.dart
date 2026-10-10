/// Kayıtlı açılır menü kimlikleri — `registry.json#menus` (2; CD-113).
///
/// Satır içi 11 menü (CD-83 + NTF-01) kimliksizdir: `showMenu(id: null, …)`.
/// Her üyenin üstündeki `/// Design:` izi `tool/check_design_coverage.js`
/// KAT01–KAT04 ile doğrulanır. Açılış tek girişten:
/// `FeedbackService.showMenu(id: MenuId.evtMenu, …)` (CLAUDE.md §7).
enum MenuId {
  /// Design: SHT-01 — Dil (açılır menü biçimi)
  sht01('SHT-01'),

  /// Design: EVT-MENU — Etkinlik menüsü
  evtMenu('EVT-MENU');

  const MenuId(this.designId);

  /// Tasarım kimliği (`design/extracted/registry.json#menus`).
  final String designId;
}
