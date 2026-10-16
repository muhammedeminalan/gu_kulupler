import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/profile/provider/edit_profile_state.dart';
import 'package:gu_kulupler/features/profile/provider/edit_profile_view_model.dart';
import 'package:gu_kulupler/features/profile/view/mixin/edit_profile_view_mixin.dart';
import 'package:gu_kulupler/features/profile/view/widget/edit_profile_interests.dart';
import 'package:gu_kulupler/features/profile/view/widget/profile_avatar_button.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_kulupler/product/media/user_avatar_image.dart';
import 'package:gu_kulupler/product/mixin/unsaved_changes_mixin.dart';
import 'package:gu_kulupler/product/widget/form/form_error_line.dart';
import 'package:gu_ui/gu_ui.dart';

/// "Profili düzenle" ekranı — `EditProfileRoute` (`/profile/edit`);
/// prototip `EditProfile` (`screens-profile.js:21–36`).
///
/// Gövde (`.col.gap16.px16.pb24`): ortalı avatar düğmesi + "Fotoğrafı
/// değiştir" (aralık 8) · ad · bölüm (SHT-02) · sınıf (SHT-03; personelde
/// yok) · ilgi alanları (sayaçlı çipler) · biyografi (çok satır, sayaç) ·
/// kilitli e-posta (dokunma TST-20) · gizlilik bandı. Alt çubuk: "Kaydet"
/// (değişiklik yokken kapalı → TST-X9; kaydederken yükleniyor). Klavye
/// açıkken gövde küçülür ve kayar.
///
/// Davranış `EditProfileViewMixin`'dedir. Profil okunamazsa hata durumu.
///
/// Design: PRF-02
class EditProfileView extends ConsumerStatefulWidget {
  /// Oturumdaki kullanıcının profil formu.
  const EditProfileView({super.key});

  @override
  ConsumerState<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends ConsumerState<EditProfileView>
    with UnsavedChangesMixin<EditProfileView>, EditProfileViewMixin {
  /// `screens-profile.js:32` `Input multiline rows=3` (görünen satır
  /// `GuInput` içinde en az 4 — css:169 `min-height:88px`).
  static const int _bioRows = 3;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(editProfileViewModelProvider);
    final original = state.original;

    return buildUnsavedGuard(
      child: Scaffold(
        backgroundColor: gu.colors.bgCanvas,
        appBar: GuAppBar(
          title: l10n.editProfileTitle,
          onBack: onBack,
          backSemanticLabel: l10n.a11yBack,
          backActionKey: GuKey.action('PRF-02.back'),
        ),
        bottomNavigationBar: original == null
            ? null
            : GuStickyCta(
                children: [
                  GuButton(
                    key: GuKey.action('PRF-02.save'),
                    label: l10n.commonSave,
                    loading: state.isSubmitting,
                    disabled: !state.isDirty,
                    onPressed: () => unawaited(save()),
                    onDisabledPressed: () => unawaited(save()),
                  ),
                ],
              ),
        body: original == null
            ? _error(l10n)
            : _form(context, state, original, l10n),
      ),
    );
  }

  Widget _form(
    BuildContext context,
    EditProfileState state,
    UserModel original,
    AppLocalizations l10n,
  ) {
    final gu = context.gu;
    final avatar = state.avatar;
    final departmentId = state.departmentId;
    final year = state.year;
    final photoError = errorTextOf(EditProfileField.photo, state, l10n);
    final submitError = submitErrorTextOf(state, l10n);
    return GuFormScrollView(
      padding: GuInsets.only(
        left: GuSpacing.s16,
        right: GuSpacing.s16,
        bottom: GuSpacing.s24 + GuSizes.screenScrollBottomExtra,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSpacing.s16,
        children: [
          Column(
            spacing: GuSpacing.s8,
            children: [
              ProfileAvatarButton(
                actionKey: GuKey.action('PRF-02.avatar'),
                initials: original.name.initials,
                seed: original.avatarSeed,
                image: avatar != null
                    ? MemoryImage(avatar.bytes)
                    : ref.userAvatarImage(
                        original,
                        displaySize: ProfileAvatarButton.avatarSize,
                      ),
                semanticLabel: l10n.profileChangePhoto,
                onTap: () => unawaited(openPhotoSource()),
              ),
              Text(
                l10n.profileChangePhoto,
                style: gu.text.caption,
                textAlign: TextAlign.center,
              ),
              if (photoError != null) FormErrorLine(photoError),
            ],
          ),
          GuInput(
            actionKey: GuKey.action('PRF-02.name'),
            controller: nameController,
            label: l10n.authFullName,
            errorText: errorTextOf(EditProfileField.name, state, l10n),
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.done,
            onChanged: viewModel.setName,
          ),
          GuPickerField(
            actionKey: GuKey.action('PRF-02.department'),
            label: l10n.profileDepartment,
            icon: GuIcons.graduationCap,
            value: departmentId == null
                ? null
                : StaticLabels.department(context, departmentId),
            placeholder: l10n.commonSelect,
            onTap: () => unawaited(openDepartmentPicker()),
          ),
          if (!state.isStaff)
            GuPickerField(
              actionKey: GuKey.action('PRF-02.year'),
              label: l10n.profileYear,
              icon: GuIcons.calendarDays,
              value: year == null ? null : StaticLabels.year(context, year),
              placeholder: l10n.commonSelect,
              onTap: () => unawaited(openYearPicker()),
            ),
          EditProfileInterests(
            selected: state.interests,
            errorText: errorTextOf(EditProfileField.interests, state, l10n),
            onToggle: viewModel.toggleInterest,
          ),
          GuInput(
            actionKey: GuKey.action('PRF-02.bio'),
            controller: bioController,
            label: l10n.editProfileBio,
            multiline: true,
            rows: _bioRows,
            maxLength: Limits.bioMax,
            showCounter: true,
            onChanged: viewModel.setBio,
          ),
          GuActionSurface(
            key: GuKey.action('PRF-02.lockedEmail'),
            borderRadius: GuRadius.borderSm,
            onTap: viewModel.onLockedFieldTap,
            // Alan salt okunurdur: dokunma metin alanına değil kilit
            // bildirimine gider (prototip sarmalayıcı `div`).
            builder: (context, _) => AbsorbPointer(
              child: GuInput(
                actionKey: GuKey.action('PRF-02.email'),
                controller: emailController,
                label: l10n.authEmail,
                locked: true,
                help: l10n.editProfileEmailLocked,
              ),
            ),
          ),
          GuBanner(
            icon: GuIcons.shield,
            text: l10n.editProfilePrivacy,
            card: true,
          ),
          if (submitError != null) FormErrorLine(submitError),
        ],
      ),
    );
  }

  /// Profil okunamadı: hata durumu, kalan alanda dikeyde ortalı.
  Widget _error(AppLocalizations l10n) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: GuInsets.only(
        bottom:
            MediaQuery.paddingOf(context).bottom +
            GuSizes.screenScrollBottomExtra,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(
          child: GuErrorState(
            title: l10n.sysErrorTitle,
            description: l10n.sysErrorDesc,
            retryLabel: l10n.commonRetry,
            onRetry: retry,
            retryActionKey: GuKey.action('PRF-02.retry'),
          ),
        ),
      ),
    ),
  );
}
