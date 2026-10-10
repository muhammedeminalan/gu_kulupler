'use strict';
// Rules test bağlamları (PLAN §11.1 sütunları): ad → RulesTestContext.
// Tanımlar `expectations/roles.json` dosyasındadır (uid, token claim'leri, kullanıcı ve üyelik
// alanları); bu dosya yalnızca onları emülatör bağlamına çevirir. Aynı JSON'u `fixtures.js`
// (veri) ve Dart `RolePolicy` parite testi (rol) okur — bağlam bilgisinin ikinci kopyası yoktur.
const roles = require('../expectations/roles.json');
const { getTestEnv } = require('../setup/env');

/** Matrisin 12 bağlamı (§11.1 sütun sırası). */
const CONTEXTS = Object.freeze([...roles.contexts]);

/** Alt varyantlar: `outsideDomain` (unver), `deleted` (susp) — yalnızca kendi vakalarında kullanılır. */
const VARIANTS = Object.freeze(Object.keys(roles.variants));

/** Bağlamların üyelik taşıdığı kulüp (`c01`) ve çapraz kulüp vakalarının kulübü (`c02`). */
const CLUB = roles.club;
const OTHER_CLUB = roles.otherClub;

/** Oturumsuz bağlamın yol şablonlarında kullandığı sahte kimlik (hiçbir belgenin sahibi değildir). */
const ANON_UID = 'u_anon';

/** Takma adı (`superadmin`, `otherMgr`) asıl bağlam adına çevirir; bilinmeyen ad hatadır. */
function resolveName(name) {
  const canonical = roles.aliases[name] || name;
  if (!roles.definitions[canonical]) {
    throw new Error(`bilinmeyen Rules bağlamı: ${name} (geçerli: ${Object.keys(roles.definitions).join(', ')})`);
  }
  return canonical;
}

/** Bağlam tanımı: { uid, token, user, membership, activeUser, clubRole, isSuper }. */
function definition(name) {
  return roles.definitions[resolveName(name)];
}

/** Bağlamın uid'i; oturumsuz bağlamda `ANON_UID`. */
function uidOf(name) {
  return definition(name).uid || ANON_UID;
}

/**
 * Bağlamın yeni bir emülatör istemcisi. Token claim'leri (`email`, `email_verified`, `superadmin`)
 * `authenticatedContext` ile verilir — gerçek Auth kullanıcısı gerekmez. İstemci yerel önbelleği
 * önceki testlerden bağımsız olsun isteniyorsa `contextFor` yerine bu kullanılır.
 * @param {string} name `CONTEXTS`, `VARIANTS` ya da takma ad
 * @returns {{firestore: () => object, storage: () => object}}
 */
function freshContext(name) {
  const def = definition(name);
  const env = getTestEnv();
  const raw = def.uid ? env.authenticatedContext(def.uid, { ...def.token }) : env.unauthenticatedContext();
  // firestore()/storage() her çağrıda emülatör ayarını yeniden uygular; örnekler tembel ve bir kez alınır.
  let firestore = null;
  let storage = null;
  return {
    firestore: () => (firestore = firestore || raw.firestore()),
    storage: () => (storage = storage || raw.storage()),
  };
}

/** Test dosyası boyunca yeniden kullanılan bağlamlar (jest modülleri dosya başına yalıtır). */
const cache = new Map();

/**
 * Bağlamın emülatör istemcisi; aynı ad için dosya boyunca aynı istemci döner (yeni istemci ~30 ms,
 * yeniden kullanım ~4 ms). Sunucu verisi her testten önce boşaltılır; okumalar sunucudan gelir.
 * @param {string} name `CONTEXTS`, `VARIANTS` ya da takma ad
 */
function contextFor(name) {
  const key = resolveName(name);
  if (!cache.has(key)) cache.set(key, freshContext(key));
  return cache.get(key);
}

module.exports = {
  CONTEXTS,
  VARIANTS,
  CLUB,
  OTHER_CLUB,
  ANON_UID,
  resolveName,
  definition,
  uidOf,
  contextFor,
  freshContext,
};
