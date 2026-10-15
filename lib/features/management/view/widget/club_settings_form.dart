import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/management/constants/club_settings_constants.dart';
import 'package:gu_kulupler/features/management/provider/club_settings_state.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_kulupler/product/media/club_media_image.dart';
import 'package:gu_kulupler/product/media/post_image_resolver.dart';
import 'package:gu_kulupler/product/widget/club/club_look_picker.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_kulupler/product/widget/member/user_row.dart';
import 'package:gu_ui/gu_ui.dart';

/// MGT-09 formunun gövdesi (prototip `screens-manage.js:179–186`): dört
/// grup + danışman kartı. Değerler ve hata haritası [state]'ten
/// (`ClubSettingsViewModel`) gelir; her değişiklik geri çağrıyla döner —
/// form yalnızca metin denetleyicilerini tutar.
///
/// Dönen sütun `col gap20`'dir; kaydırma ve dış dolgu (`px16 pt8 pb24`)
/// çağırandadır.
///
/// * **Görünüm** (`col gap8`): logo (`MGT-09.logo`; `emblem` 72, ikon 30 —
///   seçilmiş / yüklenmiş logo varsa görsel) · kapak (`MGT-09.cover`; kalan
///   genişlik, 72 yüksek, radius 16, sağ altta `bg.surface` zeminli "Kapak"
///   rozeti, inset 8).
/// * **Bilgiler** (`col gap12`): kilitli kulüp adı (`MGT-09.lockedName`
///   sarmalayıcı → TST-20; metin alanı `MGT-09.name`) · kategori
///   (`MGT-09.category` → SHT-33) · kısa açıklama (`MGT-09.summary`, sayaç
///   `Limits.clubSummaryMax`) · uzun açıklama (`MGT-09.about`, 5 satır, sayaç
///   `Limits.clubAboutMax`).
/// * **İletişim** (`col gap12`): e-posta (`mail`) · Instagram (`camera`) ·
///   web sitesi (`globe`); hata metinleri `auth.err.email`,
///   `clubSettings.err.instagram`, `clubSettings.err.web`.
/// * **Katılım** (`col gap8`): kart içinde üç anahtarlı satır
///   (`MGT-09.toggle.applicationsOpen` / `.approvalRequired` /
///   `.requireNote`; ikon 20 `text.muted` + başlık + açıklama, ayırıcılı);
///   onay kapalıysa uyarı bandı "Herkes anında üye olur."
/// * **Danışman** (`col gap8`): kart içinde danışman satırı (dokunulmaz) +
///   "Danışman kampüs yönetimi tarafından atanır"; danışman kaydı yoksa grup
///   çizilmez.
///
/// Danışman bakışında ([ClubSettingsState.isReadOnly]) metin alanları kapalı,
/// anahtarlar kapalıdır (dokunma [onReadOnlyTap] → TST-26); logo / kapak /
/// kategori dokunuşlarını çağıran engeller.
///
/// MGT-09'a özgüdür (tek çağıran); anahtarlar `MGT-09.*`.
class ClubSettingsForm extends ConsumerStatefulWidget {
  /// [state] durumunun formu.
  const ClubSettingsForm({
    required this.state,
    required this.onLogoTap,
    required this.onCoverTap,
    required this.onLockedNameTap,
    required this.onCategoryTap,
    required this.onSummaryChanged,
    required this.onAboutChanged,
    required this.onEmailChanged,
    required this.onInstagramChanged,
    required this.onWebChanged,
    required this.onApplicationsOpenChanged,
    required this.onApprovalRequiredChanged,
    required this.onRequireNoteChanged,
    required this.onReadOnlyTap,
    super.key,
  });

  /// Uzun açıklamanın satır sayısı (`screens-manage.js:183` `rows=5`).
  static const int aboutRows = 5;

  /// Kulüp ikonu kayıtta yoksa logo / kapak sembolü.
  static const GuIcons fallbackIcon = GuIcons.users;

  /// Formun durumu (okunmuş kulüp: `state.original != null`).
  final ClubSettingsState state;

  /// Logo (`MGT-09.logo`).
  final VoidCallback onLogoTap;

  /// Kapak (`MGT-09.cover`).
  final VoidCallback onCoverTap;

  /// Kilitli kulüp adı (`MGT-09.lockedName`).
  final VoidCallback onLockedNameTap;

  /// Kategori (`MGT-09.category`).
  final VoidCallback onCategoryTap;

  /// Kısa açıklama değişti.
  final ValueChanged<String> onSummaryChanged;

  /// Uzun açıklama değişti.
  final ValueChanged<String> onAboutChanged;

  /// E-posta değişti.
  final ValueChanged<String> onEmailChanged;

  /// Instagram değişti.
  final ValueChanged<String> onInstagramChanged;

  /// Web sitesi değişti.
  final ValueChanged<String> onWebChanged;

  /// "Başvurular açık" anahtarı.
  final ValueChanged<bool> onApplicationsOpenChanged;

  /// "Yönetim onayı gerekli" anahtarı.
  final ValueChanged<bool> onApprovalRequiredChanged;

  /// "Başvuruda not iste" anahtarı.
  final ValueChanged<bool> onRequireNoteChanged;

  /// Danışman bakışında kapalı anahtara dokunuldu (TST-26).
  final VoidCallback onReadOnlyTap;

  @override
  ConsumerState<ClubSettingsForm> createState() => _ClubSettingsFormState();
}

class _ClubSettingsFormState extends ConsumerState<ClubSettingsForm> {
  late final TextEditingController _name;
  late final TextEditingController _summary;
  late final TextEditingController _about;
  late final TextEditingController _email;
  late final TextEditingController _instagram;
  late final TextEditingController _web;

  ClubSettingsState get _state => widget.state;

  @override
  void initState() {
    super.initState();
    final state = _state;
    _name = TextEditingController(text: state.original?.name ?? '');
    _summary = TextEditingController(text: state.summary);
    _about = TextEditingController(text: state.about);
    _email = TextEditingController(text: state.email);
    _instagram = TextEditingController(text: state.instagram);
    _web = TextEditingController(text: state.web);
  }

  @override
  void didUpdateWidget(ClubSettingsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Değerler ViewModel'den de değişir (sınırda kesme, kayıttan sonra
    // biçimlenmiş değer — Instagram `@`).
    final state = _state;
    _show(_name, state.original?.name ?? '');
    _show(_summary, state.summary);
    _show(_about, state.about);
    _show(_email, state.email);
    _show(_instagram, state.instagram);
    _show(_web, state.web);
  }

  @override
  void dispose() {
    _name.dispose();
    _summary.dispose();
    _about.dispose();
    _email.dispose();
    _instagram.dispose();
    _web.dispose();
    super.dispose();
  }

  /// [controller] alanındaki metni [value] yapar (imleç sonda).
  static void _show(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  GuIcons get _clubIcon {
    final club = _state.original;
    return (club == null ? null : CoverMapper.icon(club.iconName)) ??
        ClubSettingsForm.fallbackIcon;
  }

  String? _errorText(ClubSettingsField field, AppLocalizations l10n) {
    if (_state.errors[field] == null) return null;
    return switch (field) {
      ClubSettingsField.email => l10n.authErrEmail,
      ClubSettingsField.instagram => l10n.clubSettingsErrInstagram,
      ClubSettingsField.web => l10n.clubSettingsErrWeb,
      // Kesilen metin sınırı aşamaz; tasarımda metni yok.
      ClubSettingsField.summary || ClubSettingsField.about => null,
    };
  }

  /// Grup: büyük harfli `t-overline` başlık + içerik.
  Widget _group(String title, double spacing, List<Widget> children) {
    final locale = Localizations.localeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing,
      children: [
        Semantics(
          header: true,
          child: Text(title.upperFor(locale), style: context.gu.text.overline),
        ),
        ...children,
      ],
    );
  }

  // ── Görünüm ───────────────────────────────────────────────────────

  Widget _look() {
    final pendingLogo = _state.pendingLogo;
    final pendingCover = _state.pendingCover;
    return ClubLookPicker(
      icon: _clubIcon,
      palette: _state.coverPalette,
      pattern: _state.coverPattern,
      logo: pendingLogo != null
          ? MemoryImage(pendingLogo.bytes)
          : ref.clubLogoImage(_state.original),
      cover: pendingCover != null
          ? MemoryImage(pendingCover.bytes)
          : ref.watch(storageImageResolverProvider)(_state.coverPath),
      logoKey: GuKey.action('MGT-09.logo'),
      coverKey: GuKey.action('MGT-09.cover'),
      onLogoTap: widget.onLogoTap,
      onCoverTap: widget.onCoverTap,
    );
  }

  // ── Bilgiler ──────────────────────────────────────────────────────

  List<Widget> _info(AppLocalizations l10n) {
    final readOnly = _state.isReadOnly;
    final categoryId = _state.original?.categoryId;
    return [
      GuActionSurface(
        key: GuKey.action('MGT-09.lockedName'),
        borderRadius: GuRadius.borderSm,
        onTap: widget.onLockedNameTap,
        // Alan salt okunurdur: dokunma metin alanına değil kilit bildirimine
        // gider (prototip sarmalayıcı `div role=button`).
        builder: (context, _) => AbsorbPointer(
          child: GuInput(
            actionKey: GuKey.action('MGT-09.name'),
            controller: _name,
            label: l10n.clubSettingsName,
            locked: true,
            help: l10n.clubSettingsNameLocked,
          ),
        ),
      ),
      GuPickerField(
        actionKey: GuKey.action('MGT-09.category'),
        label: l10n.clubSettingsCategory,
        icon: GuIcons.layoutGrid,
        value: categoryId == null
            ? null
            : StaticLabels.category(context, categoryId),
        onTap: widget.onCategoryTap,
      ),
      GuInput(
        actionKey: GuKey.action('MGT-09.summary'),
        controller: _summary,
        label: l10n.clubSettingsSummary,
        maxLength: Limits.clubSummaryMax,
        showCounter: true,
        disabled: readOnly,
        errorText: _errorText(ClubSettingsField.summary, l10n),
        onChanged: widget.onSummaryChanged,
      ),
      GuInput(
        actionKey: GuKey.action('MGT-09.about'),
        controller: _about,
        label: l10n.clubSettingsAbout,
        multiline: true,
        rows: ClubSettingsForm.aboutRows,
        maxLength: Limits.clubAboutMax,
        showCounter: true,
        disabled: readOnly,
        errorText: _errorText(ClubSettingsField.about, l10n),
        onChanged: widget.onAboutChanged,
      ),
    ];
  }

  // ── İletişim ──────────────────────────────────────────────────────

  List<Widget> _contact(AppLocalizations l10n) {
    final readOnly = _state.isReadOnly;
    return [
      GuInput(
        actionKey: GuKey.action('MGT-09.email'),
        controller: _email,
        label: l10n.authEmail,
        icon: GuIcons.mail,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        disabled: readOnly,
        errorText: _errorText(ClubSettingsField.email, l10n),
        onChanged: widget.onEmailChanged,
      ),
      GuInput(
        actionKey: GuKey.action('MGT-09.instagram'),
        controller: _instagram,
        label: ClubSettingsConstants.instagramLabel,
        icon: GuIcons.camera,
        textInputAction: TextInputAction.next,
        disabled: readOnly,
        errorText: _errorText(ClubSettingsField.instagram, l10n),
        onChanged: widget.onInstagramChanged,
      ),
      GuInput(
        actionKey: GuKey.action('MGT-09.web'),
        controller: _web,
        label: l10n.clubContactWeb,
        icon: GuIcons.globe,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.done,
        disabled: readOnly,
        errorText: _errorText(ClubSettingsField.web, l10n),
        onChanged: widget.onWebChanged,
      ),
    ];
  }

  // ── Katılım ───────────────────────────────────────────────────────

  /// `.tile.is-plain.in-card`: ikon 20 `c-muted` + başlık + açıklama +
  /// anahtar.
  Widget _switchTile({
    required GuIcons icon,
    required String title,
    required String caption,
    required bool value,
    required Key actionKey,
    required ValueChanged<bool> onChanged,
  }) {
    final gu = context.gu;
    return GuTile(
      plain: true,
      padding: GuTilePadding.inCard,
      leading: GuIcon(icon, size: GuSizes.icon20, color: gu.colors.textMuted),
      title: title,
      // `<span class="t-caption">` satır içidir: satır kutusu `.tile-text`'in
      // kalıtılan 15/1.47 satırından kısa olamaz (css:77) → bodyM payandası.
      sub2Widget: Text(
        caption,
        strutStyle: StrutStyle.fromTextStyle(gu.text.bodyM),
      ),
      trailing: GuSwitch(
        key: actionKey,
        value: value,
        semanticLabel: title,
        disabled: _state.isReadOnly,
        onDisabledPressed: widget.onReadOnlyTap,
        onChanged: onChanged,
      ),
    );
  }

  List<Widget> _join(AppLocalizations l10n) {
    final state = _state;
    return [
      GuCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _switchTile(
              icon: GuIcons.lockOpen,
              title: l10n.clubSettingsApplicationsOpen,
              caption: l10n.clubSettingsApplicationsOpenHelp,
              value: state.applicationsOpen,
              actionKey: GuKey.action('MGT-09.toggle.applicationsOpen'),
              onChanged: widget.onApplicationsOpenChanged,
            ),
            const GuDivider(),
            _switchTile(
              icon: GuIcons.shieldCheck,
              title: l10n.clubSettingsApprovalRequired,
              caption: l10n.clubSettingsApprovalRequiredHelp,
              value: state.approvalRequired,
              actionKey: GuKey.action('MGT-09.toggle.approvalRequired'),
              onChanged: widget.onApprovalRequiredChanged,
            ),
            const GuDivider(),
            _switchTile(
              icon: GuIcons.fileText,
              title: l10n.clubSettingsRequireNote,
              caption: l10n.clubSettingsRequireNoteHelp,
              value: state.requireNote,
              actionKey: GuKey.action('MGT-09.toggle.requireNote'),
              onChanged: widget.onRequireNoteChanged,
            ),
          ],
        ),
      ),
      if (!state.approvalRequired)
        GuBanner(
          kind: GuBannerKind.warning,
          text: l10n.clubSettingsInstantWarning,
          card: true,
        ),
    ];
  }

  // ── Danışman ──────────────────────────────────────────────────────

  Widget _advisorRow(AppLocalizations l10n, ClubAdvisorModel advisor) {
    final name = [
      advisor.title.trim(),
      advisor.name.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    return GuCard(
      child: UserRow.named(
        name: name,
        avatarSeed: advisor.userId ?? name,
        sub: l10n.clubSettingsAdvisorLocked,
        inCard: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final advisor = _state.original?.advisor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s20,
      children: [
        if (_state.isSubmitError)
          GuBanner(
            kind: GuBannerKind.danger,
            text: l10n.sysErrorTitle,
            card: true,
          ),
        _group(l10n.clubSettingsGroupLook, GuSpacing.s8, [_look()]),
        _group(l10n.clubSettingsGroupInfo, GuSpacing.s12, _info(l10n)),
        _group(l10n.clubSettingsGroupContact, GuSpacing.s12, _contact(l10n)),
        _group(l10n.clubSettingsGroupJoin, GuSpacing.s8, _join(l10n)),
        if (advisor != null)
          _group(l10n.clubAdvisor, GuSpacing.s8, [
            _advisorRow(l10n, advisor),
          ]),
      ],
    );
  }
}
