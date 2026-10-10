/// Toast kimlikleri — `registry.json#toasts` 78 kimliğin 77'si.
///
/// `TST-58` ("Demo: … açılıyor") yalnızca demodur ve enum'a girmez
/// (`docs/task-map.json#excluded`, K-02; KAT03). Her üyenin üstündeki
/// `/// Design: TST-nn` izi `tool/check_design_coverage.js` KAT01–KAT04 ile
/// doğrulanır. Metin / tür / eylem: `ToastCatalog`. Gösterim tek girişten:
/// `FeedbackService.showToast(ToastId.tstNN)` (CLAUDE.md §7).
enum ToastId {
  /// Design: TST-01
  tst01,

  /// Design: TST-02
  tst02,

  /// Design: TST-03
  tst03,

  /// Design: TST-04
  tst04,

  /// Design: TST-05
  tst05,

  /// Design: TST-06
  tst06,

  /// Design: TST-07
  tst07,

  /// Design: TST-08
  tst08,

  /// Design: TST-09
  tst09,

  /// Design: TST-10
  tst10,

  /// Design: TST-11
  tst11,

  /// Design: TST-12
  tst12,

  /// Design: TST-13
  tst13,

  /// Design: TST-14
  tst14,

  /// Design: TST-15
  tst15,

  /// Design: TST-16
  tst16,

  /// Design: TST-17
  tst17,

  /// Design: TST-18
  tst18,

  /// Design: TST-19
  tst19,

  /// Design: TST-20
  tst20,

  /// Design: TST-21
  tst21,

  /// Design: TST-22
  tst22,

  /// Design: TST-23
  tst23,

  /// Design: TST-24
  tst24,

  /// Design: TST-25
  tst25,

  /// Design: TST-26
  tst26,

  /// Design: TST-27
  tst27,

  /// Design: TST-28
  tst28,

  /// Design: TST-29
  tst29,

  /// Design: TST-30
  tst30,

  /// Design: TST-31
  tst31,

  /// Design: TST-32
  tst32,

  /// Design: TST-33
  tst33,

  /// Design: TST-34
  tst34,

  /// Design: TST-35
  tst35,

  /// Design: TST-36
  tst36,

  /// Design: TST-37
  tst37,

  /// Design: TST-38
  tst38,

  /// Design: TST-39
  tst39,

  /// Design: TST-40
  tst40,

  /// Design: TST-41
  tst41,

  /// Design: TST-42
  tst42,

  /// Design: TST-43
  tst43,

  /// Design: TST-44
  tst44,

  /// Design: TST-45
  tst45,

  /// Design: TST-46
  tst46,

  /// Design: TST-47
  tst47,

  /// Design: TST-48
  tst48,

  /// Design: TST-49
  tst49,

  /// Design: TST-50
  tst50,

  /// Design: TST-51
  tst51,

  /// Design: TST-52
  tst52,

  /// Design: TST-53
  tst53,

  /// Design: TST-54
  tst54,

  /// Design: TST-55
  tst55,

  /// Design: TST-56
  tst56,

  /// Design: TST-57
  tst57,

  /// Design: TST-X1
  tstX1,

  /// Design: TST-X2
  tstX2,

  /// Design: TST-X3
  tstX3,

  /// Design: TST-X4
  tstX4,

  /// Design: TST-X5
  tstX5,

  /// Design: TST-X6
  tstX6,

  /// Design: TST-X7
  tstX7,

  /// Design: TST-X8
  tstX8,

  /// Design: TST-X9
  tstX9,

  /// Design: TST-X10
  tstX10,

  /// Design: TST-X11
  tstX11,

  /// Design: TST-X12
  tstX12,

  /// Design: TST-X13
  tstX13,

  /// Design: TST-X14
  tstX14,

  /// Design: TST-X15
  tstX15,

  /// Design: TST-X16
  tstX16,

  /// Design: TST-X17
  tstX17,

  /// Design: TST-X18
  tstX18,

  /// Design: TST-X19
  tstX19,

  /// Design: TST-X20
  tstX20;

  /// Tasarım kimliği (`TST-nn`; `design/extracted/registry.json`).
  String get designId => 'TST-${name.substring(3)}';
}
