import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/feed/provider/compose_state.dart';
import 'package:gu_kulupler/features/feed/provider/compose_view_model.dart';
import 'package:gu_kulupler/features/feed/view/widget/compose_parts.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_ui/gu_ui.dart';

/// FED-03 anket düzenleyicisi — seçenekler, süre ve sonuç ayarı (prototip
/// `screens-clubs.js:211–213`).
///
/// * **Seçenekler** (`col gap8`): "Seçenekler" etiketi; satır başına metin
///   alanı ("Seçenek {n}", en çok `Limits.pollOptionTextMax` karakter) ve —
///   ikiden çok satır varken — "Kaldır" (`trash-2`); altında hata satırı
///   ("En az 2 seçenek gerekli" / "Seçenekler birbirinden farklı olmalı") ve
///   dört satır dolmadıysa "Seçenek ekle".
/// * **Süre** (`col gap6`): 1 / 3 / 7 gün dilimi.
/// * **"Sonuçlar oy verince görünsün"** anahtarı.
///
/// Düzenlenen ankette (`ComposeState.isPollLocked` — W-71) seçenekler salt
/// okunurdur, ekle / kaldır ve süre çizilmez, anahtar kapalıdır: oylar
/// taşınamadığı için anket yayından sonra değişmez.
///
/// Anahtarlar: `FED-03.option.<i>`, `FED-03.removeOption.<i>`,
/// `FED-03.addOption`, `FED-03.duration.<gün>`, `FED-03.showAfterVote`.
class PollEditor extends ConsumerStatefulWidget {
  /// [clubId] kulübündeki yazı formunun (düzenlemede [editPostId]) anketi.
  const PollEditor({required this.clubId, this.editPostId, super.key});

  /// Kulüp kimliği.
  final String clubId;

  /// Düzenlenen gönderi; yeni gönderide `null`.
  final String? editPostId;

  @override
  ConsumerState<PollEditor> createState() => _PollEditorState();
}

class _PollEditorState extends ConsumerState<PollEditor> {
  final List<TextEditingController> _controllers = [
    for (var index = 0; index < Limits.pollOptionsMax; index++)
      TextEditingController(),
  ];
  ProviderSubscription<List<String>>? _optionsSubscription;

  ComposeViewModelProvider get _provider => composeViewModelProvider(
    clubId: widget.clubId,
    editPostId: widget.editPostId,
  );

  ComposeViewModel get _viewModel => ref.read(_provider.notifier);

  @override
  void initState() {
    super.initState();
    // Seçenekler ViewModel'den de değişir: taslak, "Temizle", satır kaldırma.
    _optionsSubscription = ref.listenManual(
      _provider.select((state) => state.pollOptions),
      (_, options) => _show(options),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _optionsSubscription?.close();
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Alanlardaki metinleri [options] yapar (imleç sonda).
  void _show(List<String> options) {
    for (final (index, controller) in _controllers.indexed) {
      final text = index < options.length ? options[index] : '';
      if (controller.text == text) continue;
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _onChanged(int index, String value) {
    _viewModel.setPollOption(index, value);
    // Sınırı aşan metin ViewModel'de kesilir; alan kesilmiş metni gösterir.
    _show(ref.read(_provider).pollOptions);
  }

  String? _errorText(FormFieldError? error) => switch (error) {
    null => null,
    FormFieldError.invalidFormat => context.l10n.composeErrDupOptions,
    _ => context.l10n.composeErrMinOptions,
  };

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(_provider);
    final locked = state.isPollLocked;
    final error = _errorText(state.errors[ComposeField.options]);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s16,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: GuSpacing.s8,
          children: [
            Text(l10n.composeOptions, style: gu.text.fieldLabel),
            for (var index = 0; index < state.pollOptions.length; index++)
              Row(
                spacing: GuSpacing.s8,
                children: [
                  Expanded(
                    child: GuInput(
                      controller: _controllers[index],
                      placeholder: l10n.composeOptionN(index + 1),
                      semanticLabel: l10n.composeOptionN(index + 1),
                      readOnly: locked,
                      onChanged: (value) => _onChanged(index, value),
                      actionKey: GuKey.action('FED-03.option.$index'),
                    ),
                  ),
                  if (state.canRemovePollOption)
                    GuIconButton(
                      key: GuKey.action('FED-03.removeOption.$index'),
                      icon: GuIcons.trash2,
                      semanticLabel: l10n.commonRemove,
                      onPressed: () => _viewModel.removePollOption(index),
                    ),
                ],
              ),
            if (error != null) ComposeErrorLine(error),
            if (state.canAddPollOption)
              GuButton(
                key: GuKey.action('FED-03.addOption'),
                label: l10n.composeAddOption,
                size: GuButtonSize.sm,
                variant: GuButtonVariant.text,
                icon: GuIcons.plus,
                onPressed: _viewModel.addPollOption,
              ),
          ],
        ),
        if (!locked)
          GuField(
            label: l10n.composeDuration,
            child: GuSegmented(
              options: [
                for (final duration in PollDuration.values)
                  GuSegmentOption(
                    id: duration.name,
                    label: l10n.timeDays(duration.days),
                  ),
              ],
              value: state.pollDuration.name,
              onChanged: (id) => _viewModel.setPollDuration(
                PollDuration.values.byName(id),
              ),
              optionKeyBuilder: (index) => GuKey.action(
                'FED-03.duration.${PollDuration.values[index].days}',
              ),
            ),
          ),
        ComposeSwitchRow(
          label: l10n.composeShowAfterVote,
          value: state.showResultsAfterVote,
          disabled: locked,
          switchKey: GuKey.action('FED-03.showAfterVote'),
          onChanged: (value) => _viewModel.setShowResults(value: value),
        ),
      ],
    );
  }
}
