# Navigasyon, Rotalar ve Geçişler

> Kilitli: D-05 (go_router + typed routes + `StatefulShellRoute.indexedStack`, **guard'lı rotalara daima `go`**), D-06 (platformun kendi geçişi), D-20 (durum çubuğu).
> Kaynak: prototipin gerçek rota haritası (`design/prototype/app/core.js` → `ROUTE_PATH`, `TAB_OF`, `nav.*`; `actions.js` → `flows.openNotification`) ve `registry.json#inventory`.
> **Q-20** (sekmeler arası bağlantıda geri davranışı) cevabı bu dokümanın §4'ünü belirler. Cevaplanana kadar **varsayılan = A**.

## 1. Model

```
GoRouter (rootNavigatorKey, refreshListenable: SessionViewModel, redirect: AuthGuard)
├── ön-oturum rotaları (kabuksuz)         /splash /onboarding /login{/register,/reset} /verify /setup-profile /legal/:tip
├── sistem rotaları (kabuksuz)            /error /offline /not-found
└── StatefulShellRoute.indexedStack  (AppShellView = alt sekme çubuğu)
    ├── branch clubs          /clubs                 CLB-01   (+ alt ağaç)
    ├── branch events         /events                EVT-01
    ├── branch notifications  /notifications         NTF-01
    ├── branch admin          /admin                 ADM-01   (yalnızca süper admin; sekme yoksa branch erişilmez)
    └── branch profile        /profile               PRF-01
```

- **Her sekme kendi yığınını korur** (indexedStack); sekmeler arası yığın **karışmaz**. Aktif sekmeye tekrar dokunma: yığın derinse köke döner (`goBranch(i, initialLocation: true)`), kökteyse listeyi başa kaydırır (`scrollTopReq`).
- **Alt sekme çubuğu yalnızca sekme kökünde görünür** (prototip: `nav.depth()==1`). Daha derin ekranlarda gizlenir; `AppShellView` bunu `GoRouterState`'ten (derinlik) türetir, **ekran ekran elle** değil. Toast, çubuk görünürken onun üstünde durur.
- **Yığın rota ağacından türetilir** (`go` kuralı): geri tuşunun çalışması istenen her ekran, mantıksal ebeveyninin `routes:` listesinde **alt-rota**dır.
- Zorunlu id'ler **path parametresidir**; `$extra` ile model taşınmaz. Opsiyonel bağlam **query parametresidir** (`?clubId=`, `?tab=`).
- **`push` yalnızca guard'sız, geçici sayfalar için:** `AUT-06` (yasal metin; AUT-01/AUT-02/SHT-05/SET-04'ten açılır). Başka `push` yok (testle sabitlenir: `grep` `context.push` yalnızca bu rotada).
- Auth/rol kararları `redirect`'tedir (`AuthGuard`, `RoleGuard`); view içinden auth amaçlı `go` yazılmaz. Giriş sonrası dönüş adresi `from` query parametresiyle.
- Sheet/dialog/menü/toast **rota değildir**: `FeedbackService` (`showModalBottomSheet` / `showDialog` / overlay). Sheet içinden rota açılırsa önce sheet kapanır (`SheetCloseThen`).

## 2. Rota tablosu

Tür: `T` = tab kökü, `C` = alt rota (ebeveyn belirtilir), `X` = kabuksuz üst-düzey. Guard: `A` oturum+doğrulanmış+profil tamam, `M` o kulüpte `manager` (board/president), `V` `manager|advisor` (danışman salt okunur), `S` süper admin, `G` misafir (oturum yok).
Typed route sınıf adı = `<Ad>Route` (go_router_builder). Prototip yolu `core.js ROUTE_PATH`'tan; **Flutter yolu** kilitli olandır.

### 2.1 Kabuksuz

| ID | Flutter yolu | Sınıf | Guard | Not |
|---|---|---|---|---|
| SYS-01 | `/splash` | `SplashRoute` | — | açılışta; çözüm bitince yönlendirir |
| SYS-02 | `/error` | `ErrorRoute` | — | `?from=` ile yeniden dene hedefi; "Ana sayfa" `go` |
| SYS-03 | `/offline` | `OfflineRoute` | — | tam ekran (önbellek yok) |
| SYS-04 | `/not-found` | `NotFoundRoute` | — | aynı zamanda `errorBuilder` (bilinmeyen URL) ve silinmiş içerik; "Geri" = `canPop ? pop : go(home)` |
| ONB-01 | `/onboarding` | `OnboardingRoute` | G (ilk açılış) | 3 slayt |
| AUT-01 | `/login` | `LoginRoute` | G | `?from=` |
| AUT-02 | `/login/register` | `RegisterRoute` | G | AUT-01'in alt rotası (geri → AUT-01) |
| AUT-04 | `/login/reset` | `ResetPasswordRoute` | G | alt rota |
| AUT-03 | `/verify` | `VerifyEmailRoute` | oturum var, doğrulanmamış | |
| AUT-05 | `/setup-profile` | `SetupProfileRoute` | doğrulanmış, profil eksik | |
| AUT-06 | `/legal/:tip` | `LegalRoute` | — | `tip ∈ {kosullar, gizlilik, kvkk}`; geçersiz → SYS-04; **`push`** ile açılır |

### 2.2 Sekme: Kulüpler (`/clubs`)

| ID | Flutter yolu | Sınıf | Ebeveyn | Guard | Prototip yolu |
|---|---|---|---|---|---|
| CLB-01 | `/clubs` | `ClubsRoute` | T | A | `/clubs` |
| CLB-02 | `/clubs/search` | `ClubsSearchRoute` | CLB-01 | A | `/clubs/search` |
| CLB-07 | `/clubs/user/:userId?clubId=` | `ClubUserProfileRoute` | CLB-01 | A (+ `clubId` varsa üyelik bağlamı) | `/users/:id` |
| CLB-03 (+FED-01) | `/clubs/:id?tab=about\|posts\|events` | `ClubDetailRoute` | CLB-01 | A | `/clubs/:id` |
| CLB-04 | `/clubs/:id/applied` | `ClubAppliedRoute` | CLB-03 | A | `/clubs/:id/applied` |
| CLB-05 | `/clubs/:id/application` | `ClubApplicationRoute` | CLB-03 | A | `…/application` |
| CLB-06 | `/clubs/:id/members` | `ClubMembersRoute` | CLB-03 | üye (`seesInside`) | `…/members` |
| FED-02 | `/clubs/:id/posts/:postId` | `PostDetailRoute` | CLB-03 | üye | `…/posts/:postId` |
| FED-03 | `/clubs/:id/compose?edit=` | `ComposeRoute` | CLB-03 | M | `…/compose` |
| MGT-01 | `/clubs/:id/manage` | `ManageRoute` | CLB-03 | V | `/manage/:clubId` |
| MGT-02 | `/clubs/:id/manage/applications` | `ManageApplicationsRoute` | MGT-01 | V (yazma M) | `…/applications` |
| MGT-03 | `/clubs/:id/manage/members` | `ManageMembersRoute` | MGT-01 | V | `…/members` |
| MGT-04 | `/clubs/:id/manage/events` | `ManageEventsRoute` | MGT-01 | V | `…/events` |
| MGT-05 | `/clubs/:id/manage/events/new` · `…/events/:eventId/edit` | `EventFormRoute` | MGT-04 | M | `…/events/new` |
| MGT-06 | `/clubs/:id/manage/events/:eventId/attendance` | `AttendanceRoute` | MGT-04 | V (yoklama M) | `…/attendance` |
| MGT-07 | `/clubs/:id/manage/events/:eventId/attendance/scan` | `ScanRoute` | MGT-06 | M | `…/scan` |
| MGT-08 | `/clubs/:id/manage/content` | `ManageContentRoute` | MGT-01 | V | `…/content` |
| MGT-09 | `/clubs/:id/manage/settings` | `ClubSettingsRoute` | MGT-01 | V | `…/settings` |
| MGT-10 | `/clubs/:id/manage/activity` | `ActivityLogRoute` | MGT-01 | V | `…/activity` |

`:id` ve `:clubId` aynı kulüp kimliğidir (yol parametresi adı `clubId` olarak birleştirilir; prototipteki `id`/`clubId` ikiliği taşınmaz).

### 2.3 Sekme: Etkinlikler (`/events`)

| ID | Flutter yolu | Sınıf | Ebeveyn | Guard |
|---|---|---|---|---|
| EVT-01 | `/events` | `EventsRoute` | T | A |
| EVT-02 | `/events/:id?showCancelled=` | `EventDetailRoute` | EVT-01 | A (members-only etkinlik: üye) |
| EVT-03 | `/events/:id/ticket` | `TicketRoute` | EVT-02 | A + kendi rsvp'si |
| EVT-04 | `/events/mine` | `MyEventsRoute` | EVT-01 | A |
| CLB-02 (paylaşılan) | `/events/search` | `EventsSearchRoute` | EVT-01 | A |

### 2.4 Sekme: Bildirimler (`/notifications`)

| ID | Flutter yolu | Sınıf | Ebeveyn | Guard |
|---|---|---|---|---|
| NTF-01 | `/notifications` | `NotificationsRoute` | T | A |
| NTF-02 (paylaşılan) | `/notifications/preferences` | `NotificationPrefsRoute` | NTF-01 | A |

### 2.5 Sekme: Profil (`/profile`)

| ID | Flutter yolu | Sınıf | Ebeveyn | Guard |
|---|---|---|---|---|
| PRF-01 | `/profile` | `ProfileRoute` | T | A |
| PRF-02 | `/profile/edit` | `EditProfileRoute` | PRF-01 | A |
| PRF-03 | `/profile/clubs?tab=active\|pending\|past` | `MyClubsRoute` | PRF-01 | A |
| PRF-04 | `/profile/saved` | `SavedRoute` | PRF-01 | A |
| SET-01 | `/profile/settings` | `SettingsRoute` | PRF-01 | A |
| NTF-02 (paylaşılan) | `/profile/settings/notifications` | `SettingsNotificationPrefsRoute` | SET-01 | A |
| SET-02 | `/profile/settings/blocked` | `BlockedRoute` | SET-01 | A |
| CLB-07 (paylaşılan) | `/profile/settings/blocked/:userId` | `BlockedUserProfileRoute` | SET-02 | A |
| SET-03 | `/profile/settings/delete` | `DeleteAccountRoute` | SET-01 | A |
| SET-04 | `/profile/settings/about` | `AboutRoute` | SET-01 | A |
| SET-05 | `/profile/settings/support` | `SupportRoute` | SET-01 | A |

### 2.6 Sekme: Admin (`/admin`)

| ID | Flutter yolu | Sınıf | Ebeveyn | Guard |
|---|---|---|---|---|
| ADM-01 | `/admin` | `AdminRoute` | T | S |
| ADM-02 | `/admin/clubs` | `AdminClubsRoute` | ADM-01 | S |
| ADM-03 | `/admin/clubs/new` · `/admin/clubs/:id/edit` | `AdminClubFormRoute` | ADM-02 | S |
| ADM-04 | `/admin/reports?reportId=` | `AdminReportsRoute` | ADM-01 | S |
| ADM-05 | `/admin/users` | `AdminUsersRoute` | ADM-01 | S |
| CLB-07 (paylaşılan) | `/admin/users/:userId` | `AdminUserProfileRoute` | ADM-05 | S |

- Sekme çubuğu: `Kulüpler · Etkinlikler · Bildirimler · [Admin] · Profil`; **Admin yalnızca `isSuperAdmin`** (kabuk bunu gösterir/gizler; rota guard'ı yine de uygular). Bildirim rozeti: okunmamış sayısı, 9 üstü "9+".
- **Paylaşılan yaprak ekranlar** (bir görünüm sınıfı, birden çok rota sınıfı): `Search` (clubs, events), `NotificationPrefs` (notifications, profile), `UserProfile/CLB-07` (clubs, profile, admin). Gerekçe: bu ekranlar birden çok sekmeden doğal olarak açılır ve ağır alt ağaçları yoktur; sekme değiştirmek yanlış hissettirirdi.
- Rota sınıfı sayısı artmasın diye paylaşılanların `build()` gövdeleri aynı view'a delege eder (tekrarlı widget yasağı D-16).

## 3. Yönlendirme (redirect) tablosu

`architecture.md §6` ile aynıdır; burada rota düzeyinde:

| Durum | Giriş yapılan yol | Sonuç |
|---|---|---|
| oturum çözülmedi | herhangi | `/splash` |
| oturum yok, ilk açılış | herhangi (auth dışı) | `/onboarding` → `/login` |
| oturum yok | app rotaları | `/login?from=<yol>` |
| oturum var, e-posta doğrulanmamış | herhangi | `/verify` |
| doğrulanmış, profil eksik | herhangi | `/setup-profile` |
| askıda (`status=suspended`) | herhangi | oturum kapat → `/login` + DLG-01 |
| aktif | `/splash`, `/onboarding`, `/login*`, `/verify`, `/setup-profile` | `from` varsa o, yoksa `/clubs` |
| aktif, süper değil | `/admin/**` | `/clubs` + TST-X18 |
| aktif, kulüpte yönetici/danışman değil | `/clubs/:id/manage/**` | `/clubs/:id` + TST-X18 |
| aktif, üye değil | `/clubs/:id/members`, `…/posts/*` | `/clubs/:id` (yönetici/üye olmayan için üyelik bandı) |
| danışman | `…/manage/**` yazma ekranları (`compose`, `events/new\|edit`, `attendance/scan`) | `/clubs/:id/manage` + TST-26 |
| `:tip` geçersiz, kaynak yok (silinmiş) | | `/not-found` |

- **Oturum/rol değişince** `refreshListenable` yeniden değerlendirir (rol düşürülürse yönetim ekranındaki kullanıcı atılır).
- Zorunlu güncelleme (DLG-26) ve oturum sona erdi (DLG-27) rota değil kök katman diyaloğudur; ikincisi sonrası `/login`.
- Yönlendirme mantığı **saf fonksiyon** (`AppRedirect.resolve(SessionState, Uri)`) olarak yazılır; tablo testiyle (her satır) kanıtlanır.

## 4. Sekmeler arası bağlantı (Q-20) ve derin bağlantılar

**Varsayılan (A) — "sekme değiştirir":** ekran, kendi **ev sekmesinin** ağacında yaşar. Başka sekmeden o ekrana `go` ile gidilince ev sekmesine **geçilir** ve yığın `kök → … → hedef` olur; çağıran sekme yığınını **korur** (alt çubuktan geri dönülebilir). Örn. Profil'den bir kulübe → Kulüpler sekmesi `[CLB-01, CLB-03]`; Etkinlik detayından kulüp çipi → aynı. Geri, hedef sekmenin köküne iner.
**Alternatifler (Q-20):** (B) detay ekranlarını kök navigatörde `push` ile açıp geri her zaman çağırana dönsün (prototipe en sadık; `go` kuralından sapma, guard'lı alt rotalar için ekran içi koruma gerekir); (C) her sekme paylaşılan alt ağaçların kendi kopyasını taşısın (en sadık, rota sınıfı sayısı ~5×). Cevap C ya da B ise bu bölüm ve §2 yeniden yazılır, `docs/decisions.md`'ye işlenir.

### 4.1 Bildirim / derin bağlantı → rota (`openNotification`, prototipten)

Kural: kaydı okundu işaretle → hedefi `go` ile aç → hedef yoksa/silinmişse **SYS-04**.

| Bildirim türü | Hedef (yığın) | Ek |
|---|---|---|
| `application_received` | `/clubs/:cid/manage/applications` | 250 ms sonra başvuranın SHT-19'u (üyelik hâlâ varsa) |
| `application_approved`, `role_changed` | `/clubs/:cid` | |
| `application_rejected`, `removed_from_club` | `/clubs/:cid/application` | yığın: kulüp → başvuru durumu |
| `announcement` | `/clubs/:cid/posts/:pid` (kulüp sekmesi `posts`) | gönderi yok/silinmiş/gizli → SYS-04 |
| `event_new` | `/events/:eid` | etkinlik yok → SYS-04 |
| `event_cancelled` | `/events/:eid?showCancelled=true` | |
| `event_reminder`, `waitlist_promoted` | kayıtlıysa `/events/:eid/ticket`, değilse `/events/:eid` | |
| `report_resolved` | rota yok | yalnızca TST-17 |
| `new_report` | `/admin/reports?reportId=` | süper ise 250 ms sonra SHT-26 |
| `system` / varsayılan | `/profile/settings/about` | |

FCM push tıklaması aynı çözücüyü kullanır (`NotificationNavigator.open(NotificationModel)`); uygulama kapalıyken açılış `getInitialMessage` ile, splash sonrası.

## 5. Sayfa geçişleri (D-06) — istisna listesi

**Varsayılan:** platform. `ThemeData.pageTransitionsTheme`: iOS → `CupertinoPageTransitionsBuilder` (kenardan geri kaydırma, paralaks), Android → `PredictiveBackPageTransitionsBuilder` (Android 14+ predictive back; eskiye düşer). go_router `MaterialPage` (varsayılan) bunu kullanır.

| Geçiş | Animasyon | Gerekçe (prototip `nav.anim`) |
|---|---|---|
| Sekme değiştirme | animasyonsuz / çapraz solma (`GuMotion.fast`) | `fade` |
| Splash → ilk ekran, giriş sonrası uygulamaya geçiş (`enterApp`), çıkış, hesap silme sonrası | solma (`GuMotion.base`) | `fade` |
| `replace` benzeri (örn. bildirim → hedef) | solma | `fade` |
| Sheet | alttan yükselme, 28 radius üst köşe, `GuMotion.base`; sürükleyerek kapanma | tasarım |
| Dialog | solma + hafif ölçek `GuMotion.fast` | tasarım |
| Toast | alttan yükselme/solma | tasarım |

- Hiçbir ekranda ad hoc `CustomTransitionPage` yok; yukarıdaki üç satır tek yardımcıdan (`GuPageTransitions`) gelir.
- `MediaQuery.disableAnimations` açıksa tüm süreler 0.
- **Test:** iOS ve Android platform geçersiz kılmasıyla (`debugDefaultTargetPlatformOverride`) rota geçişi + geri; kenar kaydırma; yığın boyu doğrulaması.

## 6. Geri tuşu / predictive back kuralları

- Android sistem geri: derin ekranda `pop`; sekme kökünde, ilk sekme değilse ilk sekmeye (Kulüpler); ilk sekmenin kökünde uygulamadan çıkış (`SystemNavigator.pop`) — `PopScope` ile kabukta tek yerde.
- Formlarda kaydedilmemiş değişiklik: `PopScope(canPop: !dirty)` → DLG-25 ("Değişiklikler kaydedilmedi"). Sheet'te formlu içerik aynı.
- Açık sheet/dialog varken geri önce onu kapatır (modal rota doğal davranışı).
- AUT-03 (doğrulama bekleme) ve zorunlu güncelleme (DLG-26) ekranında geri **çıkış yaptırmaz**.

## 7. Testler (`docs/testing.md §4`)

1. `AppRedirect` tablo testi (§3'ün her satırı).
2. Rota envanteri: `registry.json#inventory` (51 satır) ↔ typed route sınıfları; her ekran bir rotadan ulaşılabilir; tüm path parametreleri ve guard'lar tabloyla aynı.
3. Yığın testi: derin bağlantı tablosu (§4.1) beklenen yığını üretir; geri tuşu beklenen ekrana iner; sekme yığınları birbirine karışmaz (sekme A'da derinleş → B → A: yığın korunur; aktif sekme tekrar dokunma köke indirir).
4. Platform geçiş testi (iOS/Android).
5. `grep` testi: `context.push(` yalnızca `LegalRoute`; view'da `Navigator.`/`GetIt.I` yok.
