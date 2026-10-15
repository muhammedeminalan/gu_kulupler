import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/admin/provider/admin_club_form_state.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_kulupler/product/media/club_media_image.dart';
import 'package:gu_kulupler/product/media/post_image_resolver.dart';
import 'package:gu_kulupler/product/widget/club/club_look_picker.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_kulupler/product/widget/member/user_row.dart';
import 'package:gu_ui/gu_ui.dart';

/// ADM-03 formunun gövdesi (prototip `screens-admin.js:49–55`, `col gap16`):
/// kulüp adı (`ADM-03.name`) · kategori (`ADM-03.category` → SHT-33) · kısa
/// açıklama (`ADM-03.summary`, sayaç) · uzun açıklama (`ADM-03.about`, 4
/// satır — `GuInput` varsayılanı, sayaç) · logo + kapak (`ClubLookPicker`; `ADM-03.logo` /
/// `ADM-03.cover`) · başkan ("Başkan ata" `ADM-03.assignPresident` ya da
/// kart + "Kaldır" `ADM-03.removePresident`) · unvan + danışman
/// (`ADM-03.advisorTitle` / `ADM-03.advisorName`; unvan alanı referansta
/// 120 dp) · bağlı danışman hesabı + "Kaldır" (`ADM-03.unlinkAdvisor`,
/// W-101 a; yalnızca `advisor.userId` doluyken) · iki anahtarlı kart
/// (`ADM-03.toggle.applicationsOpen` / `.approvalRequired`).
///
/// Değerler ve hatalar [state]'ten (`AdminClubFormViewModel`) gelir; form
/// yalnızca metin denetleyicilerini tutar. Kaydırma ve dış dolgu (`px16 pt8
/// pb24`) çağırandadır.
class AdminClubFormBody extends ConsumerStatefulWidget {
  /// [state] durumunun formu.
  const AdminClubFormBody({
    required this.state,
    required this.onNameChanged,
    required this.onCategoryTap,
    required this.onSummaryChanged,
    required this.onAboutChanged,
    required this.onLogoTap,
    required this.onCoverTap,
    required this.onAssignPresident,
    required this.onRemovePresident,
    required this.onAdvisorTitleChanged,
    required this.onAdvisorNameChanged,
    required this.onUnlinkAdvisor,
    required this.onApplicationsOpenChanged,
    required this.onApprovalRequiredChanged,
    super.key,
  });

  /// Unvan : danışman genişlik oranı — referansta (390 dp) unvan `width:
  /// 120px`, danışman kalan `358 − 8 − 120 = 230` → 12 : 23; dar ekranda
  /// oran korunur (sabit genişlik yok).
  static const int advisorTitleFlex = 12;

  /// Bkz. [advisorTitleFlex].
  static const int advisorNameFlex = 23;

  /// Formun durumu.
  final AdminClubFormState state;

  /// Kulüp adı değişti.
  final ValueChanged<String> onNameChanged;

  /// Kategori (`ADM-03.category`).
  final VoidCallback onCategoryTap;

  /// Kısa açıklama değişti.
  final ValueChanged<String> onSummaryChanged;

  /// Uzun açıklama değişti.
  final ValueChanged<String> onAboutChanged;

  /// Logo (`ADM-03.logo`).
  final VoidCallback onLogoTap;

  /// Kapak (`ADM-03.cover`).
  final VoidCallback onCoverTap;

  /// "Başkan ata" (`ADM-03.assignPresident`).
  final VoidCallback onAssignPresident;

  /// Başkan kartındaki "Kaldır" (`ADM-03.removePresident`).
  final VoidCallback onRemovePresident;

  /// Danışman unvanı değişti.
  final ValueChanged<String> onAdvisorTitleChanged;

  /// Danışman adı değişti.
  final ValueChanged<String> onAdvisorNameChanged;

  /// Bağlı danışman hesabındaki "Kaldır" (`ADM-03.unlinkAdvisor`).
  final VoidCallback onUnlinkAdvisor;

  /// "Başvurular açık" anahtarı.
  final ValueChanged<bool> onApplicationsOpenChanged;

  /// "Yönetim onayı gerekli" anahtarı.
  final ValueChanged<bool> onApprovalRequiredChanged;

  @override
  ConsumerState<AdminClubFormBody> createState() => _AdminClubFormBodyState();
}

class _AdminClubFormBodyState extends ConsumerState<AdminClubFormBody> {
  late final TextEditingController _name;
  late final TextEditingController _summary;
  late final TextEditingController _about;
  late final TextEditingController _advisorTitle;
  late final TextEditingController _advisorName;

  AdminClubFormState get _state => widget.state;

  @override
  void initState() {
    super.initState();
    final state = _state;
    _name = TextEditingController(text: state.name);
    _summary = TextEditingController(text: state.summary);
    _about = TextEditingController(text: state.about);
    _advisorTitle = TextEditingController(text: state.advisorTitle);
    _advisorName = TextEditingController(text: state.advisorName);
  }

  @override
  void didUpdateWidget(AdminClubFormBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Değerler ViewModel'den de değişir (sınırda kesme).
    final state = _state;
    _show(_name, state.name);
    _show(_summary, state.summary);
    _show(_about, state.about);
    _show(_advisorTitle, state.advisorTitle);
    _show(_advisorName, state.advisorName);
  }

  @override
  void dispose() {
    _name.dispose();
    _summary.dispose();
    _about.dispose();
    _advisorTitle.dispose();
    _advisorName.dispose();
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

  String? _errorText(AdminClubField field, AppLocalizations l10n) {
    if (field == AdminClubField.name &&
        _state.errors[field] == null &&
        _state.isNameTaken) {
      return l10n.clubFormErrUnique;
    }
    final error = _state.errors[field];
    if (error == null) return null;
    return switch (field) {
      AdminClubField.advisorName when error != FormFieldError.required =>
        l10n.authErrNameLength(Limits.nameMin, Limits.nameMax),
      // Kesilen metin sınırı aşamaz; tasarımda metni yok.
      AdminClubField.summary || AdminClubField.about => null,
      // Prototipte yalnızca "zorunlu" vardır; tek karakterlik ad da (Rules
      // `nameLower` ≥ 2) aynı uyarıyı alır.
      _ => l10n.authErrRequired,
    };
  }

  GuIcons get _icon =>
      CoverMapper.icon(_state.iconName) ??
      CoverMapper.icon(AdminClubFormState.defaultIconName) ??
      GuIcons.sparkles;

  Widget _look() {
    final pendingLogo = _state.pendingLogo;
    final pendingCover = _state.pendingCover;
    return ClubLookPicker(
      icon: _icon,
      palette: _state.coverPalette,
      pattern: _state.coverPattern,
      logo: pendingLogo != null
          ? MemoryImage(pendingLogo.bytes)
          : ref.clubLogoImage(
              _state.original,
              displaySize: GuEmblemSize.lg.dimension,
            ),
      cover: pendingCover != null
          ? MemoryImage(pendingCover.bytes)
          : ref.watch(storageImageResolverProvider)(_state.coverPath),
      logoKey: GuKey.action('ADM-03.logo'),
      coverKey: GuKey.action('ADM-03.cover'),
      onLogoTap: widget.onLogoTap,
      onCoverTap: widget.onCoverTap,
    );
  }

  Widget _removeButton(Key key, VoidCallback onPressed, String label) =>
      GuButton(
        key: key,
        label: label,
        size: GuButtonSize.sm,
        variant: GuButtonVariant.text,
        onPressed: onPressed,
      );

  /// `col gap8`: "Başkan" etiketi · "Başkan ata" ya da başkan kartı · hata.
  Widget _president(AppLocalizations l10n) {
    final president = _state.president;
    final control = _state.presidentUserId == null
        ? GuButton(
            key: GuKey.action('ADM-03.assignPresident'),
            label: l10n.clubFormAssignPresident,
            icon: GuIcons.userPlus,
            variant: GuButtonVariant.outline,
            full: true,
            onPressed: widget.onAssignPresident,
          )
        : GuCard(
            child: UserRow(
              user: president,
              sub: MemberRow.departmentAndYear(
                context,
                department: president?.department,
                year: president?.year,
              ),
              inCard: true,
              trailing: _removeButton(
                GuKey.action('ADM-03.removePresident'),
                widget.onRemovePresident,
                l10n.commonRemove,
              ),
            ),
          );
    return GuField(
      label: l10n.clubFormPresident,
      errorText: _errorText(AdminClubField.president, l10n),
      spacing: GuSpacing.s8,
      child: control,
    );
  }

  /// `row gap8`: unvan (`width:120px`) · danışman (`flex1`).
  Widget _advisor(AppLocalizations l10n) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: GuSpacing.s8,
    children: [
      Expanded(
        flex: AdminClubFormBody.advisorTitleFlex,
        child: GuInput(
          actionKey: GuKey.action('ADM-03.advisorTitle'),
          controller: _advisorTitle,
          label: l10n.clubFormAdvisorTitle,
          placeholder: l10n.clubFormAdvisorTitlePlaceholder,
          textInputAction: TextInputAction.next,
          onChanged: widget.onAdvisorTitleChanged,
        ),
      ),
      Expanded(
        flex: AdminClubFormBody.advisorNameFlex,
        child: GuInput(
          actionKey: GuKey.action('ADM-03.advisorName'),
          controller: _advisorName,
          label: l10n.clubAdvisor,
          textInputAction: TextInputAction.done,
          errorText: _errorText(AdminClubField.advisorName, l10n),
          onChanged: widget.onAdvisorNameChanged,
        ),
      ),
    ],
  );

  /// Bağlı danışman hesabı (W-101 a): kayıttaki ad + "Hesap bağlı" +
  /// "Kaldır". Bağ bayat olsa da (hesap silinmiş) gösterilir.
  Widget _linkedAdvisor(AppLocalizations l10n, String userId) {
    final advisor = _state.original?.advisor;
    final name = [
      advisor?.title.trim() ?? '',
      advisor?.name.trim() ?? '',
    ].where((part) => part.isNotEmpty).join(' ');
    return GuCard(
      child: UserRow.named(
        name: name,
        avatarSeed: userId,
        sub: l10n.clubFormAdvisorLinked,
        inCard: true,
        trailing: _removeButton(
          GuKey.action('ADM-03.unlinkAdvisor'),
          widget.onUnlinkAdvisor,
          l10n.commonRemove,
        ),
      ),
    );
  }

  /// `.tile.is-plain.in-card`: ikon 20 `c-muted` + `t-body-m c-heading`
  /// başlık + anahtar.
  Widget _switchTile({
    required GuIcons icon,
    required String title,
    required bool value,
    required Key actionKey,
    required ValueChanged<bool> onChanged,
  }) => GuTile(
    plain: true,
    padding: GuTilePadding.inCard,
    leading: GuIcon(
      icon,
      size: GuSizes.icon20,
      color: context.gu.colors.textMuted,
    ),
    title: title,
    trailing: GuSwitch(
      key: actionKey,
      value: value,
      semanticLabel: title,
      onChanged: onChanged,
    ),
  );

  Widget _toggles(AppLocalizations l10n) => GuCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _switchTile(
          icon: GuIcons.lockOpen,
          title: l10n.clubSettingsApplicationsOpen,
          value: _state.applicationsOpen,
          actionKey: GuKey.action('ADM-03.toggle.applicationsOpen'),
          onChanged: widget.onApplicationsOpenChanged,
        ),
        const GuDivider(),
        _switchTile(
          icon: GuIcons.shieldCheck,
          title: l10n.clubSettingsApprovalRequired,
          value: _state.approvalRequired,
          actionKey: GuKey.action('ADM-03.toggle.approvalRequired'),
          onChanged: widget.onApprovalRequiredChanged,
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final categoryId = _state.categoryId;
    final linkedAdvisorId = _state.linkedAdvisorId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s16,
      children: [
        if (_state.isSubmitError)
          GuBanner(
            kind: GuBannerKind.danger,
            text: l10n.sysErrorTitle,
            card: true,
          ),
        GuInput(
          actionKey: GuKey.action('ADM-03.name'),
          controller: _name,
          label: l10n.clubSettingsName,
          textInputAction: TextInputAction.next,
          errorText: _errorText(AdminClubField.name, l10n),
          onChanged: widget.onNameChanged,
        ),
        GuPickerField(
          actionKey: GuKey.action('ADM-03.category'),
          label: l10n.clubSettingsCategory,
          icon: GuIcons.layoutGrid,
          value: categoryId == null
              ? null
              : StaticLabels.category(context, categoryId),
          placeholder: l10n.commonSelect,
          errorText: _errorText(AdminClubField.category, l10n),
          onTap: widget.onCategoryTap,
        ),
        GuInput(
          actionKey: GuKey.action('ADM-03.summary'),
          controller: _summary,
          label: l10n.clubSettingsSummary,
          maxLength: Limits.clubSummaryMax,
          showCounter: true,
          errorText: _errorText(AdminClubField.summary, l10n),
          onChanged: widget.onSummaryChanged,
        ),
        GuInput(
          actionKey: GuKey.action('ADM-03.about'),
          controller: _about,
          label: l10n.clubSettingsAbout,
          multiline: true,
          maxLength: Limits.clubAboutMax,
          showCounter: true,
          errorText: _errorText(AdminClubField.about, l10n),
          onChanged: widget.onAboutChanged,
        ),
        _look(),
        _president(l10n),
        _advisor(l10n),
        if (linkedAdvisorId != null) _linkedAdvisor(l10n, linkedAdvisorId),
        _toggles(l10n),
      ],
    );
  }
}
