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

/// Değişkene bağlı dialog düğmesi: metni çağıranın değerlerinden üretir;
/// `null` dönerse düğme çizilmez.
typedef DialogOptionalLabelBuilder =
    String? Function(AppLocalizations l10n, DialogParams params);

/// Katalog metinlerinin okuduğu [DialogParams] anahtarları (ARB yer tutucu
/// adlarıyla aynı).
abstract final class DialogParamKeys {
  /// Kulüp adı — DLG-07, DLG-08 gövdesi (`{club}`).
  static const String club = 'club';

  /// Kullanıcı adı — DLG-12 "… kullanıcısını da engelle" (`{name}`).
  static const String name = 'name';
}

/// Standart (başlık + gövde + en çok iki düğme) bir dialogun katalog kaydı —
/// prototip `simple(id, {…})` (`dialogs.js:6`).
///
/// Özel gövdeli dialoglar (DLG-02 geri sayım — `LoginLockDialog`, DLG-19 /
/// 28 / 30 girdi, DLG-21 adımlar, DLG-22 onay kutusu, DLG-23 seçenekler,
/// DLG-25 üç eylem — `UnsavedChangesDialog`, DLG-32 bağlantı —
/// `ExternalLinkDialog`) katalogdan değil
/// `FeedbackService.showDialog(builder:)` ile açılır.
@immutable
final class DialogSpec {
  const DialogSpec({
    required this.title,
    required this.primary,
    this.body,
    this.secondary,
    this.secondaryFor,
    this.icon,
    this.destructive = false,
    this.primaryDanger,
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

  /// Değişkene bağlı ikincil düğme; verilirse [secondary] yerine kullanılır
  /// ve `null` döndürdüğünde düğme çizilmez (DLG-12: "{name} kullanıcısını
  /// da engelle" yalnızca şikayet bir kullanıcıya bağlıysa —
  /// `dialogs.js:28`).
  final DialogOptionalLabelBuilder? secondaryFor;

  /// [params] ile çizilecek ikincil düğmenin metni; `null` → düğme yok.
  String? secondaryLabel(AppLocalizations l10n, DialogParams params) {
    final conditional = secondaryFor;
    return conditional != null
        ? conditional(l10n, params)
        : secondary?.call(l10n);
  }

  /// Üstteki ikon kutusu.
  final GuIcons? icon;

  /// Yıkıcı işlem: ikon kutusu ve — [primaryDanger] aksini söylemedikçe —
  /// birincil düğme `danger`.
  final bool destructive;

  /// Birincil düğme `danger` mi? `null` → [destructive] ile aynı.
  ///
  /// Uyarı niteliğindeki dialoglarda ikon `danger`, birincil düğme ise
  /// olağan (`primary`) kalır: DLG-01 "Destekle iletişime geç"
  /// (`dialogs.js:18`), DLG-16 "Tamam".
  final bool? primaryDanger;

  /// Birincil düğme `danger` çizilir mi ([primaryDanger] ?? [destructive]).
  bool get isPrimaryDanger => primaryDanger ?? destructive;

  /// `false` → scrim / geri tuşu kapatmaz (DLG-26, DLG-27).
  final bool dismissible;

  /// Birincil düğmenin anahtar soneki (`DLG-07.confirm`, `DLG-06.logout`).
  final String primaryAction;

  /// İkincil düğmenin anahtar soneki (`DLG-07.cancel`, `DLG-01.ok`).
  final String secondaryAction;
}

/// `DialogId → DialogSpec` kaydı.
///
/// Her dialogun satırını sahibi olan task ekler
/// (`docs/task-map.json#owners.dialogs`). Kaydı olmayan kimlik
/// `showDialog(builder:)` ile açılır.
abstract final class DialogCatalog {
  static final Map<DialogId, DialogSpec> _specs = <DialogId, DialogSpec>{
    /// Design: DLG-01 — Hesabın askıya alındı (`dialogs.js:18`): ikon
    /// `danger`, birincil düğme olağan. Sonuç `true` → destek e-postası,
    /// dış bağlantı onayıyla (DLG-32; `SuspendedAccountMixin`).
    DialogId.dlg01: DialogSpec(
      title: (l10n, _) => l10n.dlg01Title,
      body: (l10n, _) => l10n.dlg01Body,
      primary: (l10n) => l10n.dlg01Support,
      secondary: (l10n) => l10n.commonOk,
      icon: GuIcons.ban,
      destructive: true,
      primaryDanger: false,
      primaryAction: 'support',
      secondaryAction: 'ok',
    ),

    /// Design: DLG-03 — Bildirimleri açalım mı? (`dialogs.js:15`
    /// `permissionDialog`). Sonuç `true` → sistem bildirim izni istenir
    /// (`PermissionPromptMixin.askNotificationPermission`); prototipin OS
    /// izin maketi (`PermissionSim`) uygulanmaz (K-02).
    DialogId.dlg03: DialogSpec(
      title: (l10n, _) => l10n.dlg03Title,
      body: (l10n, _) => l10n.dlg03Body,
      primary: (l10n) => l10n.dlgPermissionAllow,
      secondary: (l10n) => l10n.dlgPermissionNotNow,
      icon: GuIcons.bellRing,
      primaryAction: 'allow',
      secondaryAction: 'notNow',
    ),

    /// Design: DLG-04 — Kamera erişimi (`dialogs.js:16`). Sonuç `true` →
    /// sistem kamera izni istenir; ret → TST-32
    /// (`PermissionPromptMixin.ensureCameraAccess`).
    DialogId.dlg04: DialogSpec(
      title: (l10n, _) => l10n.dlg04Title,
      body: (l10n, _) => l10n.dlg04Body,
      primary: (l10n) => l10n.dlgPermissionAllow,
      secondary: (l10n) => l10n.dlgPermissionNotNow,
      icon: GuIcons.camera,
      primaryAction: 'allow',
      secondaryAction: 'notNow',
    ),

    /// Design: DLG-05 — Fotoğraflarına erişim (`dialogs.js:17`). Ön
    /// açıklamadır: sonuç `true` → sistem fotoğraf seçicisi doğrudan açılır,
    /// sistem izni istenmez (CD-16;
    /// `PermissionPromptMixin.ensureGalleryAccess`).
    DialogId.dlg05: DialogSpec(
      title: (l10n, _) => l10n.dlg05Title,
      body: (l10n, _) => l10n.dlg05Body,
      primary: (l10n) => l10n.dlgPermissionAllow,
      secondary: (l10n) => l10n.dlgPermissionNotNow,
      icon: GuIcons.images,
      primaryAction: 'allow',
      secondaryAction: 'notNow',
    ),

    /// Design: DLG-06 — Çıkış yapılsın mı? (`dialogs.js:21`). Sonuç `true`
    /// → oturum kapatılır (`SignOutMixin.confirmSignOut`).
    DialogId.dlg06: DialogSpec(
      title: (l10n, _) => l10n.dlg06Title,
      body: (l10n, _) => l10n.dlg06Body,
      primary: (l10n) => l10n.authLogout,
      secondary: (l10n) => l10n.commonGiveUp,
      icon: GuIcons.logOut,
      primaryAction: 'logout',
    ),

    /// Design: DLG-07 — İsteği iptal et? (`dialogs.js:22`): ikon ve birincil
    /// düğme `danger`; gövde kulüp adını taşır ([DialogParamKeys.club]).
    /// Sonuç `true` → başvuru geri çekilir
    /// (`MembershipDialogsMixin.confirmCancelApplication`).
    DialogId.dlg07: DialogSpec(
      title: (l10n, _) => l10n.dlg07Title,
      body: (l10n, params) =>
          l10n.dlg07Body(_text(params, DialogParamKeys.club)),
      primary: (l10n) => l10n.applicationCancel,
      secondary: (l10n) => l10n.commonGiveUp,
      icon: GuIcons.x,
      destructive: true,
    ),

    /// Design: DLG-08 — Kulüpten ayrıl? (`dialogs.js:24`): ikon ve birincil
    /// düğme `danger`; gövde kulüp adını taşır. Sonuç `true` → üyelik sona
    /// erer (`MembershipDialogsMixin.confirmLeaveClub`).
    DialogId.dlg08: DialogSpec(
      title: (l10n, _) => l10n.dlg08Title,
      body: (l10n, params) =>
          l10n.dlg08Body(_text(params, DialogParamKeys.club)),
      primary: (l10n) => l10n.clubLeave,
      secondary: (l10n) => l10n.commonGiveUp,
      icon: GuIcons.logOut,
      destructive: true,
    ),

    /// Design: DLG-09 — Ayrılamazsın (`dialogs.js:25`): başkan devretmeden
    /// ayrılamaz. Sonuç `true` → "Başkanlığı devret"
    /// (`MembershipDialogsMixin.showSolePresidentDialog`; devir akışı
    /// SHT-25 → DLG-21, T-33).
    DialogId.dlg09: DialogSpec(
      title: (l10n, _) => l10n.dlg09Title,
      body: (l10n, _) => l10n.dlg09Body,
      primary: (l10n) => l10n.mgtMembersTransfer,
      secondary: (l10n) => l10n.commonOk,
      icon: GuIcons.crown,
      primaryAction: 'transfer',
      secondaryAction: 'ok',
    ),

    /// Design: DLG-10 — Gönderi silinsin mi? (`dialogs.js:26`): ikon ve
    /// birincil düğme `danger`. Sonuç `true` → gönderi kaldırılır
    /// (`PostActionsMixin.removePost`; ardından TST-45 "Geri al").
    DialogId.dlg10: DialogSpec(
      title: (l10n, _) => l10n.dlg10Title,
      body: (l10n, _) => l10n.dlg10Body,
      primary: (l10n) => l10n.commonDelete,
      secondary: (l10n) => l10n.commonGiveUp,
      icon: GuIcons.trash2,
      destructive: true,
    ),

    /// Design: DLG-11 — Yorum silinsin mi? (`dialogs.js:27`): ikon ve
    /// birincil düğme `danger`. Sonuç `true` → yorum kaldırılır
    /// (`PostDetailViewModel`; ardından TST-45 "Geri al").
    DialogId.dlg11: DialogSpec(
      title: (l10n, _) => l10n.dlg11Title,
      body: (l10n, _) => l10n.dlg11Body,
      primary: (l10n) => l10n.commonDelete,
      secondary: (l10n) => l10n.commonGiveUp,
      icon: GuIcons.trash2,
      destructive: true,
    ),

    /// Design: DLG-12 — Şikayetin alındı (`dialogs.js:28`). "Tamam" → `true`.
    /// Şikayet bir kullanıcıya bağlıysa ([DialogParamKeys.name] verildiyse)
    /// altında "{name} kullanıcısını da engelle" çizilir → `false`
    /// (`ReportReceivedMixin.showReportReceivedDialog`; engelleme onayı
    /// DLG-13, T-18).
    DialogId.dlg12: DialogSpec(
      title: (l10n, _) => l10n.dlg12Title,
      body: (l10n, _) => l10n.dlg12Body,
      primary: (l10n) => l10n.commonOk,
      secondaryFor: (l10n, params) => switch (params[DialogParamKeys.name]) {
        final String name when name.isNotEmpty => l10n.dlg12Block(name),
        _ => null,
      },
      icon: GuIcons.shieldCheck,
      primaryAction: 'ok',
      secondaryAction: 'block',
    ),

    /// Design: DLG-13 — {name} engellensin mi? (`dialogs.js:29`): ikon ve
    /// birincil düğme `danger`; başlık kullanıcının adını taşır
    /// ([DialogParamKeys.name]). Sonuç `true` → kullanıcı engellenir
    /// (`BlockUserMixin.blockUser`; ardından TST-09 "Geri al").
    DialogId.dlg13: DialogSpec(
      title: (l10n, params) =>
          l10n.dlg13Title(_text(params, DialogParamKeys.name)),
      body: (l10n, _) => l10n.dlg13Body,
      primary: (l10n) => l10n.sht27Block,
      secondary: (l10n) => l10n.commonGiveUp,
      icon: GuIcons.ban,
      destructive: true,
    ),

    /// Design: DLG-26 — Güncelleme gerekli (`dialogs.js:44`; kapatılamaz).
    DialogId.dlg26: DialogSpec(
      title: (l10n, _) => l10n.dlg26Title,
      body: (l10n, _) => l10n.dlg26Body,
      primary: (l10n) => l10n.dlg26Update,
      icon: GuIcons.download,
      dismissible: false,
      primaryAction: 'update',
    ),

    /// Design: DLG-27 — Oturumun sona erdi (`dialogs.js:45`; kapatılamaz).
    DialogId.dlg27: DialogSpec(
      title: (l10n, _) => l10n.dlg27Title,
      body: (l10n, _) => l10n.dlg27Body,
      primary: (l10n) => l10n.authLoginCta,
      icon: GuIcons.lock,
      dismissible: false,
      primaryAction: 'login',
    ),
  };

  /// [params] içindeki [key] metni; verilmediyse (ya da metin değilse) boş.
  static String _text(DialogParams params, String key) => switch (params[key]) {
    final String value => value,
    _ => '',
  };

  /// [id] kaydı; yoksa `null`.
  static DialogSpec? of(DialogId id) => _specs[id];

  /// Kaydı olan kimlikler.
  static Iterable<DialogId> get ids => _specs.keys;
}
