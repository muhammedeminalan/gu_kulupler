# GÜ Kulüpler — Assets

Generated 2026-10-08T16:24:30.642Z from the design prototype. All demo data is fictional.

## Contents
- icons/svg, icons/png — 130 Lucide icons (ISC licence), stroke 1.75, 24×24 viewBox
- logo/ — official university logo (gu-logo.png, provided by the client) + LogoPlaceholder SVG/PNG fallback
- illustrations/ — 12 single-tone SVG illustrations
- patterns/, covers/ — CoverArt templates + 14 club covers
- colors/ — tokens.json, tokens.css, app_colors.dart, app_theme.dart
- typography/ — typography.json, text_theme.dart, FONTS.md, fonts/*.woff2
- i18n/ — app_tr.arb, app_en.arb (Flutter gen-l10n compatible; keys camelCased)
- data/ — demo-data.json

## Flutter
1. Copy colors/*.dart and typography/text_theme.dart into lib/theme/.
2. Copy i18n/*.arb into lib/l10n/ and add l10n.yaml (see typography/FONTS.md for fonts).
3. Icons: use lucide_icons_flutter or flutter_svg with icons/svg.

## Licences
Lucide — ISC · Montserrat, Inter — SIL OFL 1.1 · Logo — © Gümüşhane Üniversitesi
