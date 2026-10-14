import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/widget/form/form_error_line.dart';
import 'package:gu_ui/gu_ui.dart';

/// AUT-05 · 1. adım "Bir fotoğraf ekle" (`screens-auth.js:143`).
///
/// Başlık + açıklama; altında ortalı sütun (aralık 12, dikey dolgu 16):
/// 120 dp avatar (fotoğraf seçildiyse önizleme, yoksa baş harfler), seçim
/// yapıldıysa "Fotoğraf eklendi" rozeti, "Fotoğraf ekle" (`AUT-05.photo` →
/// SHT-16) ve "Şimdilik atla" (`AUT-05.skipPhoto`). Seçilen görsel
/// işlenemezse altında [errorText] satırı çizilir.
class SetupProfilePhotoStep extends StatelessWidget {
  /// Fotoğraf adımı.
  const SetupProfilePhotoStep({
    required this.name,
    required this.avatarSeed,
    required this.onAddPhoto,
    required this.onSkip,
    this.photo,
    this.errorText,
    super.key,
  });

  /// Kullanıcının adı (avatar baş harfleri).
  final String name;

  /// Avatar gradyan tohumu.
  final String avatarSeed;

  /// "Fotoğraf ekle" dokunması.
  final VoidCallback onAddPhoto;

  /// "Şimdilik atla" dokunması.
  final VoidCallback onSkip;

  /// Seçilen fotoğraf; `null` → yalnız baş harfler.
  final ImageProvider? photo;

  /// Fotoğraf seçme hatası.
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final error = errorText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s16,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.authSetupPhotoTitle, style: gu.text.titleL),
        ),
        Text(
          l10n.authSetupPhotoDesc,
          style: gu.text.bodyM.copyWith(color: gu.colors.textSecondary),
        ),
        Padding(
          padding: GuInsets.sym(v: GuSpacing.s16),
          child: Column(
            spacing: GuSpacing.s12,
            children: [
              GuAvatar(
                initials: name.initials,
                seed: avatarSeed,
                size: GuSizes.avatarSizes.last,
                image: photo,
              ),
              if (photo != null)
                GuBadge(
                  label: l10n.authSetupPhotoAdded,
                  kind: GuBadgeKind.success,
                  icon: GuIcons.circleCheck,
                ),
              GuButton(
                key: GuKey.action('AUT-05.photo'),
                label: l10n.authSetupAddPhoto,
                variant: GuButtonVariant.tonal,
                icon: GuIcons.camera,
                onPressed: onAddPhoto,
              ),
              GuButton(
                key: GuKey.action('AUT-05.skipPhoto'),
                label: l10n.authSetupSkipPhoto,
                variant: GuButtonVariant.text,
                onPressed: onSkip,
              ),
              if (error != null) FormErrorLine(error),
            ],
          ),
        ),
      ],
    );
  }
}
