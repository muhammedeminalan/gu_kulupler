// Fixture: ToastSpec kayıtları — buradaki ToastId.* satırları kullanım (KUL01) sayılmaz.
/// Design: TST-X1
class ToastCatalog {
  static Object of(ToastId id) => switch (id) {
    ToastId.tst01 => 'hata',
    ToastId.tstX1 => 'bilgi',
  };
}
