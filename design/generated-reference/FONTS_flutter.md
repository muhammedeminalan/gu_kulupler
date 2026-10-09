# Fonts

- **Montserrat** (400, 500, 600, 700) — headings, numerals, overline. Licence: SIL Open Font License 1.1.
- **Inter** (400, 500, 600) — body, labels. Licence: SIL Open Font License 1.1.
- Subsets: latin + **latin-ext** (required for ğ, ş, İ, ı, ç, ö, ü).

## pubspec.yaml

```yaml
flutter:
  fonts:
    - family: Montserrat
      fonts:
        - asset: assets/fonts/montserrat-400.woff2
        - asset: assets/fonts/montserrat-500.woff2
          weight: 500
        - asset: assets/fonts/montserrat-600.woff2
          weight: 600
        - asset: assets/fonts/montserrat-700.woff2
          weight: 700
    - family: Inter
      fonts:
        - asset: assets/fonts/inter-400.woff2
        - asset: assets/fonts/inter-500.woff2
          weight: 500
        - asset: assets/fonts/inter-600.woff2
          weight: 600
```

Alternatively use the `google_fonts` package: `GoogleFonts.montserrat()`, `GoogleFonts.inter()`.
