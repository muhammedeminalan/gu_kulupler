# CLAUDE.md — GÜ Kulüpler

> Bu dosya projede iş yapan herkes (ve Claude) için **tek doğru kaynaktır**. `.claude/skills/*` ve `.claude/agents/*` bu dosyaya referans verir, kuralları tekrar etmez.
> Çelişki çözümü ve kilitli kararlar: [`docs/decisions.md`](docs/decisions.md). Okuma haritası: [`docs/README.md`](docs/README.md).

**Proje:** Gümüşhane Üniversitesi öğrenci kulüpleri için yönetim + sosyal mobil uygulama ("GÜ Kulüpler"). Flutter + Firebase, TR (varsayılan) + EN. Girişimcilik dersi projesi.
**Durum:** Tasarım **bitti** (Claude Design dışa aktarımı `design/` altında, salt okunur). Bu repo tasarımı **1:1** Flutter'a çevirir.

---

## 0. ÇALIŞMA PROTOKOLÜ (her oturumun başında oku)

Sen bir geliştirici değil, **kapılarla ilerleyen bir yürütücüsün**. Kullanıcı büyük planın sahibidir.

1. **İlk oturum:** `prompts/00-baslat.md`'yi uygula (keşif → soru turu → `docs/PLAN.md` → **DUR**).
2. **Kapı 0:** `docs/PLAN.md` onaylanmadan **tek satır uygulama kodu yazma.**
3. **Sıra:** Plan onayı → **T-00** (depo kurulumu, `prompts/02-faz0-kurulum.md`) → **Faz 1 tasarım analizi** (`prompts/03-faz1-tasarim-analizi.md`) → `docs/design-analysis.md` onayı → **T-01…T-47**. **Kapı 1:** analiz onaylanmadan T-01 ve hiçbir ekran/view/widget yazılmaz.
4. **Task döngüsü:** `docs/roadmap.md`'deki task'lar **sırayla, birer birer**; her biri `prompts/task-calistir.md` sırasıyla: **plan modu → onay → uygulama → test → `tool/quality_gate.sh` → inceleme ajanları → commit.** Durum `node tool/progress.js` ile `docs/progress.json`'da tutulur. Task'ı atlama, birleştirme, yeniden sıralama.
5. **Belirsizlik = soru.** Tahmin etme, "makul varsayım" yapma. Seçenekli sorular **`AskUserQuestion` açılır penceresiyle** sorulur (kurallar: `.claude/skills/gu-ask-user/SKILL.md`). Düz metinle soru sorma.
6. **Sapma yok.** Kilitli karar (D-xx), cevaplanmış soru (Q-xx), `docs/*` sözleşmeleri ve tasarım değişmez. Değiştirmek istiyorsan **önce sor**.
7. **Kullanıcıya her zaman Türkçe** yaz. Kısa ol: ne yaptın, sonuç, bir sonraki adım.

---

## 1. Mimari

**Feature-first + paylaşılan `product/` katmanı + iki yerel paket.** Ayrıntı: [`docs/architecture.md`](docs/architecture.md).

```
repo/
├── pubspec.yaml                 # uygulama + workspace: [packages/gu_data, packages/gu_ui]
├── packages/
│   ├── gu_data/                 # modeller, enum'lar, FirebaseResult, servisler, repository'ler, soft delete
│   └── gu_ui/                   # token, tema, tipografi, GuIcon, çekirdek widget'lar, overlay çerçeveleri, extension'lar
├── lib/
│   ├── main.dart
│   ├── core/                    # bootstrap, DI (project_dependency*.dart), env, hata/log
│   ├── product/                 # navigation, feedback katalogları (SHT/DLG/TST), alan-bilen ortak widget'lar, mixin'ler
│   ├── features/<feature>/      # provider/ (veya view_model/) + view/ (mixin/, widget/)
│   └── l10n/                    # app_tr.arb, app_en.arb (+ üretilen)
├── firebase/                    # firestore.rules, indexes, storage.rules, test/ (rules testleri)
├── functions/                   # yalnızca Q-02 = Functions ise
├── assets/ fonts icons illustrations covers patterns logo
├── test/  integration_test/
├── tool/  docs/  prompts/  design/(salt okunur)  reference/(salt okunur)
```

**Katman kuralı (tek yön):** `view → viewmodel → repository (arayüz: gu_data) → service → Firebase SDK`.
- `gu_ui` Firebase'e ve `gu_data`'ya **bağımlı değildir** (saf arayüz). Alan modeli isteyen widget'lar uygulamanın `lib/product/widget/` altında yaşar.
- `gu_data` Flutter widget'ı içermez. ViewModel Firestore SDK tiplerini görmez (`DocumentSnapshot`, `Timestamp` vb. repository sınırında kalır).
- Feature'lar birbirinin içine import etmez; ortak olan `product/` veya paketlere çıkar.

İsimlendirme: `*_view_model.dart`, `*_state.dart`, `*_view.dart`, `*_mixin.dart`, `*_model.dart`, `*_repository.dart`, `*_service.dart`. Sınıflar `XViewModel`, `XState`, `XView`, `XModel`.

---

## 2. State — Riverpod `@riverpod` Notifier (Freezed YOK, AsyncValue YOK)

```dart
part 'club_list_view_model.g.dart';

@riverpod
final class ClubListViewModel extends _$ClubListViewModel with ProjectDependencyMixin {
  @override
  ClubListState build() => const ClubListState();

  Future<void> fetch() async {
    state = state.copyWith(isFetching: true, isError: false);
    final result = await clubRepository.fetchActiveClubs();
    state = switch (result) {
      FirebaseSuccess(:final data) => state.copyWith(clubs: data, isFetching: false),
      FirebaseFailure() => state.copyWith(isFetching: false, isError: true),
    };
  }
}

final class ClubListState extends Equatable {
  const ClubListState({this.clubs = const [], this.isFetching = false, this.isError = false});
  final List<ClubModel> clubs;
  final bool isFetching;
  final bool isError;
  @override
  List<Object?> get props => [clubs, isFetching, isError];
  ClubListState copyWith({List<ClubModel>? clubs, bool? isFetching, bool? isError}) =>
      ClubListState(clubs: clubs ?? this.clubs, isFetching: isFetching ?? this.isFetching, isError: isError ?? this.isError);
}
```

- Mutasyon **daima** `state = state.copyWith(...)`. Doğrudan alan ataması yok.
- İstisnayı yutma; `isError` bayrağına çevir. `props` ve `copyWith` **tüm alanları** içerir (eksik alan = hata).
- Optimistik güncellemeler (beğeni, kaydet, onayla…) önce state'i günceller, hata gelirse geri alır ve toast gösterir.
- Her ViewModel ve State için test zorunlu.

---

## 3. DI — GetIt + Riverpod

- Servisler/repository'ler GetIt'te: `lib/core/di/project_dependency.dart`; ViewModel içinde `ProjectDependencyMixin` (`clubRepository`, `authService`, `feedback`, …).
- **View/widget dosyasında `GetIt.I` çağrısı yasak.** Widget'ta global state için `AppProviderMixin<T>` / `AppProviderStateMixin`.
- Testte GetIt sıfırlanır, **el yazımı fake**'ler kaydedilir (`test/fakes/`).

## 4. View

- `ConsumerStatefulWidget` / `ConsumerWidget` (asla düz `StatefulWidget`). İş mantığı ViewModel veya view mixin'inde; view şişirilmez.
- Koşullu render sırası: **hata → yükleniyor (skeleton) → boş → dolu**; çevrimdışı banner üstte kalıcı.
- Her ekran sınıfının üstünde `/// Design: <ID>`; her etkileşimli öğe `key: GuKey.action('<ID>.<aksiyon>')` (D-18, D-19).
- Tüm 5 durum (normal, yükleniyor, boş, hata, çevrimdışı) tasarımda varsa **hepsi** uygulanır ve test edilir.

---

## 5. Routing

- `@TypedGoRoute` + `GoRouteData`; üretilen `app_router.g.dart` commit edilmez. Rota tablosu ve guard'lar: [`docs/navigation.md`](docs/navigation.md) (prototipin gerçek rota haritasıyla uyumlu).
- **Guard'lı rotalara daima `go`.** `push` yalnızca guard'sız geçici sayfa: `LegalRoute` (AUT-06). Sheet/dialog zaten `showModal*`. Alt sekme çubuğu yalnızca sekme kökünde görünür; sekmeler arası bağlantı kuralı Q-20 (`docs/navigation.md §4`).
- Kimlik/rol yönlendirmesi router'da (`AuthGuard`, `redirect`); view'dan `context.go` ile auth kararı **verilmez**.
- Sekme başına bağımsız yığın (`StatefulShellRoute.indexedStack`), aktif sekmeye tekrar dokunma = köke dön / başa kaydır. Sekme yığınları birbirine **karışmaz**; bildirimden derin bağlantı = ilgili sekmenin köküne geri dönen yığın (`openInTab`).
- **Geçişler platform varsayılanı** (D-06). Elle `CustomTransitionPage` yalnızca `docs/navigation.md §5` istisnalarında.
- Zorunlu id'ler path parametresidir (`$extra`'ya model taşıma yok).

## 6. Stil — SERT KURALLAR (`tool/check_hardcode.sh` reddeder)

| Yasak | Yerine |
|---|---|
| `Color(0x…)`, `Colors.red` vb. (tema/token dosyaları hariç) | `context.gu.colors.*` (`GuColors`) |
| `Theme.of(context)` doğrudan | `context.gu.*` extension'ları |
| `EdgeInsets.all(12)`, `SizedBox(height: 8)`, `Padding(... 16)` sayısal | `GuSpacing.*` / `GuGap.*` / `GuInsets.*` |
| `BorderRadius.circular(12)` | `GuRadius.*` |
| `TextStyle(fontSize: …)`, `FontWeight.*` view'da | `context.gu.text.*` (`GuTypography`) |
| `Duration(milliseconds: 200)`, `Curves.*` view'da | `GuMotion.*` |
| `Text('Kulüpler')`, `'…'` UI string | `context.l10n.*` (ARB) |
| `Icon(Icons.*)` | `GuIcon(GuIcons.*)` |
| `print(`, `debugPrint(` (logger dışında) | `AppLogger` |
| `Navigator.push`, view'da `GetIt.I` | go_router / mixin |
| Düz `StatefulWidget` feature view'larında (`gu_ui` saf widget'ları serbest) | `ConsumerStatefulWidget` |
| Genişlik/yükseklik sabitleri (`width: 390`) | `LayoutBuilder`/`Flexible`/token |
| `.delete()` (Firestore/Storage/Auth), `deleteDoc`, `batch.delete` | `softDelete` / `restore` (`docs/soft-delete.md`) |

- Eksik token gerekiyorsa **çağrı yerine değil, token katmanına** eklenir ve `docs/token-map.md` güncellenir.
- Satır içi istisna: `// ignore-hardcode: <gerekçe>` (gerekçe zorunlu; incelemede sorgulanır).
- Dokunma hedefi: `GuTapTarget` (D-22). Kontrast: token testi AA'yı doğrular.
- Responsive: `LayoutBuilder` + `Flexible/Expanded/Wrap/ellipsis`; 320 dp'de sağ taşma sıfır; sabit `SizedBox(width:)` ile genişlik zorlamak yok. Klavye açıkken içerik kayar (`resizeToAvoidBottomInset` + scroll).
- Durum çubuğu: `GuSystemUi` (D-20). Güvenli alanlar: `SafeArea`/`MediaQuery.viewPadding`; tasarımdaki `--safe-top:54px` mock'tur, **gerçek inset kullanılır**.

## 7. Widget'lar

- Önce `docs/widget-catalog.md`'ye bak (Faz 1'de üretilir). Yoksa `gu_ui`'a (alan-bağımsız) veya `lib/product/widget/`'a (alan-bilen) ekle, **kataloğu aynı commit'te güncelle**.
- Her widget: tasarımdaki **tüm durumlar** (default/pressed/focus/disabled/loading/selected/error), `Semantics` etiketi, test + golden.
- Bottom sheet / dialog / toast **tek yardımcı sınıf** üzerinden (`FeedbackService`): `showSheet(SheetId.sht05, …)`, `showDialog(DialogId.dlg07, …)`, `showToast(ToastId.tst27, …)`. Katalog: `lib/product/feedback/`. Aynı anda en çok **1 toast**; Geri al'lı toast 6 sn, diğerleri 4 sn; alt çubuğun üstünde.

## 8. Yerelleştirme

- `context.l10n.<anahtar>`. Anahtarlar tasarımdan camelCase'e çevrilmiş (`a11y.back → a11yBack`); orijinal anahtar ARB `@key.description`'dadır. TR ve EN anahtar kümesi **eşit** olmalı (`tool/check_arb_parity.js`).
- Çoğul ve parametre ICU ile (`{count, plural, …}`); string birleştirme yok. Tarih/saat/sayı `intl` ile, yerel ayara göre.
- Yeni metin: önce ARB'ye (TR + EN), sonra kullanım.

## 9. Veri (Firebase)

- Servis erişimi yalnızca `gu_data` içinden; sonuç tipi `FirebaseResult` (D-34). Yeni yazma yolu açan her değişiklik **aynı commit'te** `firebase/firestore.rules` + `firestore.indexes.json` + rules testi + (gerekirse) seed güncellemesi içerir. Aksi halde üretimde `permission-denied`.
- **Soft delete (D-10):** silinen = `isDeleted:true, deletedAt, deletedBy, updatedAt`. Okuma sorguları `isDeleted == false` süzer. Sayaçlar (`memberCount`, `goingCount`, `likeCount`…) aynı batch/transaction'da güncellenir. Ayrıntı: [`docs/soft-delete.md`](docs/soft-delete.md).
- Yetki **arayüzde gizlemekle** sağlanmaz; Rules'ta uygulanır. Rol/yetki matrisi ve üyelik durum makinesi: [`docs/domain-model.md`](docs/domain-model.md), [`docs/firestore-rules-spec.md`](docs/firestore-rules-spec.md).
- Emülatör: `AppEnvironment` (`--dart-define=ENV=emulator`), host'lar Android `10.0.2.2`, iOS/masaüstü `localhost`. Gerçek projeye yazan komut/seed **kullanıcı onayı olmadan çalıştırılmaz** (`firebase deploy` dahil).

## 10. Test (kısa; ayrıntı [`docs/testing.md`](docs/testing.md))

- Widget → widget testi + golden (açık/koyu) + durum testleri. Servis/repository → birim test. ViewModel → `ProviderContainer` + fake repository. Rules → emülatör testi (rol × işlem matrisi, **delete herkes için reddedilir**).
- Her ekran: **cihaz matrisi testi** (320 / 390 / 430 / tablet × açık/koyu × TR/EN × metin ölçeği 1.0/1.3/1.6; taşma = fail), **aksiyon envanteri testi**, durum testleri (loading/empty/error/offline).
- Golden güncelleme yalnızca bilinçli (`--update-goldens`) ve kullanıcıya bildirilir.

## 11. Kalite kapısı ve commit

```
bash tool/quality_gate.sh --task T-12      # task bitişi (tam kapı; done için şart)
bash tool/quality_gate.sh --fast | --static # ara kontrol (done için geçersiz)
bash tool/quality_gate.sh --final           # T-47
```
format → codegen/gen-l10n → `flutter analyze --fatal-infos` → katman sınırı → hardcode → no-hard-delete → ARB (`--strict`) → tasarım kapsamı → testler + kapsam eşikleri → Rules. **Kırmızıyken commit yok.** Bash aracı varsayılan 2 dk zaman aşımına sahiptir: tam kapıyı `timeout: 600000` ile ya da arka planda çalıştır (`gu-quality-gate`).

- Commit: Conventional Commits + task ID, açıklama Türkçe (D-35). Üretilen dosyalar commit edilmez. `git push` yok (kullanıcı ister).
- Task bitişi: roadmap durumunu `docs/progress.json`'a işle, değişen kararları `docs/decisions.md`'ye, yeni widget'ları `docs/widget-catalog.md`'ye yaz.

## 12. Tasarıma 1:1 uyum (özet; sözleşme [`docs/design-contract.md`](docs/design-contract.md))

- Referans: `design/reference-shots/{screens,sheets,dialogs,toasts,states}` ve `design/extracted/*` (token, ID, rota, aksiyon, CSS). Prototip kaynağı `design/prototype/app/*.js` **okunur, port edilmez** (Preact → Flutter anlamsal çeviri).
- Her ekran bitince kendi test çıktınla referans görüntüyü **gözle karşılaştır** (`gu-design-fidelity-reviewer` ajanı). Ölçü, boşluk, renk, metin, durum, ikon farkı = hata.
- Bilinen tasarım kusurları ve Flutter'daki karşılıkları: [`docs/design-known-issues.md`](docs/design-known-issues.md). Tasarımdaki **mock** öğeler (Demo FAB, kontrol paneli, cihaz çerçevesi, sahte durum çubuğu, "(Demo) …" butonları, demo hesap çipleri, "Okutuldu simüle et") **uygulanmaz**; yalnızca debug/emülatör build'inde isteğe bağlı `DebugMenu` olarak (kullanıcı isterse).

## 13. Yapma listesi (hızlı kontrol)

- ❌ Hard delete · ❌ hardcode · ❌ tekrarlı widget · ❌ `GetIt.I` view'da · ❌ Freezed/AsyncValue · ❌ `google_fonts` · ❌ Material `Icons` · ❌ kapsam dışı özellik · ❌ onaysız `firebase deploy`/gerçek projeye yazma · ❌ onaysız kilitli kararı değiştirme · ❌ kırmızı kapıyla commit · ❌ `--no-verify` · ❌ üretilen dosyayı commit · ❌ plan modunda onaysız uygulama · ❌ düz metinle seçenekli soru.

## 14. Dosya haritası

| Ne | Nerede |
|---|---|
| Başlangıç prompt'u | `prompts/00-baslat.md` |
| Soru bankası | `prompts/01-soru-bankasi.md` |
| Task şablonu | `prompts/task-calistir.md` |
| Yol haritası + task→ID eşlemesi | `docs/roadmap.md`, `docs/task-map.json` |
| İlerleme / kapılar / bağlama borçları | `docs/progress.json` (`node tool/progress.js …`) |
| Task planları (kalıcı) | `docs/plans/T-xx.md` |
| Faz 0 / Faz 1 prompt'ları | `prompts/02-faz0-kurulum.md`, `prompts/03-faz1-tasarim-analizi.md` |
| Beceriler / ajanlar / hook'lar | `.claude/skills/*`, `.claude/agents/*`, `.claude/settings.json` |
| Kalite betikleri | `tool/quality_gate.sh`, `tool/check_{hardcode,no_hard_delete,boundaries}.sh`, `tool/check_design_coverage.js`, `tool/check_arb_parity.js`, `tool/check_coverage.js`, `tool/codegen.sh`, `tool/verify_pack.sh`, `tool/hooks/post_edit.sh` |
| Süper admin claim / demo veri | `tool/admin/README.md`, `tool/seed/README.md` |
| Konvansiyon örnek kodu (salt okunur) | `reference/` (`reference/README.md`) |
| Paket haritası / okuma sırası | `docs/README.md` |
| Veri modeli, iş kuralları | `docs/domain-model.md` |
| Rules + indeks spesifikasyonu | `docs/firestore-rules-spec.md` |
| Bildirim/Functions mimarisi | `docs/architecture.md §7` |
| Tasarım envanteri | `design/extracted/registry.json`, `screens-actions.json` |
| Prototip CSS (bileşen ölçüleri) | `design/extracted/component-css.css` |
| Üretilmiş referans kod/renk/font | `design/generated-reference/` |
