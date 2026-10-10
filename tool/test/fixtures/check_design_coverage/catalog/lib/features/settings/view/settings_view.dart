// Fixture: sahip task'ın görünümü — sınıf izleri ve katalog dışı kullanım.
/// Design: SHT-01
class LanguageSheet {}

/// Design: DLG-01
class AccountDialog {}

class SettingsView {
  void open(dynamic feedback) {
    feedback.showSheet(SheetId.sht01);
    feedback.showDialog(DialogId.dlg01);
    feedback.showToast(ToastId.tst01);
    feedback.showMenu(id: MenuId.evtMenu);
  }
}
