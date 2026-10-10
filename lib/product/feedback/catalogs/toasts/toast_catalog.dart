import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_ui/gu_ui.dart';

/// Toast metni: yerelleştirme + çağıranın değerleri.
typedef ToastTextBuilder =
    String Function(AppLocalizations l10n, ToastParams params);

/// Toast eylem düğmesi metni.
typedef ToastLabelBuilder = String Function(AppLocalizations l10n);

/// Toast metinlerinin değişkenleri — alan adları ARB yer tutucularıyla
/// (`{name}`, `{no}`, `{n}` …) ve prototip seçenekleriyle (`dialogs.js:60–74`
/// `p.saved`, `p.open` …) aynıdır.
///
/// ```dart
/// feedback.showToast(ToastId.tst27, params: ToastParams(name: user.name));
/// feedback.showToast(ToastId.tst11, params: const ToastParams(saved: true));
/// ```
@immutable
final class ToastParams extends Equatable {
  const ToastParams({
    this.name = '',
    this.no = '',
    this.what = '',
    this.role = '',
    this.title = '',
    this.s = '',
    this.date = '',
    this.n = 1,
    this.count = 0,
    this.unblocked = false,
    this.saved = false,
    this.off = false,
    this.suspended = false,
    this.pinned = false,
    this.open = false,
  });

  /// Kişi adı (TST-05, 09, 27, 28, 31, 46, 47, 49, X13).
  final String name;

  /// Destek talep numarası (TST-23).
  final String no;

  /// Silinen şeyin adı (TST-45: gönderi / yorum / taslak).
  final String what;

  /// Yeni rolün adı (TST-46).
  final String role;

  /// Bildirim başlığı (TST-55).
  final String title;

  /// Kalan saniye (TST-X3).
  final String s;

  /// Biçimlenmiş tarih (TST-X4).
  final String date;

  /// Bekleme listesi sırası (TST-43).
  final int n;

  /// Katılımcı sayısı (TST-X8).
  final int count;

  /// TST-09: engel kaldırıldı (değilse engellendi).
  final bool unblocked;

  /// TST-11: kaydedilenlere eklendi (değilse kaldırıldı).
  final bool saved;

  /// TST-37: hatırlatıcı kapatıldı (değilse ayarlandı).
  final bool off;

  /// TST-50 / TST-52: askıya alındı (değilse askı kaldırıldı).
  final bool suspended;

  /// TST-53: sabitlendi (değilse sabitleme kaldırıldı).
  final bool pinned;

  /// TST-54 / TST-X15: açıldı (değilse kapatıldı).
  final bool open;

  @override
  List<Object?> get props => [
    name,
    no,
    what,
    role,
    title,
    s,
    date,
    n,
    count,
    unblocked,
    saved,
    off,
    suspended,
    pinned,
    open,
  ];
}

/// Toast görünme süresi türü (CD-24; `core.js:567`).
enum ToastDurationKind {
  /// Eylemsiz toast — `GuMotion.toastDefault` (4 sn).
  standard(GuMotion.toastDefault),

  /// Eylemli ("Geri al", "Görüntüle" …) toast — `GuMotion.toastUndo` (6 sn).
  undo(GuMotion.toastUndo);

  const ToastDurationKind(this.duration);

  /// Token süresi.
  final Duration duration;
}

/// Bir toastın katalog kaydı — tür / metin / eylem `registry.json#toasts`'tan
/// (K-44), metinler ARB'den.
@immutable
final class ToastSpec {
  const ToastSpec({
    required this.kind,
    required this.text,
    this.actionLabel,
    this.undoAction = false,
    this.durationKind = ToastDurationKind.standard,
    this.persistent = false,
  }) : assert(
         !undoAction || actionLabel != null,
         'undoAction eylem etiketi ister.',
       );

  /// Tür (ikon + şerit rengi).
  final GuToastKind kind;

  /// Metin kurucu.
  final ToastTextBuilder text;

  /// Eylem düğmesi metni; `null` → eylemsiz toast.
  final ToastLabelBuilder? actionLabel;

  /// Eylem "Geri al" mı — anahtar `<ID>.undo`, değilse `<ID>.action`
  /// (`shell.js:21`).
  final bool undoAction;

  /// Eylem gösterildiğinde süre türü (eylemli kayıtlarda `undo`).
  final ToastDurationKind durationKind;

  /// Süreyle kapanmaz (registry'de 0 kayıt; alan sözleşme için durur).
  final bool persistent;

  /// Eylem düğmesinin anahtar soneki.
  String get actionKeyName => undoAction ? 'undo' : 'action';
}

/// 77 toastın kataloğu (`registry.json#toasts` 78 − `TST-58`).
///
/// `switch` tüketicidir: `ToastId`'ye eklenen üye burada satır ister
/// (derleme hatası). Tür sayıları: success 37 · error 3 · info 37; eylemli
/// 15 (Geri al ×9, Görüntüle ×3, TST-32, TST-34, TST-41).
abstract final class ToastCatalog {
  /// Tüm kayıtlar (`ToastId.values` sırasıyla).
  static final Map<ToastId, ToastSpec> specs = Map.unmodifiable({
    for (final id in ToastId.values) id: _build(id),
  });

  /// [id] kaydı.
  static ToastSpec of(ToastId id) => specs[id]!;

  static ToastSpec _build(ToastId id) => switch (id) {
    ToastId.tst01 => _error((l, _) => l.tst01),
    ToastId.tst02 => _info((l, _) => l.tst02),
    ToastId.tst03 => _success((l, _) => l.tst03),
    ToastId.tst04 => _info((l, _) => l.tst04),
    ToastId.tst05 => _success((l, p) => l.tst05(p.name)),
    ToastId.tst06 => _info((l, _) => l.tst06, undo: true),
    ToastId.tst07 => _success((l, _) => l.tst07),
    ToastId.tst08 => _success((l, _) => l.tst08),
    ToastId.tst09 => _info(
      (l, p) => p.unblocked ? l.tst09Unblocked(p.name) : l.tst09Blocked(p.name),
      undo: true,
    ),
    ToastId.tst10 => _info((l, _) => l.tst10),
    ToastId.tst11 => _success(
      (l, p) => p.saved ? l.tst11Saved : l.tst11Removed,
      undo: true,
    ),
    ToastId.tst12 => _success((l, _) => l.tst12),
    ToastId.tst13 => _success((l, _) => l.tst13),
    ToastId.tst14 => _success((l, _) => l.tst14, action: (l) => l.commonView),
    ToastId.tst15 => _success((l, _) => l.tst15),
    ToastId.tst16 => _info((l, _) => l.tst16, undo: true),
    ToastId.tst17 => _success((l, _) => l.tst17),
    ToastId.tst18 => _success((l, _) => l.tst18),
    ToastId.tst19 => _success((l, _) => l.tst19),
    ToastId.tst20 => _info((l, _) => l.tst20),
    ToastId.tst21 => _success((l, _) => l.tst21),
    ToastId.tst22 => _success((l, _) => l.tst22),
    ToastId.tst23 => _success((l, p) => l.tst23(p.no)),
    ToastId.tst24 => _error((l, _) => l.tst24),
    ToastId.tst25 => _success((l, _) => l.tst25),
    ToastId.tst26 => _info((l, _) => l.tst26),
    ToastId.tst27 => _success((l, p) => l.tst27(p.name), undo: true),
    ToastId.tst28 => _info((l, p) => l.tst28(p.name), undo: true),
    ToastId.tst29 => _success((l, _) => l.tst29),
    ToastId.tst30 => _success((l, _) => l.tst30, action: (l) => l.commonView),
    ToastId.tst31 => _success((l, p) => l.tst31(p.name), undo: true),
    ToastId.tst32 => _error((l, _) => l.tst32, action: (l) => l.scanGoSettings),
    ToastId.tst33 => _success((l, _) => l.tst33),
    ToastId.tst34 => _success(
      (l, _) => l.tst34,
      action: (l) => l.applicationGoClub,
    ),
    ToastId.tst35 => _success((l, _) => l.tst35),
    ToastId.tst36 => _success((l, _) => l.tst36),
    ToastId.tst37 => _success((l, p) => p.off ? l.tst37Off : l.tst37Set),
    ToastId.tst38 => _success((l, _) => l.tst38),
    ToastId.tst39 => _info((l, _) => l.tst39),
    ToastId.tst40 => _info((l, _) => l.tst40),
    ToastId.tst41 => _success(
      (l, _) => l.tst41,
      action: (l) => l.eventCtaTicket,
    ),
    ToastId.tst42 => _info((l, _) => l.tst42),
    ToastId.tst43 => _success((l, p) => l.tst43(p.n)),
    ToastId.tst44 => _success((l, _) => l.tst44),
    ToastId.tst45 => _info((l, p) => l.tst45(p.what), undo: true),
    ToastId.tst46 => _success((l, p) => l.tst46(p.name, p.role)),
    ToastId.tst47 => _info((l, p) => l.tst47(p.name), undo: true),
    ToastId.tst48 => _info((l, _) => l.tst48),
    ToastId.tst49 => _success((l, p) => l.tst49(p.name)),
    ToastId.tst50 => _info(
      (l, p) => p.suspended ? l.tst50Suspended : l.tst50Activated,
    ),
    ToastId.tst51 => _success((l, _) => l.tst51),
    ToastId.tst52 => _info(
      (l, p) => p.suspended ? l.tst52Suspended : l.tst52Unsuspended,
    ),
    ToastId.tst53 => _success(
      (l, p) => p.pinned ? l.tst53Pinned : l.tst53Unpinned,
    ),
    ToastId.tst54 => _info((l, p) => p.open ? l.tst54Opened : l.tst54Closed),
    ToastId.tst55 => _info(
      (l, p) => l.tst55(p.title),
      action: (l) => l.commonView,
    ),
    ToastId.tst56 => _info((l, _) => l.tst56),
    ToastId.tst57 => _success((l, _) => l.tst57),
    ToastId.tstX1 => _info((l, _) => l.tstX1),
    ToastId.tstX2 => _info((l, _) => l.tstX2),
    ToastId.tstX3 => _info((l, p) => l.tstX3(p.s)),
    ToastId.tstX4 => _info((l, p) => l.tstX4(p.date)),
    ToastId.tstX5 => _info((l, _) => l.tstX5),
    ToastId.tstX6 => _info((l, _) => l.tstX6),
    ToastId.tstX7 => _info((l, _) => l.tstX7),
    ToastId.tstX8 => _info((l, p) => l.tstX8(p.count)),
    ToastId.tstX9 => _info((l, _) => l.tstX9),
    ToastId.tstX10 => _info((l, _) => l.tstX10),
    ToastId.tstX11 => _info((l, _) => l.tstX11),
    ToastId.tstX12 => _info((l, _) => l.tstX12),
    ToastId.tstX13 => _success((l, p) => l.tstX13(p.name)),
    ToastId.tstX14 => _info((l, _) => l.tstX14),
    ToastId.tstX15 => _info((l, p) => p.open ? l.tstX15Opened : l.tstX15Closed),
    ToastId.tstX16 => _info((l, _) => l.tstX16),
    ToastId.tstX17 => _success((l, _) => l.tstX17),
    ToastId.tstX18 => _info((l, _) => l.tstX18),
    ToastId.tstX19 => _success((l, _) => l.tstX19),
    ToastId.tstX20 => _info((l, _) => l.tstX20),
  };

  static ToastSpec _success(
    ToastTextBuilder text, {
    bool undo = false,
    ToastLabelBuilder? action,
  }) => _spec(GuToastKind.success, text, undo: undo, action: action);

  static ToastSpec _error(ToastTextBuilder text, {ToastLabelBuilder? action}) =>
      _spec(GuToastKind.error, text, undo: false, action: action);

  static ToastSpec _info(
    ToastTextBuilder text, {
    bool undo = false,
    ToastLabelBuilder? action,
  }) => _spec(GuToastKind.info, text, undo: undo, action: action);

  static ToastSpec _spec(
    GuToastKind kind,
    ToastTextBuilder text, {
    required bool undo,
    required ToastLabelBuilder? action,
  }) {
    final label = undo ? _undoLabel : action;
    return ToastSpec(
      kind: kind,
      text: text,
      actionLabel: label,
      undoAction: undo,
      durationKind: label == null
          ? ToastDurationKind.standard
          : ToastDurationKind.undo,
    );
  }

  static String _undoLabel(AppLocalizations l10n) => l10n.commonUndo;
}
