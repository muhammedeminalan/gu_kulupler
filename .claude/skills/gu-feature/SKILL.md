---
name: gu-feature
description: Bir feature dilimini (model → servis → repository → ViewModel → State → view) projenin katman, isimlendirme ve DI kurallarıyla kurar. Yeni feature klasörü, ViewModel/State, repository veya servis eklerken kullan.
---

# gu-feature — feature dilimi

Kurallar `CLAUDE.md §1–§4`'te; burası uygulama sırası ve dosya şablonlarıdır.

## Dizin

```
lib/features/<feature>/
  provider/  <x>_view_model.dart  <x>_state.dart        # (+ .g.dart üretilir, commit edilmez)
  view/      <x>_view.dart
             mixin/  <x>_view_mixin.dart                # ekran mantığı (form, sayfalama, odak…)
             widget/ <x>_section.dart …                 # yalnızca bu feature'a özgü parçalar
packages/gu_data/lib/src/{models,services,repositories}/
test/features/<feature>/…  packages/gu_data/test/…
```

Feature'lar birbirini import etmez; ortaklar `lib/product/` veya paketlerdedir.

## Sıra

1. **Model** (gerekirse): `gu_data/src/models/x_model.dart` — `Equatable`, `json_serializable(explicit_to_json: true)`, `BaseFields`, elle `copyWith`; test: JSON gidiş-dönüş.
2. **Servis / repository arayüzü** (`gu_data`): `FirebaseResult` döner; metot adı alan dilinde (`applyToClub`, `approveApplication`); **`delete*` yok**. Sayaç değişen metot batch/transaction'da sayacı da günceller.
3. **Rules + indeks + Rules testi** (yeni yazma/okuma yolu varsa) — aynı commit (`gu-firebase-model`).
4. **Fake**: `test/fakes/fake_x_repository.dart` (gerçek arayüzü uygular, bellekte). Mock kütüphanesi yok.
5. **State**: `final class XState extends Equatable`; tüm alanlar `props` ve `copyWith`'te; varsayılanlar `const`.
6. **ViewModel**: `@riverpod final class XViewModel extends _$XViewModel with ProjectDependencyMixin`; mutasyon yalnızca `state = state.copyWith(...)`; istisna yutulmaz → `isError`; optimistik işlemde geri alma + toast.
7. **View**: `ConsumerStatefulWidget`/`ConsumerWidget`; sınıf üstünde `/// Design: <ID>`; koşullu render **hata → yükleniyor → boş → dolu**; çevrimdışı banner kökte.
8. **DI kaydı**: `lib/core/di/project_dependency*.dart` (servis/repository); view'da `GetIt.I` yok.
9. **Rota**: `gu-navigation`.
10. **Testler**: State, ViewModel (`ProviderContainer`), repository/servis, view (`gu-testing`).

## Hızlı kontrol

- ViewModel Firestore SDK tiplerini (`DocumentSnapshot`, `Timestamp`) görmüyor.
- Eşzamanlı çağrılar (art arda dokunma) için `isFetching` koruması var.
- Sayfalama imleç tabanlı (`limit(20)` + `startAfterDocument`); canlı dinleyici yalnızca `architecture.md §13` listesindeki yerlerde.
- Zaman `AppClock`'tan, rastgelelik enjekte edilen üreticiden.
- Hata → `FirebaseFailure` → `isError`; kullanıcı mesajı `architecture.md §8` eşlemesiyle.
