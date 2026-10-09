# docs/reference — kullanıcının mevcut ayar dosyaları (karşılaştırma için)

| Dosya | Ne |
|---|---|
| `pubspec.yaml.txt` | Kullanıcının projedeki ilk `pubspec.yaml`'ı (Flutter 3.12.2 SDK; `google_fonts`, `flutter_lints` içerir) |
| `analysis_options.yaml.txt` | İlk `analysis_options.yaml` (`very_good_analysis` + gevşetmeler) |
| `build.yaml.txt` | İlk `build.yaml` (`explicit_to_json: true` gerekçesi: modeller Firestore'a `Map` olarak yazılır) |

`.txt` uzantısı IDE'nin bunları ayrı paket sanmaması içindir. **Bunlar proje dosyası değildir**; proje kökündeki gerçek dosyalar kullanıcıya aittir ve T-00'da `Edit` ile uzlaştırılır (`prompts/02-faz0-kurulum.md` §1–4, `docs/packages.md`). Bu klasöre yazılmaz.
