/// Fixture: MenuId (CD-113) — registry.json#menus.
enum MenuId {
  /// Design: SHT-01 — Dil (açılır menü biçimi)
  sht01('SHT-01'),

  /// Design: EVT-MENU — Etkinlik menüsü
  evtMenu('EVT-MENU');

  const MenuId(this.designId);

  final String designId;
}
