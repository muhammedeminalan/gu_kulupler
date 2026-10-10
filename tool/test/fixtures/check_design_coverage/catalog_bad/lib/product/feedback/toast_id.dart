/// Fixture: ToastId (TST-58 muaf, enum'a girmez).
enum ToastId {
  /// Design: TST-01
  tst01,

  /// Design: TST-X1
  tstX1;

  String get designId => 'TST-${name.substring(3)}';
}
