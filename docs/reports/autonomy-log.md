# Otonom çalışma günlüğü (Claude Code)

> Kullanıcı uyurken/izlemezken Claude'un kendi verdiği kararlar, atladığı adımlar ve dikkat gerektiren notlar. Final rapor `docs/reports/final-report.md` bu dosyadan derlenir. Resmî karar kaydı `docs/decisions.md` K-tablosundadır; burası kronolojik günlük.

| Tarih | Bağlam | Karar / olay | Gerekçe | Etki |
|---|---|---|---|---|
| 2026-10-08 | Faz 0 | `docs/PLAN.md` onayı kullanıcı adına verildi (ExitPlanMode açılmadı) | Kullanıcı "yatıyorum, karar gerektiren yerde kendin ver" dedi; onay beklemek geceyi boşa geçirirdi | Plan 6 bağımsız denetçiden geçirildi; `node tool/progress.js gate plan` Claude tarafından çalıştırıldı |
| 2026-10-08 | Faz 0 | PLAN taslağının 97 açık noktası CD-01…CD-74 olarak karara bağlandı (docs/decisions.md "Claude'un kendi verdiği kararlar") | Kullanıcı gece talimatı; hepsi akışı bozmayan, docs önerileriyle uyumlu seçenekler | PLAN §22 + ilgili bölümler; K-H/K-I/K-J/T-42/CI soruları artık sorulmayacak |
| 2026-10-08 | Faz 0 | Faz 0 çıktıları + pack dosyaları main'e tek commit (CD-73) | T-00 "git status temiz" ön koşulu | push yok |
| 2026-10-09 | Faz 0 | Kullanıcı talimatı: koda geçilmeyecek; plan bitince durulacak, sabah "devam" ile T-00 | Kullanıcı sabah bakmak istiyor | gate plan + Faz 0 commit + T-00 ertelendi |
| 2026-10-09 | Faz 0 | PLAN.md kesinleşti (3 tur, 444 bulgu); sabah özeti docs/reports/morning-brief.md; gate plan/commit/T-00 "devam" bekliyor | Kullanıcı talimatı | — |
| 2026-10-09 | T-00 | Kök pubspec'te `resolution: workspace` kaldırıldı (pub kuralı; 02-faz0 §2.1 yanlış) | `flutter pub get` reddetti | PLAN/prompt metni değişmedi, T-00 planı §12 notu |
| 2026-10-09 | T-00 | K-28: ARB çoğullarında `#` gen-l10n tarafından değiştirilmiyor → `{değişken}`e çevrildi, ARB15 kuralı eklendi | Test kanıtı (`# yorum`) | design-known-issues K-28 |
| 2026-10-09 | T-00 | İnceleme: l10n extension dosyası ignore deseninden çıkarıldı (build_context_l10n_x.dart); settings.json ask listesinden git merge ve decisions.md kaldırıldı (CD-03); firebase_storage_mocks kökten çıktı; testler sıkılaştırıldı | Mimari + test denetçisi bulguları | CD-79 (tool self-test T-02) |
| 2026-10-09 | T-00 | KVKK iletişim e-postası ARB literalinde (`legalKvkkB7` kvkk@gumushane.edu.tr) — D-01 kapsamı dışı, dokunulmadı | İnceleme notu | Final rapor "değiştirilecek değerler" listesine (CD-68) |
