import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/event_form_state.dart';
import 'package:gu_kulupler/features/management/view/mixin/event_form_view_mixin.dart';
import 'package:gu_kulupler/features/management/view/widget/event_form.dart';
import 'package:gu_kulupler/product/mixin/unsaved_changes_mixin.dart';
import 'package:gu_ui/gu_ui.dart';

/// Etkinlik formu — `EventFormRoute` (`/clubs/:clubId/manage/events/new`) ve
/// `EventEditRoute` (`/clubs/:clubId/manage/events/:eventId/edit`); iki rota
/// sınıfı, tek view (CD-54). Guard `M` (router'da).
///
/// Yukarıdan aşağıya (prototip `screens-manage.js:102–117`): başlık çubuğu
/// (kapat · "Etkinlik oluştur · n/3" + adım çubuğu) · kaydırma alanı
/// (`col gap16 px16 pt8 pb24`): gönderim hatası bandı + `EventForm` · alt
/// çubuk: adım 1 "Devam"; adım 2 "Geri" + "Devam"; adım 3 "Geri" + "Taslak
/// olarak kaydet" + "Yayınla" (yayındaki etkinlikte "Kaydet").
///
/// * Kapak SHT-31 (`CoverPickerContent`), mekân SHT-30 (`PlacePickerSheet`),
///   tarih / saat SHT-28 / SHT-29; kaydedilmemiş değişiklikte kapat → DLG-25;
///   yayın → DLG-22.
/// * Düzenleme ([eventId]): durum sırası hata ("Yeniden dene") → yükleniyor
///   (iskelet) → form. Yeni etkinlikte okuma beklenmez; boş durum yoktur
///   (K-51: tasarımdaki MGT-05 durum görüntüleri normal görünümdür).
/// * Yayındaki etkinlik başladıysa tarih / saat kilitlidir (W-82); kayıtlısı
///   olan yayındaki etkinlikte "Taslak olarak kaydet" kapalıdır ve
///   açıklaması çizilir (K-F).
/// * Etkinlik yönetme yetkisi olmayan (danışman, rolsüz süper admin)
///   kullanıcı formu görmez: kilit çizimi + "Bu paneli görüntüleme yetkin
///   yok." (rota guard'ı normalde buraya düşürmez; prototip `NoAccess`).
/// * Çevrimdışı bandı kökte çizilir; form ekranda kalır, yazım TST-24 verir.
/// * Klavye açıkken içerik kayar (`resizeToAvoidBottomInset` + kaydırma).
///
/// Davranış `EventFormViewModel` ve `EventFormViewMixin`'dedir.
///
/// Design: MGT-05
class EventFormView extends ConsumerStatefulWidget {
  /// [clubId] kulübünde yeni etkinlik; [eventId] verilirse o etkinliğin
  /// düzenlemesi.
  const EventFormView({required this.clubId, this.eventId, super.key});

  /// Kulüp kimliği (`EventFormRoute.clubId` / `EventEditRoute.clubId`).
  final String clubId;

  /// Düzenlenen etkinlik (`EventEditRoute.eventId`); yeni etkinlikte `null`.
  final String? eventId;

  /// Düzenleme kipi mi.
  bool get isEdit => eventId != null;

  @override
  ConsumerState<EventFormView> createState() => _EventFormViewState();
}

class _EventFormViewState extends ConsumerState<EventFormView>
    with UnsavedChangesMixin<EventFormView>, EventFormViewMixin {
  /// Prototip `NoAccess` (`screens-manage.js:11`).
  Widget _noAccess() {
    final gu = context.gu;
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      appBar: GuAppBar(
        onBack: leaveScreen,
        backSemanticLabel: l10n.a11yBack,
        backActionKey: GuKey.action('MGT-05.back'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: GuEmptyState(
            illustration: GuIllustrations.locked,
            description: l10n.mgtNoAccess,
          ),
        ),
      ),
    );
  }

  /// Başlık: "Etkinlik oluştur · n/3" + adım çubuğu.
  Widget _title(EventFormState state) {
    final gu = context.gu;
    final l10n = context.l10n;
    final total = EventFormStep.values.length;
    final step = state.step.number;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: GuSpacing.s6,
      children: [
        Text(
          l10n.eventFormProgress(
            widget.isEdit ? l10n.eventFormEditTitle : l10n.eventFormTitle,
            '$step',
            '$total',
          ),
          style: gu.text.caption,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
        GuStepbar(step: step, total: total, semanticLabel: '$step/$total'),
      ],
    );
  }

  Widget _cta(EventFormState state) {
    final l10n = context.l10n;
    final step = state.step;
    return GuStickyCta(
      children: [
        if (step != EventFormStep.basics)
          GuButton(
            key: GuKey.action('MGT-05.back'),
            label: l10n.commonBack,
            variant: GuButtonVariant.outline,
            disabled: state.isSubmitting,
            onPressed: viewModel.back,
          ),
        if (!step.isLast)
          GuButton(
            key: GuKey.action('MGT-05.next'),
            label: l10n.commonContinue,
            onPressed: viewModel.next,
          )
        else ...[
          GuButton(
            key: GuKey.action('MGT-05.saveDraft'),
            label: l10n.eventFormSaveDraft,
            variant: GuButtonVariant.outline,
            disabled: state.isSubmitting || !state.canUnpublish,
            onPressed: () => unawaited(saveDraft()),
          ),
          GuButton(
            key: GuKey.action('MGT-05.publish'),
            label: state.isPublished ? l10n.commonSave : l10n.eventFormPublish,
            loading: state.isSubmitting,
            onPressed: () => unawaited(publish()),
          ),
        ],
      ],
    );
  }

  Widget _form(EventFormState state) {
    final gu = context.gu;
    final l10n = context.l10n;
    return SingleChildScrollView(
      // Adım başına ayrı kaydırma konumu (prototip `routeKey`).
      key: PageStorageKey<String>('event-form-${state.step.name}'),
      padding: GuInsets.only(
        left: GuSpacing.s16,
        right: GuSpacing.s16,
        top: GuSpacing.s8,
        bottom: GuSpacing.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSpacing.s16,
        children: [
          if (state.isSubmitError)
            GuBanner(
              kind: GuBannerKind.danger,
              text: l10n.sysErrorTitle,
              card: true,
            ),
          EventForm(
            step: state.step,
            title: state.title,
            desc: state.desc,
            type: state.type,
            startsAt: state.startsAt,
            endsAt: state.endsAt,
            placeId: state.placeId,
            placeText: state.placeText,
            capacity: state.capacityValue,
            visibility: state.visibility,
            autoReminder: state.autoReminder,
            coverPalette: state.coverPalette,
            coverPattern: state.coverPattern,
            coverSeed: state.original?.coverSeed,
            coverPath: state.coverPath,
            coverImage: switch (state.pendingCover) {
              final cover? => MemoryImage(cover.bytes),
              null => null,
            },
            isCoverUploading: state.isCoverUploading,
            timeLocked: state.timeLocked,
            minCapacity: state.minCapacity,
            club: state.club,
            registeredCount: widget.isEdit ? state.goingCount : null,
            conflictCount: state.conflictCount,
            errors: state.errors,
            onTitleChanged: viewModel.setTitle,
            onDescChanged: viewModel.setDesc,
            onTypeChanged: viewModel.setType,
            onCoverTap: () => unawaited(openCover()),
            onStartDateTap: () => unawaited(openStartDate()),
            onStartTimeTap: () => unawaited(openStartTime()),
            onEndDateTap: () => unawaited(openEndDate()),
            onEndTimeTap: () => unawaited(openEndTime()),
            onPlaceTap: () => unawaited(openPlace()),
            onCapacityChanged: viewModel.setCapacity,
            onVisibilityChanged: viewModel.setVisibility,
            onAutoReminderChanged: (value) =>
                viewModel.setAutoReminder(value: value),
          ),
          // K-F: kayıtlısı olan yayındaki etkinlik taslağa alınamaz.
          if (state.step.isLast && !state.canUnpublish)
            Text(
              l10n.sht23UnpublishBlocked,
              style: gu.text.caption,
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(provider);
    // Rota guard'ı ve Rules ile aynı koşul: yalnızca kulüp yönetimi
    // (başkan / yönetim kurulu) etkinlik yazar; danışman ve rolsüz süper
    // admin salt okur.
    final canWrite = ref.watch(
      sessionViewModelProvider.select(
        (session) => RolePolicy.can(
          ClubPermission.manageEvents,
          session.roleIn(widget.clubId),
          isSuper: session.isSuperAdmin,
        ),
      ),
    );
    if (!canWrite) return _noAccess();

    // Sıra: hata → yükleniyor → form (boş durum yoktur — K-51).
    final hasForm = !state.isError && !state.isLoading;
    final Widget body;
    if (state.isError) {
      body = Center(
        child: SingleChildScrollView(
          child: GuErrorState(
            title: l10n.sysErrorTitle,
            description: l10n.sysErrorDesc,
            retryLabel: l10n.commonRetry,
            retryActionKey: GuKey.action('MGT-05.retry'),
            onRetry: retry,
          ),
        ),
      );
    } else if (state.isLoading) {
      body = SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: GuSkeletonList(
          semanticLabel: l10n.commonLoading,
          count: 1,
          variant: GuSkeletonVariant.card,
        ),
      );
    } else {
      body = _form(state);
    }

    return buildUnsavedGuard(
      child: Scaffold(
        backgroundColor: gu.colors.bgCanvas,
        appBar: GuAppBar(
          onBack: onClose,
          closeIcon: true,
          backSemanticLabel: l10n.a11yClose,
          backActionKey: GuKey.action('MGT-05.close'),
          title: hasForm ? null : l10n.eventFormEditTitle,
          titleWidget: hasForm ? _title(state) : null,
        ),
        bottomNavigationBar: hasForm ? _cta(state) : null,
        body: body,
      ),
    );
  }
}
