import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/widget/notification/notification_visuals.dart';
import 'package:gu_ui/gu_ui.dart';

/// [NotificationRow] uzun basma menüsünün anahtarları — çağıran verir
/// (`GuKey.action('NTF-01.menu.<id>.read')` değişmezi çağrı yerinde, D-18).
final class NotificationRowMenuKeys {
  /// Menü anahtarları.
  const NotificationRowMenuKeys({
    required this.scrim,
    required this.read,
    required this.delete,
    required this.mute,
  });

  /// Saydam scrim (`<ID>.scrim`).
  final Key scrim;

  /// "Okundu yap" (`<ID>.menu.<id>.read`).
  final Key read;

  /// "Sil" (`<ID>.menu.<id>.delete`).
  final Key delete;

  /// "Bu türü kapat" (`<ID>.menu.<id>.mute`).
  final Key mute;
}

/// NTF-01 bildirim satırı — prototip `NotificationRow` (`cards.js:139–160`;
/// `.notif-row .notif-under .notif-front .notif-icon .ni-* .tile .dot`).
///
/// * Ön yüz: tür ikonu (`NotificationVisuals`, `ni-*` zemin, 40) · başlık
///   (bodyM; okunmamışsa kalın) / gövde (bodyS `text.secondary`, en çok 2
///   satır) / zaman (caption), aralık 2 · okunmamışsa 8 dp nokta (üst 8).
///   `GuTile(alignStart, padding: notification)`. Dokunma [onOpen].
/// * Kaydırma (±140, eşik 90 — `cards.js:145–146`): sağa → "Okundu yap"
///   ([onToggleRead]; `stateInfo` etiket), sola → "Sil" ([onDelete];
///   `stateDanger` etiket). Bırakınca ön yüz `GuMotion.base` ile yerine
///   döner. Okunmuş satırda sağa kaydırma etkisizdir (okunmadıya döndürme
///   yolu yok — `NotificationRepository.markRead`).
/// * Uzun basma (`GuMotion.longPress`) [menuKeys] verildiyse satır içi
///   `GuPopMenu` açar: "Okundu yap" (okunmamışsa), "Sil", "Bu türü kapat"
///   ([onMute] verildiyse).
/// * Metin çağırandan gelir ([title], [body], [timeLabel]): bildirim metni
///   istemcide ARB'den üretilir (T-25 şeması — belgede metin yok).
/// * Anahtarlar çağırandan: [openKey] (`NTF-01.item.<id>`), [swipeKey]
///   (`NTF-01.swipe.<id>`), [menuKeys].
///
/// Durumlar: okunmuş / okunmamış; kaydırma sol / sağ (K-25 koyu kaydırma
/// etiketi kontrastı). Erişilebilirlik: kaydırma eylemleri özel semantik
/// eylem olarak da sunulur.
class NotificationRow extends ConsumerStatefulWidget {
  /// [notification] satırı.
  const NotificationRow({
    required this.notification,
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.onOpen,
    required this.onToggleRead,
    required this.onDelete,
    required this.openKey,
    required this.swipeKey,
    this.onMute,
    this.menuKeys,
    super.key,
  });

  /// Satırın bildirimi (tür, okundu durumu, kimlik).
  final NotificationModel notification;

  /// Başlık (ARB'den üretilmiş).
  final String title;

  /// Gövde (ARB'den üretilmiş).
  final String body;

  /// Göreli zaman etiketi (`RelativeTimeFormatter`).
  final String timeLabel;

  /// Satıra dokunma (okundu + hedef).
  final VoidCallback onOpen;

  /// Okundu yap (sağa kaydırma, menü); yalnızca okunmamış satırda çağrılır.
  final VoidCallback onToggleRead;

  /// Sil (sola kaydırma, menü) → TST-16.
  final VoidCallback onDelete;

  /// "Bu türü kapat" (menü); `null` → öğe gösterilmez.
  final VoidCallback? onMute;

  /// Ön yüz anahtarı (`NTF-01.item.<id>`).
  final Key openKey;

  /// Kaydırma anahtarı (`NTF-01.swipe.<id>`).
  final Key swipeKey;

  /// Uzun basma menüsünün anahtarları; `null` → menü yok.
  final NotificationRowMenuKeys? menuKeys;

  @override
  ConsumerState<NotificationRow> createState() => _NotificationRowState();
}

class _NotificationRowState extends ConsumerState<NotificationRow> {
  double _dx = 0;
  bool _dragging = false;

  bool get _unread => !widget.notification.read;

  void _onDragStart(DragStartDetails _) => setState(() => _dragging = true);

  void _onDragUpdate(DragUpdateDetails details) {
    final next = (_dx + (details.primaryDelta ?? 0)).clamp(
      -GuSizes.notificationSwipeMax,
      GuSizes.notificationSwipeMax,
    );
    if (next != _dx) setState(() => _dx = next);
  }

  void _onDragEnd([Object? _]) {
    final dx = _dx;
    setState(() {
      _dx = 0;
      _dragging = false;
    });
    if (dx <= -GuSizes.notificationSwipeThreshold) {
      widget.onDelete();
    } else if (dx >= GuSizes.notificationSwipeThreshold && _unread) {
      widget.onToggleRead();
    }
  }

  Future<void> _openMenu() async {
    final keys = widget.menuKeys;
    if (keys == null) return;
    final l10n = context.l10n;
    final onMute = widget.onMute;
    await ref
        .read(feedbackServiceProvider)
        .showMenu<void>(
          scrimKey: keys.scrim,
          items: [
            if (_unread)
              GuPopMenuItem(
                key: keys.read,
                label: l10n.notifMarkRead,
                icon: GuIcons.check,
                onTap: widget.onToggleRead,
              ),
            GuPopMenuItem(
              key: keys.delete,
              label: l10n.commonDelete,
              icon: GuIcons.trash2,
              danger: true,
              onTap: widget.onDelete,
            ),
            if (onMute != null)
              GuPopMenuItem(
                key: keys.mute,
                label: l10n.notifMuteType,
                icon: GuIcons.bellOff,
                onTap: onMute,
              ),
          ],
        );
  }

  Widget _swipeLabel({
    required Color color,
    required String label,
    required GuIcons icon,
    required bool visible,
    required bool iconFirst,
  }) {
    final text = Text(
      label,
      style: context.gu.text.swipeAction.copyWith(color: color),
      // K-57: kaydırma etiketi ölçeklenmez.
      textScaler: TextScaler.noScaling,
    );
    final glyph = GuIcon(icon, size: GuSizes.icon18, color: color);
    return Visibility(
      visible: visible,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: GuSpacing.s6,
          children: iconFirst ? [glyph, text] : [text, glyph],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final colors = gu.colors;
    final text = gu.text;
    final l10n = context.l10n;
    final (icon, tone) = NotificationVisuals.of(widget.notification.type);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final tile = GuTile(
      key: widget.openKey,
      title: widget.title,
      titleWidget: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: GuSpacing.s2,
        children: [
          Text(
            widget.title,
            style: _unread
                ? TextStyle(fontWeight: text.labelL.fontWeight)
                : null,
          ),
          Text(
            widget.body,
            style: text.bodyS.copyWith(color: colors.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(widget.timeLabel, style: text.caption),
        ],
      ),
      leading: GuIconBox(icon: icon, tone: tone),
      trailing: _unread
          ? Padding(
              padding: GuInsets.only(top: GuSpacing.s8),
              child: Semantics(
                label: l10n.notifUnread,
                child: SizedBox.square(
                  dimension: GuSizes.dot,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: colors.brandPrimary,
                      shape: const CircleBorder(),
                    ),
                  ),
                ),
              ),
            )
          : null,
      alignStart: true,
      padding: GuTilePadding.notification,
      onTap: widget.onOpen,
    );

    final front = AnimatedContainer(
      duration: _dragging || reduceMotion ? Duration.zero : GuMotion.base,
      curve: GuMotion.easeStandard,
      transform: Matrix4.translationValues(_dx, 0, 0),
      color: colors.bgCanvas,
      child: tile,
    );

    final gestures = <Type, GestureRecognizerFactory>{
      HorizontalDragGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<HorizontalDragGestureRecognizer>(
            HorizontalDragGestureRecognizer.new,
            (r) => r
              ..onStart = _onDragStart
              ..onUpdate = _onDragUpdate
              ..onEnd = _onDragEnd
              ..onCancel = _onDragEnd,
          ),
      if (widget.menuKeys != null)
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(duration: GuMotion.longPress),
              (r) => r.onLongPress = () => unawaited(_openMenu()),
            ),
    };

    return Semantics(
      customSemanticsActions: {
        if (_unread)
          CustomSemanticsAction(label: l10n.notifMarkRead): widget.onToggleRead,
        CustomSemanticsAction(label: l10n.commonDelete): widget.onDelete,
      },
      child: ColoredBox(
        color: colors.bgCanvas,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: GuInsets.sym(h: GuSpacing.s20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _swipeLabel(
                      color: colors.stateInfo,
                      label: l10n.notifMarkRead,
                      icon: GuIcons.check,
                      visible: _dx > 0 && _unread,
                      iconFirst: true,
                    ),
                    _swipeLabel(
                      color: colors.stateDanger,
                      label: l10n.commonDelete,
                      icon: GuIcons.trash2,
                      visible: _dx < 0,
                      iconFirst: false,
                    ),
                  ],
                ),
              ),
            ),
            RawGestureDetector(
              key: widget.swipeKey,
              gestures: gestures,
              child: front,
            ),
          ],
        ),
      ),
    );
  }
}
