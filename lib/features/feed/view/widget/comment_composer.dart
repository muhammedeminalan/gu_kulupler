import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/feed/provider/post_detail_view_model.dart';
import 'package:gu_ui/gu_ui.dart';

/// Yorum yazma satırı — FED-02 alt çubuğu (`screens-clubs.js:177`) ve SHT-09
/// alt bölümü (`sheets.js:47`): çok satırlı metin alanı + "Gönder" düğmesi
/// (`row gap8`, alta hizalı); başında isteğe bağlı [leading] (FED-02:
/// kullanıcının avatarı).
///
/// * Tasarımdan bilinçli sapma (K-93, kullanıcı kararı): alan tasarımdaki
///   4 satırlık (min 88) kutu yerine **tek satırla** başlar, yazdıkça
///   `GuSizes.commentMaxRows` (5) satıra dek büyür, sonra içinde kayar.
///   [leading] ve "Gönder" tek satırlık kutu yüksekliğinde ortalanır ve alta
///   hizalanır (`align-items:flex-end`): tek satırda alanla aynı eksende,
///   alan büyüdükçe kutunun son satırının hizasında kalır. Sayaç görünürken
///   (`Limits.commentCounterFrom` sonrası) alanın altı sayaçtır: avatar ve
///   "Gönder" sayacın hizasına iner (prototipte de `flex-end` aynı).
/// * Satırın tamamı `TextFieldTapRegion`'dır (K-93): "Gönder"e (ya da
///   avatara) dokunmak klavyeyi kapatmaz; satır dışına dokunmak kapatır.
/// * Metin `PostDetailViewModel.commentDraft`'tır: alan en çok
///   `Limits.commentMax` karakter alır (fazlası kesilir), sayaç
///   `Limits.commentCounterFrom` karakterden sonra görünür.
/// * "Gönder" metin boşken ya da gönderim sürerken kapalıdır (dokunma bir şey
///   yapmaz). Yorum yazılınca alan boşalır ve [onSent] çağrılır.
/// * Anahtarları çağıran verir (D-18): [inputKey], [sendKey].
class CommentComposer extends ConsumerStatefulWidget {
  /// [clubId] kulübünün [postId] gönderisine yorum yazma satırı.
  const CommentComposer({
    required this.clubId,
    required this.postId,
    required this.inputKey,
    required this.sendKey,
    this.leading,
    this.onSent,
    super.key,
  });

  /// Kulüp kimliği.
  final String clubId;

  /// Gönderi kimliği.
  final String postId;

  /// Metin alanının anahtarı (`<ID>.commentInput` / `SHT-09.input`).
  final Key inputKey;

  /// "Gönder" düğmesinin anahtarı (`<ID>.sendComment` / `SHT-09.send`).
  final Key sendKey;

  /// Alanın solundaki öğe (FED-02: avatar); `null` → yok.
  final Widget? leading;

  /// Yorum yazıldıktan sonra (FED-02: liste sona kayar).
  final VoidCallback? onSent;

  @override
  ConsumerState<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends ConsumerState<CommentComposer> {
  late final TextEditingController _controller;
  ProviderSubscription<String>? _draftSubscription;

  PostDetailViewModelProvider get _provider => postDetailViewModelProvider(
    clubId: widget.clubId,
    postId: widget.postId,
  );

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(_provider).commentDraft);
    // Alan ViewModel'den de değişir: gönderimden sonra boşalır.
    _draftSubscription = ref.listenManual(
      _provider.select((state) => state.commentDraft),
      (_, draft) => _show(draft),
    );
  }

  @override
  void dispose() {
    _draftSubscription?.close();
    _controller.dispose();
    super.dispose();
  }

  /// Alandaki metni [draft] yapar (imleç sonda).
  void _show(String draft) {
    if (_controller.text == draft) return;
    _controller.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
  }

  void _onChanged(String text) {
    ref.read(_provider.notifier).setCommentDraft(text);
    // Sınırı aşan metin ViewModel'de kesilir; alan kesilmiş metni gösterir.
    _show(ref.read(_provider).commentDraft);
  }

  Future<void> _send() async {
    final sent = await ref.read(_provider.notifier).sendComment();
    if (sent && mounted) widget.onSent?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canSend = ref.watch(
      _provider.select((state) => state.canSendComment),
    );
    // Tek satırlık kutu yüksekliğinde ortalı: alan büyüdükçe son satırda
    // (sayaç görünürken sayacın hizasında).
    final lineBoxHeight = GuInput.growingLineBoxHeight(context);
    Widget onLine(Widget child) => SizedBox(
      height: lineBoxHeight,
      child: Center(child: child),
    );
    final leading = widget.leading;
    return TextFieldTapRegion(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: GuSpacing.s8,
        children: [
          if (leading != null) onLine(leading),
          Expanded(
            child: GuInput(
              controller: _controller,
              multiline: true,
              rows: 1,
              maxRows: GuSizes.commentMaxRows,
              maxLength: Limits.commentMax,
              showCounter: true,
              placeholder: l10n.postWriteComment,
              semanticLabel: l10n.postWriteComment,
              onChanged: _onChanged,
              actionKey: widget.inputKey,
            ),
          ),
          onLine(
            GuIconButton(
              key: widget.sendKey,
              icon: GuIcons.send,
              semanticLabel: l10n.commonSend,
              tone: GuIconButtonTone.brand,
              disabled: !canSend,
              onPressed: () => unawaited(_send()),
              onDisabledPressed: () {},
            ),
          ),
        ],
      ),
    );
  }
}
