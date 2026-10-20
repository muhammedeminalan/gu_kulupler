import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/notifications/provider/notification_prefs_state.dart';
import 'package:gu_kulupler/features/notifications/view/mixin/notification_prefs_view_mixin.dart';
import 'package:gu_kulupler/features/notifications/view/widget/quiet_hours_picker.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-07 "Kulüp bildirimleri" gövdesi — sayfa `features/clubs`'dadır;
/// NTF-02 onu içe aktaramaz, rota (kompozisyon kökü) verir.
typedef ClubPrefsSheetBuilder = Widget Function(String clubId, String clubName);

/// "Bildirim tercihleri" — `NotificationPrefsRoute`
/// (`/notifications/preferences`) ve T-28'de `SettingsNotificationPrefsRoute`
/// (`/profile/settings/notifications`); prototip `NotifPrefs`
/// (`screens-events.js:109–120`).
///
/// Yukarıdan aşağıya (`col gap16 px16 pb24`): başlık (geri · "Bildirim
/// tercihleri") · sistem izni kartı (izin yoksa "İzni aç") · genel anahtarlar
/// (duyurular, etkinlik hatırlatmaları, yeni etkinlikler, başvuru sonuçları,
/// yöneticide yönetim bildirimleri, sistem) · hatırlatma zamanı (1 saat /
/// 1 gün önce) · sessiz saatler (açıkken `QuietHoursPicker` → SHT-29) ·
/// kulüp bazlı ayarlar (SHT-07). Her değişiklik anında kaydedilir (TST-19).
///
/// * Durum sırası: hata ("Yeniden dene") → yükleniyor (iskelet) → dolu;
///   üyeliği olmayan kullanıcıda kulüp kartı "Üye olduğun kulüp yok." yazar.
///   Çevrimdışı bandı kökte çizilir; değişiklik TST-24 verir.
/// * [clubPrefsSheetBuilder] verilmezse kulüp satırı CLB-03'e gider.
///
/// Davranış `NotificationPrefsViewModel` + `NotificationPrefsViewMixin`'dedir.
///
/// Design: NTF-02
class NotificationPrefsView extends ConsumerStatefulWidget {
  /// Bildirim tercihleri.
  const NotificationPrefsView({this.clubPrefsSheetBuilder, super.key});

  /// Kulüp satırının açtığı SHT-07 gövdesi (rota verir).
  final ClubPrefsSheetBuilder? clubPrefsSheetBuilder;

  /// Tür satırının etiketi.
  static String labelOf(AppLocalizations l10n, NotificationPrefField field) =>
      switch (field) {
        NotificationPrefField.announcements => l10n.notifPrefsAnnouncements,
        NotificationPrefField.eventReminders => l10n.notifPrefsEventReminders,
        NotificationPrefField.newEvents => l10n.notifPrefsNewEvents,
        NotificationPrefField.newPosts => l10n.notifPrefsNewPosts,
        NotificationPrefField.newComments => l10n.notifPrefsNewComments,
        NotificationPrefField.applicationResults =>
          l10n.notifPrefsApplicationResults,
        NotificationPrefField.management => l10n.notifPrefsManagement,
        NotificationPrefField.system => l10n.notifPrefsSystem,
        NotificationPrefField.reminderTime => l10n.notifPrefsReminderTime,
        NotificationPrefField.quiet ||
        NotificationPrefField.quietRange => l10n.notifPrefsQuiet,
      };

  /// Tür satırının ikonu (`screens-events.js:112`).
  static GuIcons iconOf(NotificationPrefField field) => switch (field) {
    NotificationPrefField.announcements => GuIcons.megaphone,
    NotificationPrefField.eventReminders => GuIcons.bellRing,
    NotificationPrefField.newEvents => GuIcons.calendarPlus,
    NotificationPrefField.newPosts => GuIcons.newspaper,
    NotificationPrefField.newComments => GuIcons.messageCircle,
    NotificationPrefField.applicationResults => GuIcons.userCheck,
    NotificationPrefField.management => GuIcons.shieldCheck,
    NotificationPrefField.system => GuIcons.info,
    NotificationPrefField.reminderTime => GuIcons.clock,
    NotificationPrefField.quiet ||
    NotificationPrefField.quietRange => GuIcons.moon,
  };

  @override
  ConsumerState<NotificationPrefsView> createState() =>
      _NotificationPrefsViewState();
}

class _NotificationPrefsViewState extends ConsumerState<NotificationPrefsView>
    with NotificationPrefsViewMixin {
  static const GuIcons _fallbackClubIcon = GuIcons.users;

  /// Tür anahtarının aksiyon anahtarı (`NTF-02.toggle.<ad>`).
  static Key _toggleKey(NotificationPrefField field) => switch (field) {
    NotificationPrefField.announcements => GuKey.action(
      'NTF-02.toggle.announcements',
    ),
    NotificationPrefField.eventReminders => GuKey.action(
      'NTF-02.toggle.eventReminders',
    ),
    NotificationPrefField.newEvents => GuKey.action('NTF-02.toggle.newEvents'),
    NotificationPrefField.newPosts => GuKey.action('NTF-02.toggle.newPosts'),
    NotificationPrefField.newComments => GuKey.action(
      'NTF-02.toggle.newComments',
    ),
    NotificationPrefField.applicationResults => GuKey.action(
      'NTF-02.toggle.applicationResults',
    ),
    NotificationPrefField.management => GuKey.action(
      'NTF-02.toggle.management',
    ),
    NotificationPrefField.system => GuKey.action('NTF-02.toggle.system'),
    NotificationPrefField.quiet => GuKey.action('NTF-02.quiet'),
    NotificationPrefField.reminderTime ||
    NotificationPrefField.quietRange => throw ArgumentError.value(
      field,
      'field',
      'anahtar satırı değil',
    ),
  };

  /// `.card-body row gap12` (muted): izin durumu + "İzni aç".
  Widget _permissionCard(NotificationPrefsState state) {
    final gu = context.gu;
    final l10n = context.l10n;
    final granted = state.permissionGranted;
    return GuCard(
      muted: true,
      padding: GuCard.bodyPadding,
      child: Row(
        spacing: GuSpacing.s12,
        children: [
          GuIconBox(
            icon: granted ? GuIcons.bellRing : GuIcons.bellOff,
            tone: granted ? GuIconBoxTone.success : GuIconBoxTone.warning,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.notifPrefsPermission,
                  style: gu.text.labelL.copyWith(
                    color: gu.colors.textHeading,
                  ),
                ),
                Text(
                  granted ? l10n.commonOn : l10n.commonOff,
                  style: gu.text.caption,
                ),
              ],
            ),
          ),
          if (!granted)
            GuButton(
              key: GuKey.action('NTF-02.permission'),
              label: l10n.notifPrefsEnable,
              size: GuButtonSize.sm,
              variant: GuButtonVariant.tonal,
              onPressed: enablePermission,
            ),
        ],
      ),
    );
  }

  /// `.tile.is-plain.in-card`: ikon 20 `c-muted` + başlık + anahtar.
  Widget _switchTile(
    NotificationPrefsState state,
    NotificationPrefField field, {
    String? caption,
  }) {
    final l10n = context.l10n;
    final label = NotificationPrefsView.labelOf(l10n, field);
    return GuTile(
      plain: true,
      padding: GuTilePadding.inCard,
      leading: GuIcon(
        NotificationPrefsView.iconOf(field),
        size: GuSizes.icon20,
        color: context.gu.colors.textMuted,
      ),
      title: label,
      // `<span class="t-caption">` satır içidir: satır kutusu `.tile-text`'in
      // kalıtılan 15/1.47 satırından kısa olamaz (css:77) → bodyM payandası.
      sub2Widget: caption == null
          ? null
          : Text(
              caption,
              strutStyle: StrutStyle.fromTextStyle(context.gu.text.bodyM),
            ),
      trailing: GuSwitch(
        key: _toggleKey(field),
        value: state.isOn(field),
        semanticLabel: label,
        onChanged: (value) => toggle(field, value: value),
      ),
    );
  }

  /// Genel anahtarlar kartı (ayırıcılı satırlar).
  Widget _typesCard(NotificationPrefsState state) {
    final fields = [
      for (final field in NotificationPrefField.typeToggles)
        if (field != NotificationPrefField.management || state.showManagement)
          field,
    ];
    return GuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, field) in fields.indexed) ...[
            if (i > 0) const GuDivider(),
            _switchTile(state, field),
          ],
        ],
      ),
    );
  }

  /// `.field-label` + iki seçenekli dilim.
  Widget _reminderTime(NotificationPrefsState state) {
    final gu = context.gu;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s8,
      children: [
        Text(l10n.notifPrefsReminderTime, style: gu.text.fieldLabel),
        GuSegmented(
          options: [
            GuSegmentOption(
              id: ReminderOption.oneHour.json,
              label: l10n.reminder1h,
            ),
            GuSegmentOption(
              id: ReminderOption.oneDay.json,
              label: l10n.reminder1d,
            ),
          ],
          value: state.settings.reminderTime.json,
          optionKeyBuilder: (index) => index == 0
              ? GuKey.action('NTF-02.reminderTime.1h')
              : GuKey.action('NTF-02.reminderTime.1d'),
          onChanged: selectReminderTime,
        ),
      ],
    );
  }

  /// "Sessiz saatler" kartı; açıkken aralık seçicileri.
  Widget _quietCard(NotificationPrefsState state) {
    final l10n = context.l10n;
    return GuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _switchTile(
            state,
            NotificationPrefField.quiet,
            caption: l10n.notifPrefsQuietDesc,
          ),
          if (state.settings.quiet)
            QuietHoursPicker(
              from: state.quietFrom,
              to: state.quietTo,
              onPickFrom: pickQuietFrom,
              onPickTo: pickQuietTo,
              fromKey: GuKey.action('NTF-02.quietFrom'),
              toKey: GuKey.action('NTF-02.quietTo'),
            ),
        ],
      ),
    );
  }

  /// "Kulüp bazlı ayarlar": aktif üyeliklerin kulüpleri (SHT-07).
  Widget _clubs(NotificationPrefsState state) {
    final gu = context.gu;
    final l10n = context.l10n;
    final clubs = state.clubs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s8,
      children: [
        Text(l10n.notifPrefsPerClub, style: gu.text.fieldLabel),
        GuCard(
          child: clubs.isEmpty
              // `<p class="t-body-s c-muted p16">` (screens-events.js:118).
              ? Padding(
                  padding: GuInsets.all16,
                  child: Text(
                    l10n.notifPrefsNoClubs,
                    style: gu.text.bodyS.copyWith(color: gu.colors.textMuted),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, club) in clubs.indexed) ...[
                      if (i > 0) const GuDivider(),
                      GuTile(
                        key: GuKey.action('NTF-02.club.${club.id}'),
                        padding: GuTilePadding.inCard,
                        leading: GuEmblem(
                          icon:
                              CoverMapper.icon(club.iconName) ??
                              _fallbackClubIcon,
                          size: GuEmblemSize.xs,
                        ),
                        title: club.name,
                        subtitle: state.isClubMuted(club.id)
                            ? l10n.notifPrefsMuted
                            : l10n.notifPrefsCustomize,
                        chevron: true,
                        onTap: () => openClub(club),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _content(NotificationPrefsState state) => SingleChildScrollView(
    padding: GuInsets.only(
      left: GuSpacing.s16,
      right: GuSpacing.s16,
      bottom:
          MediaQuery.paddingOf(context).bottom +
          GuSizes.screenScrollBottomExtra +
          GuSpacing.s24,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s16,
      children: [
        _permissionCard(state),
        _typesCard(state),
        _reminderTime(state),
        _quietCard(state),
        _clubs(state),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(provider);

    // Sıra: hata → yükleniyor → dolu.
    final Widget body;
    if (state.isError) {
      body = Center(
        child: SingleChildScrollView(
          child: GuErrorState(
            title: l10n.sysErrorTitle,
            description: l10n.sysErrorDesc,
            retryLabel: l10n.commonRetry,
            retryActionKey: GuKey.action('NTF-02.retry'),
            onRetry: retry,
          ),
        ),
      );
    } else if (state.isFetching) {
      body = SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: GuInsets.h16,
        child: GuSkeletonList(semanticLabel: l10n.commonLoading),
      );
    } else {
      body = _content(state);
    }

    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      appBar: GuAppBar(
        title: l10n.notifPrefsTitle,
        onBack: goBack,
        backSemanticLabel: l10n.a11yBack,
        backActionKey: GuKey.action('NTF-02.back'),
      ),
      body: body,
    );
  }
}
