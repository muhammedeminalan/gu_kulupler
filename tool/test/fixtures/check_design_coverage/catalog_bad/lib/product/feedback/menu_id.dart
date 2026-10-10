/// Fixture: MenuId — evtMenu eksik (KAT02), sht01 izi yanlış (KAT04), clbMenu fazla (KAT03).
enum MenuId {
  /// Design: SHT-02
  sht01('SHT-01'),

  /// Design: EVT-MENU
  clbMenu('CLB-MENU');

  const MenuId(this.designId);

  final String designId;
}
