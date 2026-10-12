import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/auth/provider/setup_profile_state.dart';
import 'package:gu_kulupler/features/auth/provider/setup_profile_view_model.dart';
import 'package:gu_kulupler/features/auth/view/mixin/setup_profile_view_mixin.dart';
import 'package:gu_kulupler/features/auth/view/widget/setup_profile_info_step.dart';
import 'package:gu_kulupler/features/auth/view/widget/setup_profile_interests_step.dart';
import 'package:gu_kulupler/features/auth/view/widget/setup_profile_photo_step.dart';
import 'package:gu_kulupler/product/mixin/unsaved_changes_mixin.dart';
import 'package:gu_ui/gu_ui.dart';

/// Profilini tamamla — `SetupProfileRoute` (`/setup-profile`); prototip
/// `Setup` (`screens-auth.js:135–148`).
///
/// Çubuk: kapat (`x`) + "Adım n/3" + adım çubuğu. Gövde (yatay 16, üst 16,
/// aralık 16) adıma göre değişir: 1 fotoğraf · 2 bölüm + sınıf · 3 ilgi
/// alanları. Alt çubuk: 2. adımdan itibaren "Geri" + "Devam"; son adımda
/// "Tamamla" (gönderim sürerken yükleniyor).
///
/// Profil tamamlanınca ekran kendisi gezinmez; oturum `active` olur ve router
/// kabuğa yönlendirir. Davranış `SetupProfileViewMixin`'dedir. Alt güvenli
/// alanı eylem çubuğu kaplar (K-07).
///
/// Design: AUT-05
class SetupProfileView extends ConsumerStatefulWidget {
  /// Profil tamamlama ekranı.
  const SetupProfileView({super.key});

  @override
  ConsumerState<SetupProfileView> createState() => _SetupProfileViewState();
}

class _SetupProfileViewState extends ConsumerState<SetupProfileView>
    with UnsavedChangesMixin<SetupProfileView>, SetupProfileViewMixin {
  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(setupProfileViewModelProvider);
    final step = state.step;
    final avatar = state.avatar;
    final total = SetupStep.values.length;
    final progress = '${step.number}/$total';

    return buildUnsavedGuard(
      child: Scaffold(
        backgroundColor: gu.colors.bgCanvas,
        appBar: GuAppBar(
          onBack: onClose,
          closeIcon: true,
          backSemanticLabel: l10n.a11yClose,
          backActionKey: GuKey.action('AUT-05.close'),
          titleWidget: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: GuSpacing.s6,
            children: [
              Text(
                l10n.authSetupProgress('${step.number}', '$total'),
                style: gu.text.caption,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
              GuStepbar(
                step: step.number,
                total: total,
                semanticLabel: progress,
              ),
            ],
          ),
        ),
        bottomNavigationBar: GuStickyCta(
          children: [
            if (step != SetupStep.photo)
              GuButton(
                key: GuKey.action('AUT-05.back'),
                label: l10n.commonBack,
                variant: GuButtonVariant.outline,
                disabled: state.isSubmitting,
                onPressed: viewModel.back,
              ),
            GuButton(
              key: step.isLast
                  ? GuKey.action('AUT-05.finish')
                  : GuKey.action('AUT-05.next'),
              label: step.isLast ? l10n.commonFinish : l10n.commonContinue,
              loading: state.isSubmitting,
              onPressed: () => unawaited(viewModel.next()),
            ),
          ],
        ),
        body: SingleChildScrollView(
          // Adım başına ayrı kaydırma konumu.
          key: PageStorageKey<String>('setup-${step.name}'),
          padding: GuInsets.only(
            left: GuSpacing.s16,
            top: GuSpacing.s16,
            right: GuSpacing.s16,
            bottom: GuSpacing.s16 + GuSizes.screenScrollBottomExtra,
          ),
          child: switch (step) {
            SetupStep.photo => SetupProfilePhotoStep(
              name: state.name,
              avatarSeed: state.avatarSeed,
              photo: avatar == null ? null : MemoryImage(avatar.bytes),
              errorText: errorTextOf(SetupProfileField.photo, state, l10n),
              onAddPhoto: () => unawaited(openPhotoSource()),
              onSkip: viewModel.skipPhoto,
            ),
            SetupStep.info => SetupProfileInfoStep(
              departmentId: state.departmentId,
              year: state.year,
              showYear: !state.isStaff,
              departmentError: errorTextOf(
                SetupProfileField.department,
                state,
                l10n,
              ),
              yearError: errorTextOf(SetupProfileField.year, state, l10n),
              onPickDepartment: () => unawaited(openDepartmentPicker()),
              onPickYear: () => unawaited(openYearPicker()),
            ),
            SetupStep.interests => SetupProfileInterestsStep(
              selected: state.interests,
              errorText: errorTextOf(SetupProfileField.interests, state, l10n),
              submitErrorText: submitErrorTextOf(state, l10n),
              onToggle: viewModel.toggleInterest,
            ),
          },
        ),
      ),
    );
  }
}
