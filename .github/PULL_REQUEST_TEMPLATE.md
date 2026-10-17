## Ne değişti?

<!-- Kısa özet. İlgili issue varsa: Closes #123 -->

## Neden?

<!-- Sorun ya da ihtiyaç. Kilitli bir karar (D-xx / Q-xx) ya da tasarımdan sapma varsa belirt. -->

## Nasıl test edildi?

- [ ] `bash tool/quality_gate.sh` yeşil (tam kapı)
- [ ] Yeni / değişen ViewModel, State, repository, servis için test yazıldı
- [ ] Arayüz değiştiyse: widget testi + golden (açık / koyu); golden güncellemesi bilinçli
- [ ] Yeni yazma yolu varsa: `firestore.rules` + indeks + Rules testi aynı PR'da

## Ekran görüntüsü

<!-- Arayüz değiştiyse önce / sonra (açık ve koyu tema). -->

## Kontrol listesi

- [ ] Hardcode yok (renk, boşluk, metin, ikon token / ARB'den)
- [ ] Yeni metin TR ve EN ARB'ye eklendi
- [ ] Hard delete yok (soft delete)
- [ ] Üretilen dosyalar (`*.g.dart`, `app_localizations*.dart`) commit edilmedi
- [ ] `docs/` güncellendi (karar, widget kataloğu, token haritası — gerekiyorsa)
- [ ] Commit'ler Conventional Commits + Türkçe açıklama
