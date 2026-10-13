import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/features/clubs/provider/club_list_view_model.dart';

/// CLB-01 listesindeki bir kulüp kartının yuvası: kart ekrana geldiğinde
/// kulübün yönetici önizlemesini ister (`ClubListViewModel.loadPreview`,
/// CD-139).
///
/// Liste tembel kurulduğu için yalnızca görünen (ve önbellek alanındaki)
/// kartlar okuma yapar; ViewModel kulüp başına tek okuma yapar. Izgara
/// kartında avatar grubu yoktur: [loadPreview] `false` iken okuma istenmez
/// (liste görünümüne dönünce istenir).
class ClubListItem extends ConsumerStatefulWidget {
  /// [clubId] kulübünün kartı ([child]).
  const ClubListItem({
    required this.clubId,
    required this.loadPreview,
    required this.child,
    super.key,
  });

  /// Kulüp kimliği.
  final String clubId;

  /// Yönetici önizlemesi istensin mi (liste görünümü).
  final bool loadPreview;

  /// Kulüp kartı.
  final Widget child;

  @override
  ConsumerState<ClubListItem> createState() => _ClubListItemState();
}

class _ClubListItemState extends ConsumerState<ClubListItem> {
  @override
  void initState() {
    super.initState();
    _request();
  }

  @override
  void didUpdateWidget(ClubListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clubId != oldWidget.clubId ||
        (widget.loadPreview && !oldWidget.loadPreview)) {
      _request();
    }
  }

  /// Yapım bittikten sonra ister (yapım sırasında sağlayıcı değiştirilmez);
  /// yeni kare beklenmez.
  void _request() {
    if (!widget.loadPreview) return;
    unawaited(
      Future<void>.microtask(() async {
        if (!mounted) return;
        await ref
            .read(clubListViewModelProvider.notifier)
            .loadPreview(widget.clubId);
      }),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
