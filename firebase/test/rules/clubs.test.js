'use strict';
// T-15 — `clubs/{clubId}` (rules-spec §3.3; PLAN §11.1 satır 3).
//
// Rol × işlem matrisi: `expectations/clubs.json`.
//  - Okuma: doğrulanmış her kullanıcı (askıdaki kulüp dahil); silinmiş kulüp yalnızca süper admine;
//    olmayan kulüp boş döner; liste `isDeleted == false` süzgeci ister.
//  - Yazma: T-15'te yalnızca sayaç dalı açıktır ve tek başına geçmez (eşlik eden üyelik geçişi ister) —
//    ayrıntı `counters.test.js`. Oluşturma (T-37), yönetim alanları ve devir (T-30), askı (T-37) kapalıdır.
// Sorgu sözleşmesi ve indeksler `queries.test.js` dosyasındadır.
const { runMatrix } = require('../helpers/matrix');

runMatrix('clubs.json');
