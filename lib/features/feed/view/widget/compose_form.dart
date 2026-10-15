import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/feed/provider/compose_state.dart';
import 'package:gu_kulupler/features/feed/provider/compose_view_model.dart';
import 'package:gu_kulupler/features/feed/view/widget/compose_parts.dart';
import 'package:gu_kulupler/features/feed/view/widget/poll_editor.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/media/post_image_resolver.dart';
import 'package:gu_kulupler/product/media/user_avatar_image.dart';
import 'package:gu_kulupler/product/widget/post/announcement_quota_bar.dart';
import 'package:gu_kulupler/product/widget/post/image_grid.dart';
import 'package:gu_ui/gu_ui.dart';

/// FED-03 formu — tür dilimi, yazar satırı ve türe göre alanlar (prototip
/// `screens-clubs.js:201–213`; `col gap16`).
///
/// * **Tür** (`FED-03.type.*`): Gönderi / Duyuru / Anket. Düzenlemede tür
///   değişmez (dilim soluk ve dokunulmaz).
/// * **Yazar satırı:** avatar 36 + ad + kulüp adı; kullanıcı birden çok kulüp
///   yönetiyorsa kulüp adı SHT-18'i açan düğmedir ([onSwitchClub]).
/// * **Gönderi:** metin (5 satır) · "Görseller (n/4)" + "Görsel ekle"
///   ([onAddImage]; dolmuşken dokunuş da oraya gider → TST-X5) + 72 dp küçük
///   önizlemeler ("Kaldır") · "Sabitle".
/// * **Duyuru:** başlık · metin · "Üyelere bildirim gönder" (hak dolmuşsa
///   kapalı; dokunuş DLG-24) · `AnnouncementQuotaBar` · "Sabitle" · bildirim
///   önizlemesi. Düzenlemede bildirim blokları çizilmez (bildirim yeniden
///   gönderilmez).
/// * **Anket:** soru (2 satır) · `PollEditor`. Düzenlemede soru salt okunur
///   (W-71).
///
/// Metin alanları sınırda ViewModel'de kesilir; alan kesilmiş metni gösterir.
class ComposeForm extends ConsumerStatefulWidget {
  /// [clubId] kulübündeki yazı formu (düzenlemede [editPostId]).
  const ComposeForm({
    required this.clubId,
    required this.onAddImage,
    this.editPostId,
    this.initialType,
    this.onSwitchClub,
    super.key,
  });

  /// Kulüp kimliği.
  final String clubId;

  /// Düzenlenen gönderi; yeni gönderide `null`.
  final String? editPostId;

  /// Yeni gönderinin başlangıç türü (`ComposeView.initialType`; ViewModel
  /// ailesinin parçası).
  final PostType? initialType;

  /// "Görsel ekle" dokunuşu (`FED-03.addImage`): view SHT-16'yı açar; sınır
  /// dolmuşsa TST-X5.
  final VoidCallback onAddImage;

  /// Kulüp adına dokunuş (`FED-03.switchClub`) → SHT-18; `null` → kulüp adı
  /// düz metindir.
  final VoidCallback? onSwitchClub;

  @override
  ConsumerState<ComposeForm> createState() => _ComposeFormState();
}

class _ComposeFormState extends ConsumerState<ComposeForm> {
  /// `screens-clubs.js:202` `Avatar size=36`.
  static final double _avatarSize = GuSizes.avatarSizes[2];

  /// Küçük görsel önizlemesinin kenarı (`screens-clubs.js:205`
  /// `width:72px;height:72px`).
  static const double _thumbSize = GuSizes.emblem;

  /// Küçük önizlemedeki "Kaldır" düğmesinin köşeden uzaklığı
  /// (`right:2px;top:2px`).
  static const double _thumbRemoveInset = GuSpacing.s2;

  static const int _textRows = 5;
  static const int _questionRows = 2;
  static const int _notifTextLines = 2;

  /// `bytes` → megabayt (`imageTooLarge` metni).
  static const int _bytesPerMb = 1024 * 1024;

  static final List<Key> _typeKeys = [
    GuKey.action('FED-03.type.post'),
    GuKey.action('FED-03.type.announcement'),
    GuKey.action('FED-03.type.poll'),
  ];

  static const List<PostType> _types = [
    PostType.post,
    PostType.announcement,
    PostType.poll,
  ];

  late final TextEditingController _title;
  late final TextEditingController _text;
  ProviderSubscription<(String, String)>? _fieldsSubscription;

  ComposeViewModelProvider get _provider => composeViewModelProvider(
    clubId: widget.clubId,
    editPostId: widget.editPostId,
    initialType: widget.initialType,
  );

  ComposeViewModel get _viewModel => ref.read(_provider.notifier);

  @override
  void initState() {
    super.initState();
    final state = ref.read(_provider);
    _title = TextEditingController(text: state.title);
    _text = TextEditingController(text: state.text);
    // Alanlar ViewModel'den de değişir: "Temizle", sınırda kesme.
    _fieldsSubscription = ref.listenManual(
      _provider.select((state) => (state.title, state.text)),
      (_, fields) {
        _show(_title, fields.$1);
        _show(_text, fields.$2);
      },
    );
  }

  @override
  void dispose() {
    _fieldsSubscription?.close();
    _title.dispose();
    _text.dispose();
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

  void _onTitle(String value) {
    _viewModel.setTitle(value);
    _show(_title, ref.read(_provider).title);
  }

  void _onText(String value) {
    _viewModel.setText(value);
    _show(_text, ref.read(_provider).text);
  }

  String? _requiredText(FormFieldError? error, AppLocalizations l10n) =>
      error == null ? null : l10n.authErrRequired;

  String? _imageErrorText(FormFieldError? error, AppLocalizations l10n) =>
      switch (error) {
        null => null,
        FormFieldError.limitExceeded => l10n.imageTooLarge(
          Limits.imageMaxBytes ~/ _bytesPerMb,
        ),
        _ => l10n.imageInvalidType,
      };

  Widget _typeSelector(ComposeState state) {
    final l10n = context.l10n;
    final selector = GuSegmented(
      options: [
        GuSegmentOption(
          id: PostType.post.name,
          label: l10n.feedTypePost,
          icon: GuIcons.fileText,
        ),
        GuSegmentOption(
          id: PostType.announcement.name,
          label: l10n.feedTypeAnnouncement,
          icon: GuIcons.megaphone,
        ),
        GuSegmentOption(
          id: PostType.poll.name,
          label: l10n.feedTypePoll,
          icon: GuIcons.chartColumn,
        ),
      ],
      value: state.type.name,
      onChanged: (id) => _viewModel.setType(
        _types.firstWhere((type) => type.name == id),
      ),
      optionKeyBuilder: (index) => _typeKeys[index],
    );
    if (!state.isEditing) return selector;
    // Tür yayından sonra değişmez.
    return IgnorePointer(
      child: Opacity(opacity: GuOpacity.disabled, child: selector),
    );
  }

  Widget _authorRow(ComposeState state, UserModel? me) {
    final gu = context.gu;
    final name = me?.name ?? '';
    final clubName = state.club?.name ?? '';
    final onSwitchClub = state.isEditing ? null : widget.onSwitchClub;
    return Row(
      spacing: GuSpacing.s8,
      children: [
        GuAvatar(
          initials: name.initials,
          seed: me?.avatarSeed ?? name,
          size: _avatarSize,
          image: ref.userAvatarImage(me),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: gu.text.labelL.copyWith(color: gu.colors.textHeading),
              ),
              if (onSwitchClub == null)
                Text(
                  clubName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: gu.text.caption,
                )
              else
                GuTapTarget(
                  key: GuKey.action('FED-03.switchClub'),
                  onTap: onSwitchClub,
                  semanticLabel: clubName,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: GuSpacing.s4,
                    children: [
                      Flexible(
                        child: Text(
                          clubName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: gu.text.caption.copyWith(
                            color: gu.colors.brandPrimaryText,
                          ),
                        ),
                      ),
                      GuIcon(
                        GuIcons.chevronDown,
                        size: GuSizes.icon12,
                        color: gu.colors.brandPrimaryText,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _images(ComposeState state) {
    final gu = context.gu;
    final l10n = context.l10n;
    final resolver = composeImageResolver(
      state.images,
      ref.watch(postImageResolverProvider),
    );
    final error = _imageErrorText(state.errors[ComposeField.images], l10n);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s8,
      children: [
        Row(
          spacing: GuSpacing.s8,
          children: [
            Expanded(
              child: Text(
                l10n.composeImagesCount(
                  l10n.composeImages,
                  state.images.length,
                  Limits.postImagesMax,
                ),
                style: gu.text.fieldLabel,
              ),
            ),
            GuButton(
              key: GuKey.action('FED-03.addImage'),
              label: l10n.composeAddImage,
              size: GuButtonSize.sm,
              variant: GuButtonVariant.tonal,
              icon: GuIcons.image,
              disabled: !state.canAddImage,
              onPressed: widget.onAddImage,
              onDisabledPressed: widget.onAddImage,
            ),
          ],
        ),
        if (state.images.isNotEmpty)
          Wrap(
            spacing: GuSpacing.s8,
            runSpacing: GuSpacing.s8,
            children: [
              for (final (index, image) in state.images.indexed)
                _thumb(state, index, image, resolver),
            ],
          ),
        if (error != null) ComposeErrorLine(error),
      ],
    );
  }

  Widget _thumb(
    ComposeState state,
    int index,
    ComposeImage image,
    PostImageResolver resolver,
  ) => SizedBox.square(
    dimension: _thumbSize,
    child: ClipRRect(
      borderRadius: GuRadius.borderSm,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PostImage(
            image: image.previewModel(index),
            club: state.club,
            imageOf: resolver,
          ),
          Positioned(
            top: _thumbRemoveInset,
            right: _thumbRemoveInset,
            child: GuIconButton(
              key: GuKey.action('FED-03.removeImage.$index'),
              icon: GuIcons.x,
              semanticLabel: context.l10n.commonRemove,
              size: GuIconButtonSize.xs,
              iconSize: GuSizes.icon14,
              onCover: true,
              onPressed: () => _viewModel.removeImage(index),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _pinRow(ComposeState state) => ComposeSwitchRow(
    label: context.l10n.composePin,
    value: state.pinAfterPublish,
    switchKey: GuKey.action('FED-03.pin'),
    onChanged: (value) => _viewModel.setPinAfterPublish(value: value),
  );

  /// Bildirim önizlemesi (`screens-clubs.js:210`): amblem + kulüp adı · "Az
  /// önce" · başlık · iki satır metin; boş alanlar etiketleriyle çizilir.
  Widget _notificationPreview(ComposeState state) {
    final gu = context.gu;
    final l10n = context.l10n;
    final heading = gu.colors.textHeading;
    return GuField(
      label: l10n.composeNotifPreview,
      child: GuCard(
        padding: GuInsets.all16,
        child: Row(
          spacing: GuSpacing.s12,
          children: [
            const GuEmblem(
              size: GuEmblemSize.xs,
              child: GuLogo(size: GuSizes.icon20),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: GuSpacing.s2,
                children: [
                  Row(
                    spacing: GuSpacing.s8,
                    children: [
                      Expanded(
                        child: Text(
                          state.club?.name ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: gu.text.labelM.copyWith(color: heading),
                        ),
                      ),
                      Text(l10n.timeJustNow, style: gu.text.caption),
                    ],
                  ),
                  Text(
                    state.title.isEmpty
                        ? l10n.composeAnnouncementTitle
                        : state.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: gu.text.labelL.copyWith(color: heading),
                  ),
                  Text(
                    state.text.isEmpty ? l10n.composeText : state.text,
                    maxLines: _notifTextLines,
                    overflow: TextOverflow.ellipsis,
                    style: gu.text.bodyS.copyWith(
                      color: gu.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(_provider);
    final me = ref.watch(
      sessionViewModelProvider.select((session) => session.user),
    );
    final isPoll = state.type == PostType.poll;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s16,
      children: [
        if (state.isSubmitError)
          GuBanner(kind: GuBannerKind.danger, text: l10n.sysErrorTitle),
        _typeSelector(state),
        _authorRow(state, me),
        if (state.type == PostType.announcement)
          GuInput(
            controller: _title,
            label: l10n.composeAnnouncementTitle,
            maxLength: Limits.postTitleMax,
            showCounter: true,
            errorText: _requiredText(state.errors[ComposeField.title], l10n),
            onChanged: _onTitle,
            actionKey: GuKey.action('FED-03.title'),
          ),
        GuInput(
          controller: _text,
          label: isPoll ? l10n.composeQuestion : l10n.composeText,
          placeholder: l10n.feedComposePlaceholder,
          multiline: true,
          rows: isPoll ? _questionRows : _textRows,
          maxLength: Limits.postTextMax,
          showCounter: true,
          readOnly: state.isPollLocked,
          autofocus: !state.isEditing,
          errorText: _requiredText(state.errors[ComposeField.text], l10n),
          onChanged: _onText,
          actionKey: GuKey.action('FED-03.text'),
        ),
        ...switch (state.type) {
          PostType.post => [_images(state), _pinRow(state)],
          PostType.announcement => [
            if (!state.isEditing) ...[
              ComposeSwitchRow(
                label: l10n.composePushToggle,
                help: state.limitReached
                    ? l10n.composeLimitReached
                    : l10n.composePushHelp,
                value: state.pushActive,
                disabled: state.limitReached,
                switchKey: GuKey.action('FED-03.pushToggle'),
                onChanged: (value) => _viewModel.setPushEnabled(value: value),
                onDisabledPressed: () => unawaited(_viewModel.explainLimit()),
              ),
              AnnouncementQuotaBar(
                used: state.quotaUsed,
                limit: state.quotaLimit,
              ),
            ],
            _pinRow(state),
            if (!state.isEditing) _notificationPreview(state),
          ],
          PostType.poll => [
            PollEditor(
              clubId: widget.clubId,
              editPostId: widget.editPostId,
              initialType: widget.initialType,
            ),
          ],
        },
      ],
    );
  }
}
