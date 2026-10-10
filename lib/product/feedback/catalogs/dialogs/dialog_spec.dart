import 'package:flutter/foundation.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_ui/gu_ui.dart';

/// Dialog metinlerinin değişkenleri: ARB yer tutucu adı → değer
/// (`{'club': club.name}`, `{'count': 3}`).
typedef DialogParams = Map<String, Object>;

/// Dialog başlık / gövde metni: yerelleştirme + çağıranın değerleri.
typedef DialogTextBuilder =
    String Function(AppLocalizations l10n, DialogParams params);

/// Dialog düğme metni.
typedef DialogLabelBuilder = String Function(AppLocalizations l10n);

/// Standart (başlık + gövde + en çok iki düğme) bir dialogun katalog kaydı —
/// prototip `simple(id, {…})` (`dialogs.js:6`).
///
/// Özel gövdeli dialoglar (DLG-02 geri sayım, DLG-19 / 28 / 30 girdi,
/// DLG-21 adımlar, DLG-22 onay kutusu, DLG-23 seçenekler, DLG-25 üç eylem,
/// DLG-32 bağlantı) katalogdan değil `FeedbackService.showDialog(builder:)`
/// ile açılır.
@immutable
final class DialogSpec {
  const DialogSpec({
    required this.title,
    required this.primary,
    this.body,
    this.secondary,
    this.icon,
    this.destructive = false,
    this.dismissible = true,
    this.primaryAction = 'confirm',
    this.secondaryAction = 'cancel',
  });

  /// Başlık.
  final DialogTextBuilder title;

  /// Gövde metni; `null` → yok.
  final DialogTextBuilder? body;

  /// Birincil düğme metni; dokunuş dialogu `true` ile kapatır.
  final DialogLabelBuilder primary;

  /// İkincil (metin) düğme; `null` → yok. Dokunuş `false` ile kapatır.
  final DialogLabelBuilder? secondary;

  /// Üstteki ikon kutusu.
  final GuIcons? icon;

  /// Yıkıcı işlem: ikon kutusu ve birincil düğme `danger`.
  final bool destructive;

  /// `false` → scrim / geri tuşu kapatmaz (DLG-26, DLG-27).
  final bool dismissible;

  /// Birincil düğmenin anahtar soneki (`DLG-07.confirm`, `DLG-06.logout`).
  final String primaryAction;

  /// İkincil düğmenin anahtar soneki (`DLG-07.cancel`, `DLG-01.ok`).
  final String secondaryAction;
}

/// `DialogId → DialogSpec` kaydı.
///
/// T-07'de boştur: her dialogun satırını sahibi olan task ekler
/// (`docs/task-map.json#owners.dialogs`). Kaydı olmayan kimlik
/// `showDialog(builder:)` ile açılır.
abstract final class DialogCatalog {
  static final Map<DialogId, DialogSpec> _specs = <DialogId, DialogSpec>{};

  /// [id] kaydı; yoksa `null`.
  static DialogSpec? of(DialogId id) => _specs[id];

  /// Kaydı olan kimlikler.
  static Iterable<DialogId> get ids => _specs.keys;
}
