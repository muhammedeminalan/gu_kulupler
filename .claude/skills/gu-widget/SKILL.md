---
name: gu-widget
description: Yeni ya da değişen bir ortak widget yazarken (gu_ui veya lib/product/widget) kullan: önce widget-catalog taraması, tüm tasarım durumları, token kullanımı, Semantics, dokunma hedefi, anahtar, test ve golden, katalog güncelleme.
---

# gu-widget — widget yazma

**D-16:** Tekrarlı widget yasak. Kod yazmadan önce `docs/widget-catalog.md` ve `docs/design-analysis.md`'yi tara; benzeri varsa onu **genişlet**.

## Karar: nereye?

| Soru | Yer |
|---|---|
| Alan modeli (`ClubModel`, `EventModel`…) istiyor mu? | **Evet** → `lib/product/widget/` (alan-bilen) |
| Hayır, yalnızca primitifler/token | **`packages/gu_ui/lib/src/<grup>/`** (alan-bağımsız) |
| Yalnızca tek ekrana özgü ve yeniden kullanılmayacak | `features/<x>/view/widget/` (kataloğa yine de yaz) |

`gu_ui` Firebase'e, `gu_data`'ya, router'a, Riverpod'a bağımlı **değildir**.

## Şablon

```dart
/// Design: <bileşen/ekran ID'leri>  (Tasarımdaki adı: Button)
final class GuButton extends StatelessWidget {
  const GuButton({required this.label, required this.onPressed, this.variant = GuButtonVariant.filled,
      this.size = GuButtonSize.md, this.icon, this.loading = false, this.actionKey, super.key});
  ...
  @override
  Widget build(BuildContext context) {
    final gu = context.gu;                       // Theme.of(context) yok
    return GuTapTarget(                          // ≥44 pt iOS / 48 dp Android (D-22)
      child: Semantics(button: true, enabled: onPressed != null, label: ..., child: ...),
    );
  }
}
```

## Zorunlu

1. **Tüm tasarım durumları:** default · pressed · focus (halka `focus.ring`) · disabled · loading · selected · error · read-only — yalnızca tasarımda **var olanlar** (kanıt: CSS/reference-shots).
2. **Token:** renk `gu.colors.*`, boşluk `GuSpacing/GuGap/GuInsets`, radius `GuRadius`, tipografi `gu.text.*`, süre `GuMotion`, boyut `GuSizes`. Sayı/renk/süre literal yok (`tool/check_hardcode.sh`).
3. **Min-height** (sabit yükseklik değil) — metin ölçeği 1.6'da büyüyebilsin; `Flexible`/ellipsis; 320 dp'de taşma yok.
4. **Anlamsal etiket**: `Semantics` (etiket, rol, durum); ikon-yalnız düğmelerde `label` zorunlu.
5. **Anahtar:** etkileşimli öğeler `GuKey.action('<EKRAN>.<aksiyon>')` alır (parametre `actionKey`); widget kendi başına ekran ID'si bilmez, çağıran verir.
6. **Metin yok:** widget metni parametre alır; sabit string yok; ARB'yi çağıran bağlar.
7. **İkon:** `GuIcon(GuIcons.x)`; `Icons.*` yok.
8. **Reduce motion:** animasyon süresi `GuMotion` + `MediaQuery.disableAnimations` → 0.
9. **Test:** durum testleri + `Semantics` + dokunma hedefi (`androidTapTargetGuideline`/`iOSTapTargetGuideline`) + 320 dp taşma + **golden açık+koyu** (`goldenForThemes`).
10. **Katalog:** `docs/widget-catalog.md`'ye satır (ad · konum · durumlar · tasarım ID'leri · test dosyası); `docs/token-map.md` yeni token varsa.

## Yapma

❌ Aynı işi yapan ikinci widget · ❌ `Theme.of(context)` · ❌ `Color(0x…)` · ❌ `EdgeInsets.all(12)` · ❌ `SizedBox(width: 390)` · ❌ düz `StatefulWidget` (feature view'larında) · ❌ ekran içinde inline özel buton/kart.
