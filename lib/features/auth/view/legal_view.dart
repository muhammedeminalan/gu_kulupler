import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/auth/view/mixin/legal_view_mixin.dart';
import 'package:gu_kulupler/features/auth/view/widget/legal_document.dart';
import 'package:gu_kulupler/product/navigation/legal_tab.dart';
import 'package:gu_ui/gu_ui.dart';

/// Yasal metinler ekranı — prototip `Legal` (`screens-auth.js:152–160`),
/// `LegalRoute` (`/legal/:tip`; guard'sız, `push` ile açılır).
///
/// * Çubuk: geri + "Yasal metinler".
/// * Sekmeler: KVKK · Gizlilik · Koşullar ([LegalTab] sırası); ilk sekme
///   [tip].
/// * Bölüm çipleri (yatay şerit): 7 numaralı başlık; dokununca metin o
///   bölüme kayar.
/// * Metin (dolgu 0 / 16 / 16, aralık 16): `titleL` başlık, güncelleme
///   satırı, 7 bölüm. Alt boşluk gerçek güvenli alan + 8 (K-07).
/// * [showAccept] `true` ise altta "Okudum, anladım" çubuğu (prototip
///   `from === 'register'`; `LegalRoute(from: LegalOrigin.register)`): kayıt
///   formundaki onay kutusunu işaretler ve açan ekrana döner.
///
/// Ekran veri okumaz: yükleniyor / boş / hata / çevrimdışı durumu yoktur;
/// metinler ARB'dedir ([LegalDocument]).
///
/// Design: AUT-06
class LegalView extends ConsumerStatefulWidget {
  /// [tip] ilk açılan sekmedir.
  const LegalView({required this.tip, this.showAccept = false, super.key});

  /// İlk açılan sekme (yol parametresi).
  final LegalTab tip;

  /// Altta onay çubuğu gösterilsin mi (kayıt formundan açılış).
  final bool showAccept;

  @override
  ConsumerState<LegalView> createState() => _LegalViewState();
}

class _LegalViewState extends ConsumerState<LegalView> with LegalViewMixin {
  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final document = LegalDocument.of(l10n, tab);
    // Onay çubuğu alt güvenli alanı kendisi kaplar.
    final safeBottom = widget.showAccept
        ? 0.0
        : MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      appBar: GuAppBar(
        title: l10n.legalTitle,
        onBack: onBack,
        backSemanticLabel: l10n.a11yBack,
        backActionKey: GuKey.action('AUT-06.back'),
      ),
      bottomNavigationBar: widget.showAccept
          ? GuStickyCta(
              children: [
                GuButton(
                  key: GuKey.action('AUT-06.accept'),
                  label: l10n.legalAccept,
                  full: true,
                  onPressed: onAccept,
                ),
              ],
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GuTabs(
            tabs: [
              for (final item in LegalTab.values)
                GuTabItem(
                  id: item.name,
                  label: LegalDocument.shortTitleOf(l10n, item),
                ),
            ],
            value: tab.name,
            onChanged: onTabChanged,
            tabKeyBuilder: (index) =>
                GuKey.action('AUT-06.tab.${LegalTab.values[index].name}'),
          ),
          GuHorizontalList(
            children: [
              for (final (index, section) in document.sections.indexed)
                GuChip(
                  key: GuKey.action('AUT-06.jump.${index + 1}'),
                  label: l10n.legalSectionHeading(index + 1, section.heading),
                  onTap: () => onJump(index + 1),
                ),
            ],
          ),
          Expanded(
            // Sekme değişimi kısa solma (kullanıcı kararı 2026-10-16;
            // `GuMotion.tabSwitch`).
            child: GuContentFade(
              value: tab,
              child: SingleChildScrollView(
                // Sekme başına ayrı kaydırma konumu (prototip `routeKey`).
                key: PageStorageKey<String>('legal-${tab.name}'),
                padding: GuInsets.only(
                  left: GuSpacing.s16,
                  right: GuSpacing.s16,
                  bottom:
                      GuSpacing.s16 +
                      safeBottom +
                      GuSizes.screenScrollBottomExtra,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: GuSpacing.s16,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(document.title, style: gu.text.titleL),
                    ),
                    Text(l10n.legalUpdated, style: gu.text.caption),
                    for (final (index, section) in document.sections.indexed)
                      LegalSection(
                        key: sectionKeys[index],
                        heading: l10n.legalSectionHeading(
                          index + 1,
                          section.heading,
                        ),
                        body: section.body,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
