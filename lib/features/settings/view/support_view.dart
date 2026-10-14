import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/settings/provider/support_state.dart';
import 'package:gu_kulupler/features/settings/provider/support_view_model.dart';
import 'package:gu_kulupler/features/settings/view/mixin/support_view_mixin.dart';
import 'package:gu_kulupler/features/settings/view/widget/support_faq_list.dart';
import 'package:gu_kulupler/features/settings/view/widget/support_sent_card.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/mixin/unsaved_changes_mixin.dart';
import 'package:gu_kulupler/product/widget/form/form_error_line.dart';
import 'package:gu_ui/gu_ui.dart';

/// SET-05 Yardım ve destek — `SupportRoute` (`/profile/settings/support`);
/// prototip `Support` (`screens-profile.js:107–122`).
///
/// Gövde (`.col.gap16.px16.pb24`): SSS arama alanı · "Sık sorulan sorular"
/// (`t-title-s`) · SSS kartı (tek açık soru) · "Bize ulaş" · form (konu
/// seçici, sayaçlı mesaj, "Ekran görüntüsü ekle" + "İsteğe bağlı", tam
/// genişlik "Gönder") ya da gönderimden sonra başarı kartı. Klavye açıkken
/// gövde küçülür ve kayar.
///
/// Davranış `SupportViewMixin`'dedir; veri okuması yoktur (yükleniyor / boş
/// / hata durumu tasarımda yok — çevrimdışı gönderim TST-24).
///
/// Design: SET-05
class SupportView extends ConsumerStatefulWidget {
  /// Destek.
  const SupportView({super.key});

  @override
  ConsumerState<SupportView> createState() => _SupportViewState();
}

class _SupportViewState extends ConsumerState<SupportView>
    with UnsavedChangesMixin<SupportView>, SupportViewMixin {
  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(supportViewModelProvider);
    final sent = state.displayTicketNo;

    return buildUnsavedGuard(
      child: Scaffold(
        backgroundColor: gu.colors.bgCanvas,
        appBar: GuAppBar(
          title: l10n.supportTitle,
          onBack: onBack,
          backSemanticLabel: l10n.a11yBack,
          backActionKey: GuKey.action('SET-05.back'),
        ),
        body: SingleChildScrollView(
          padding: GuInsets.only(
            left: GuSpacing.s16,
            right: GuSpacing.s16,
            bottom:
                GuSpacing.s24 +
                MediaQuery.paddingOf(context).bottom +
                GuSizes.screenScrollBottomExtra,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: GuSpacing.s16,
            children: [
              GuSearchField(
                actionKey: GuKey.action('SET-05.search'),
                value: state.faqQuery,
                placeholder: l10n.supportSearchFaq,
                semanticLabel: l10n.supportSearchFaq,
                onChanged: viewModel.setFaqQuery,
              ),
              _heading(context, l10n.supportFaq),
              SupportFaqList(
                items: faqItems(state, l10n),
                expanded: state.expandedFaq,
                onToggle: viewModel.toggleFaq,
                emptyText: l10n.supportNoFaq,
              ),
              _heading(context, l10n.supportContact),
              if (sent != null)
                SupportSentCard(
                  ticketNo: sent,
                  onNewRequest: viewModel.newRequest,
                )
              else
                ..._form(context, state, l10n),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _form(
    BuildContext context,
    SupportState state,
    AppLocalizations l10n,
  ) {
    final gu = context.gu;
    final subject = state.subject;
    final attached = state.attachment != null;
    final attachmentError = errorTextOf(SupportField.attachment, state, l10n);
    final submitError = submitErrorTextOf(state, l10n);
    return [
      GuPickerField(
        actionKey: GuKey.action('SET-05.subject'),
        label: l10n.supportSubject,
        value: subject == null
            ? null
            : SupportViewMixin.subjectLabel(l10n, subject),
        placeholder: l10n.commonSelect,
        errorText: errorTextOf(SupportField.subject, state, l10n),
        onTap: () => unawaited(openSubjectMenu()),
      ),
      GuInput(
        actionKey: GuKey.action('SET-05.message'),
        controller: messageController,
        label: l10n.supportMessage,
        multiline: true,
        maxLength: Limits.supportMessageMax,
        showCounter: true,
        errorText: errorTextOf(SupportField.message, state, l10n),
        onChanged: viewModel.setMessage,
      ),
      Wrap(
        spacing: GuSpacing.s8,
        runSpacing: GuSpacing.s8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          GuButton(
            key: GuKey.action('SET-05.attach'),
            label: attached ? l10n.supportAttached : l10n.supportAttach,
            icon: attached ? GuIcons.circleCheck : GuIcons.image,
            variant: attached ? GuButtonVariant.tonal : GuButtonVariant.outline,
            size: GuButtonSize.sm,
            onPressed: () => unawaited(openAttachmentSource()),
          ),
          Text(l10n.commonOptional, style: gu.text.caption),
        ],
      ),
      if (attachmentError != null) FormErrorLine(attachmentError),
      GuButton(
        key: GuKey.action('SET-05.send'),
        label: l10n.commonSend,
        full: true,
        loading: state.isSubmitting,
        onPressed: () => unawaited(send()),
      ),
      if (submitError != null) FormErrorLine(submitError),
    ];
  }

  /// `h2.t-title-s` bölüm başlığı.
  static Widget _heading(BuildContext context, String text) => Semantics(
    header: true,
    child: Text(text, style: context.gu.text.titleS),
  );
}
