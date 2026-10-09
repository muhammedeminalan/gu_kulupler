---
name: gu-navigation
description: go_router typed route, StatefulShellRoute, guard/redirect, sayfa geçişleri, geri davranışı ve sekmeler arası bağlantı işleri. Rota eklerken, ekran bağlarken, derin bağlantı veya bildirim yönlendirmesi yazarken kullan.
---

# gu-navigation

Sözleşme: `docs/navigation.md` (rota tabloları, redirect tablosu, Q-20, geçişler, geri kuralları, testler). Kilitli: D-05, D-06, D-20.

## Kurallar

1. **Typed route**: `@TypedGoRoute` + `GoRouteData`, sınıf adı `<Ad>Route` (tablo `navigation.md §2`). Üretilen `app_router.g.dart` commit edilmez.
2. **Guard'lı rotalara daima `go`.** `push` yalnızca guard'sız geçici sayfa: `LegalRoute` (AUT-06). Sheet/dialog zaten `showModal*` (FeedbackService). `grep` testi bunu zorlar.
3. **Kimlik/rol kararı router'da** (`AuthGuard`, `AppRedirect`). View'dan `context.go` ile auth kararı verilmez.
4. **Path parametresi:** zorunlu id'ler path'te (`$extra`'ya model taşıma yok). Sorgu parametreleri tablodaki gibi (`?tab=`, `?clubId=`, `?showCancelled=`, `?from=`).
5. **Sekmeler:** `StatefulShellRoute.indexedStack` — 5 dal (clubs/events/notifications/profile/admin). Aktif sekmeye tekrar dokunma = köke dön/başa kaydır. Sekme yığınları **karışmaz**. Alt çubuk yalnızca sekme kökünde (yığın derinliği 1).
6. **Sekmeler arası bağlantı:** Q-20 cevabına göre (`navigation.md §4`): varsayılan A "hedefin ev sekmesine geç". Bildirimden derin bağlantı = `openInTab` eşdeğeri (yığın: sekme kökü → hedef).
7. **Geçişler:** platform varsayılanı (iOS Cupertino, Android predictive back). İstisnalar yalnızca `§5` (sekme geçişi/splash/enterApp → fade). Elle `CustomTransitionPage` istisna dışında yok.
8. **Geri:** `§6` — sekme kökünde Android geri ilk sekmeye; formlarda `PopScope(canPop: !dirty)` → DLG-25; AUT-03 ve DLG-26'da geri çıkış yaptırmaz; SYS-04 "Geri" = `canPop ? pop : go(home)`.
9. **Silinmiş/yok içerik** → SYS-04 (`NotFoundRoute`, aynı zamanda `errorBuilder`).

## Yeni rota ekleme sırası

1. `navigation.md` tablosundaki satırı bul (yoksa dur → `gu-ask-user`); ekran ID'si ↔ `registry.json#inventory` yolu.
2. `*_route.dart` içinde typed sınıf; `$extra` yok; parametre tipleri.
3. Guard: rol/üyelik gereksinimi tablodan (`seesInside`, `manager`, `super`).
4. Çağıran tarafta `XRoute(...).go(context)`; `push` değil.
5. Test: redirect satırı, envanter (51 satır), yığın, geri, platform geçişi.
6. Başka task'a ait hedef ise **uygulama** → `progress.json#pendingWiring`.

## Test

`AppRedirect` tablo testi · rota envanteri ↔ `registry.json#inventory` · derin bağlantı tablosu (§4.1) yığınları · sekme yığını bağımsızlığı · platform geçiş testi · `context.push(` taraması (yalnızca `LegalRoute`).
