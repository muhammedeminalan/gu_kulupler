import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_ui/gu_ui.dart';

// TODO(T-20): FED-01 gönderi akışı — bu dosya nihai yoldaki geçici iskelettir
// (PLAN §13.3.2 `ClubFeedTab`; W-10): süzgeç çipleri, gönderi kartları, yazı
// oluşturma girişi, tasarım izi ve aksiyon anahtarları T-20'de yazılır.

/// CLB-03 "Gönderiler" sekmesinin gövdesi (kulübün içini görenler). Geçici
/// iskelet: yalnızca boş durumu çizer ("Henüz gönderi yok"); tasarım kimliği
/// izi ve aksiyon anahtarı taşımaz.
class ClubFeedTab extends StatelessWidget {
  /// [clubId] kulübünün gönderi akışı.
  const ClubFeedTab({required this.clubId, super.key});

  /// Kulüp kimliği (`ClubFeedViewModel` ailesi — T-20).
  final String clubId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GuEmptyState(
      illustration: GuIllustrations.emptyPosts,
      title: l10n.feedEmptyTitle,
      description: l10n.feedEmptyDesc,
    );
  }
}
