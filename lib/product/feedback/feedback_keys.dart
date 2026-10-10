import 'package:flutter/foundation.dart';
import 'package:gu_ui/gu_ui.dart';

/// Overlay aksiyon anahtarları: `<ID>.<aksiyon>` (`SHT-05.scrim`,
/// `DLG-07.confirm`, `TST-27.undo`; D-18).
///
/// Kimlik çalışma anında enum'dan gelir; ad önce kurulur, sonra
/// `GuKey.action`'a verilir (biçim orada `assert` ile denetlenir).
abstract final class FeedbackKeys {
  /// [designId] (`SheetId.designId` vb.) + [action] için anahtar.
  static ValueKey<String> of(String designId, String action) {
    final name = '$designId.$action';
    return GuKey.action(name);
  }
}
