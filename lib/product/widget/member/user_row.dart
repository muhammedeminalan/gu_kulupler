import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_ui/gu_ui.dart';

/// Kişi satırı — prototip `UserRow` (`ui.js:129–132`): avatar + ad (+ rozet)
/// + alt satır + sondaki öğe. `GuTile(leading: GuAvatar)` sarmalayıcısıdır
/// (CD-27); CLB-03, SET-02, ADM-03, MGT-09, SHT-25 / SHT-26 kullanır.
///
/// * [UserRow.new] alan modelini alır: [user] `null` ise ad "Silinmiş
///   kullanıcı"dır (`common.deletedUser`), avatar `?` gösterir
///   (`art.js:44`).
/// * [UserRow.named] kullanıcı belgesi olmadan çizer (üyelik belgesindeki
///   `applicant` anlık görüntüsü, hesaba bağlı olmayan danışman).
/// * Başlık satırı: ad `bodyM` `text.heading`, tek satır + üç nokta; [badge]
///   adın yanında durur (aralık 6) ve esnemez — ad uzunsa ad kesilir (K-29).
///   Ada satırın yarısı bile kalmıyorsa rozet alt satıra iner (`row gap6
///   wrap`); rozet tek başına satırdan genişse kendi metnini keser.
/// * Satır kabuğu `GuTile`'dır (en az 56, dolgu 8 / 16; [inCard] 10 / 16,
///   aralık 12, basılıyken `bg.surfaceMuted`); [onTap] yoksa düz satırdır.
/// * Anahtarı çağıran verir (D-18, CD-86): [actionKey] satırın kendisidir
///   (`<ID>.<aksiyon>.<userId>`).
/// * Erişilebilirlik: dokunulabilir satır ad + rozet + alt satırla okunan
///   tek düğmedir; avatar okunmaz.
/// * Prototipteki sabit `max-width:200px` yazılmaz (K-29).
///
/// ```dart
/// UserRow(
///   user: user,
///   sub: departmentAndYear,
///   chevron: true,
///   actionKey: GuKey.action('SHT-25.select.${user.uid}'),
///   onTap: () => select(user.uid),
/// )
/// ```
class UserRow extends StatelessWidget {
  /// [user] kullanıcısının satırı; `null` → "Silinmiş kullanıcı".
  const UserRow({
    required this.user,
    this.sub,
    this.trailing,
    this.badge,
    this.size = GuSizes.avatar,
    this.inCard = false,
    this.chevron = false,
    this.onTap,
    this.actionKey,
    this.sub2,
    super.key,
  }) : _name = null,
       _avatarSeed = null;

  /// Kullanıcı belgesi olmadan, [name] ve [avatarSeed] ile çizilen satır.
  const UserRow.named({
    required String this._name,
    required String this._avatarSeed,
    this.sub,
    this.trailing,
    this.badge,
    this.size = GuSizes.avatar,
    this.inCard = false,
    this.chevron = false,
    this.onTap,
    this.actionKey,
    this.sub2,
    super.key,
  }) : user = null;

  /// Kullanıcı; `null` → silinmiş kullanıcı ([UserRow.named] hariç).
  final UserModel? user;

  final String? _name;
  final String? _avatarSeed;

  /// Alt satır (bölüm · sınıf, rol adı); boşsa çizilmez.
  final String? sub;

  /// Satır sonundaki öğe (düğme, menü).
  final Widget? trailing;

  /// Adın yanındaki rozet (`GuRoleBadge`).
  final Widget? badge;

  /// Avatar çapı (varsayılan 40).
  final double size;

  /// Kart içi satır (`.tile.in-card`).
  final bool inCard;

  /// Sonda `chevron-right`.
  final bool chevron;

  /// Satıra dokunma; `null` → düz satır.
  final VoidCallback? onTap;

  /// Satırın aksiyon anahtarı (`GuKey.action`); çağıran verir.
  final Key? actionKey;

  /// Alt satırın altındaki üçüncü satır (`Tile.sub2`; `caption`) — `MemberRow`
  /// katılım oranı çubuğu.
  final Widget? sub2;

  /// Silinmiş kullanıcının avatar metni ve renk tohumu (`art.js:44`).
  static const String _unknown = '?';

  /// Görünen ad; kullanıcı yoksa `null` (→ "Silinmiş kullanıcı").
  String? get name => user?.name ?? _name;

  /// Avatar renk tohumu: `avatarSeed`, boşsa kullanıcı kimliği
  /// (`art.js:44`); kullanıcı yoksa `?`.
  String get avatarSeed {
    final user = this.user;
    if (user == null) return _avatarSeed ?? _unknown;
    return user.avatarSeed.isEmpty ? user.uid : user.avatarSeed;
  }

  @override
  Widget build(BuildContext context) {
    final name = this.name;
    final shownName = name ?? context.l10n.commonDeletedUser;
    final badge = this.badge;
    // Stil `GuTile`'ın başlık stilinden gelir (`DefaultTextStyle`).
    final nameText = Text(
      shownName,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );
    return GuTile(
      key: actionKey,
      title: shownName,
      titleWidget: badge == null
          ? nameText
          : _NameBadgeLine(name: nameText, badge: badge),
      subtitle: (sub?.isEmpty ?? true) ? null : sub,
      sub2Widget: sub2,
      leading: GuAvatar(
        initials: (name ?? _unknown).initials,
        seed: avatarSeed,
        size: size,
      ),
      trailing: trailing,
      chevron: chevron,
      padding: inCard ? GuTilePadding.inCard : GuTilePadding.normal,
      onTap: onTap,
    );
  }
}

/// Ad + rozet satırı (`row gap6 wrap`; K-29). Önce rozet ölçülür; ad kalan
/// genişliğe sığar ya da kesilir. Ada satırın yarısı bile
/// kalmıyorsa (ve ad kesilecekse) rozet alt satıra iner, ad tam genişliği
/// alır.
class _NameBadgeLine extends MultiChildRenderObjectWidget {
  _NameBadgeLine({required Widget name, required Widget badge})
    : super(children: [name, badge]);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderNameBadgeLine();
}

class _NameBadgeParentData extends ContainerBoxParentData<RenderBox> {}

/// [_NameBadgeLine] yerleşiminin sonucu; `nameConstraints` adın ölçüldüğü
/// kısıttır (kuru taban çizgisi için).
typedef _LineLayout = ({
  Size size,
  Offset name,
  Offset badge,
  BoxConstraints nameConstraints,
});

class _RenderNameBadgeLine extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _NameBadgeParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _NameBadgeParentData> {
  /// Ad ile rozet arası (yatayda ve alt satıra inince dikeyde) — `gap6`.
  static const double _gap = GuSpacing.s6;

  /// Rozet yanında kalırken ada bırakılması gereken en küçük pay.
  static const double _minNameShare = 0.5;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _NameBadgeParentData) {
      child.parentData = _NameBadgeParentData();
    }
  }

  RenderBox get _name => firstChild!;

  RenderBox get _badge => lastChild!;

  _LineLayout _layout(BoxConstraints constraints, ChildLayouter layoutChild) {
    final maxWidth = constraints.maxWidth;
    final badgeSize = layoutChild(_badge, BoxConstraints(maxWidth: maxWidth));
    final inlineMax = math.max<double>(0, maxWidth - badgeSize.width - _gap);
    final natural = _name.getMaxIntrinsicWidth(double.infinity);
    final inline =
        natural <= inlineMax || inlineMax >= maxWidth * _minNameShare;

    if (!inline) {
      final nameConstraints = BoxConstraints(maxWidth: maxWidth);
      final nameSize = layoutChild(_name, nameConstraints);
      return (
        size: constraints.constrain(
          Size(
            math.max(nameSize.width, badgeSize.width),
            nameSize.height + _gap + badgeSize.height,
          ),
        ),
        name: Offset.zero,
        badge: Offset(0, nameSize.height + _gap),
        nameConstraints: nameConstraints,
      );
    }

    final nameConstraints = BoxConstraints(maxWidth: inlineMax);
    final nameSize = layoutChild(_name, nameConstraints);
    final height = math.max(nameSize.height, badgeSize.height);
    return (
      size: constraints.constrain(
        Size(nameSize.width + _gap + badgeSize.width, height),
      ),
      name: Offset(0, (height - nameSize.height) / 2),
      badge: Offset(nameSize.width + _gap, (height - badgeSize.height) / 2),
      nameConstraints: nameConstraints,
    );
  }

  @override
  void performLayout() {
    final layout = _layout(constraints, ChildLayoutHelper.layoutChild);
    size = layout.size;
    (_name.parentData! as _NameBadgeParentData).offset = layout.name;
    (_badge.parentData! as _NameBadgeParentData).offset = layout.badge;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, ChildLayoutHelper.dryLayoutChild).size;

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final layout = _layout(constraints, ChildLayoutHelper.dryLayoutChild);
    final distance = _name.getDryBaseline(layout.nameConstraints, baseline);
    return distance == null ? null : distance + layout.name.dy;
  }

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _name.getMinIntrinsicWidth(height),
    _badge.getMinIntrinsicWidth(height),
  );

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _name.getMaxIntrinsicWidth(height) +
      _gap +
      _badge.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      computeDryLayout(BoxConstraints(maxWidth: width)).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeDryLayout(BoxConstraints(maxWidth: width)).height;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
