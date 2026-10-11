'use strict';
// T-12 — Repository ↔ Rules yük sözleşmesi (uçtan uca; CLAUDE.md §9 "yazma yolu = Rules + testi").
//
// `contracts/repository_payloads.json` repository'lerin Firestore'a gönderdiği GERÇEK yazımlardır:
// Dart tarafı (packages/gu_data/test/repositories/rules_payload_contract_test.dart) gerçek
// FirebaseUserRepository / FirebaseSettingsRepository'nin SDK'ya verdiği ham yükün bu dosyayla birebir
// aynı olduğunu doğrular. Bu dosya aynı yazımları emülatörde, kurallar AÇIKKEN, hesabın sahibi olarak
// gönderir: hepsi geçmelidir. Böylece "repository'nin yazdığı her alan Rules beyaz listesinde" iddiası
// elle kopyalanmış bir yük (helpers/payloads.js) yerine tek kaynaktan sınanır.
//
//  1. Öykü adımları: her adım, önceki adımların bıraktığı belgeler üzerinde koşar (önceki adımlar
//     kurallar kapalıyken aynı yüklerle kurulur).
//  2. Akış kısıtları (repository yükü doğru olsa da çağrı SIRASI yanlışsa ret): doğrulanmamış oturum
//     profil oluşturamaz; profil tamamlanmadan (interests boş) tek alanlı güncelleme geçmez.
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, serverTimestamp, setDoc, updateDoc, writeBatch } = require('firebase/firestore');
const contract = require('../contracts/repository_payloads.json');
const { contextFor, definition } = require('../helpers/contexts');
const { readDoc } = require('../helpers/fixtures');
const { getAdminContext } = require('../setup/env');

const SENTINEL = contract.serverTimestamp;

/** Sözleşmedeki `@serverTimestamp` nöbetçilerini SDK nöbetçisine çevirir (iç içe map / liste dahil). */
function materialize(value) {
  if (value === SENTINEL) return serverTimestamp();
  if (Array.isArray(value)) return value.map(materialize);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([key, inner]) => [key, materialize(inner)]));
  }
  return value;
}

/**
 * Bir adımın yazımlarını repository'nin gönderdiği biçimde gönderir: tek yazım doğrudan, birden çok
 * yazım tek batch (`FirestoreService.commitBatch`). Noktalı anahtar (`clubs.c01`) iki SDK'da da alan
 * yoludur.
 */
function send(db, writes) {
  const apply = (target, write) => {
    const ref = doc(db, write.path);
    const data = materialize(write.data);
    if (write.op === 'set') return target ? target.set(ref, data) : setDoc(ref, data);
    if (write.op === 'update') return target ? target.update(ref, data) : updateDoc(ref, data);
    throw new Error(`bilinmeyen işlem: ${write.op}`);
  };
  if (writes.length === 1) return apply(null, writes[0]);
  const batch = writeBatch(db);
  for (const write of writes) apply(batch, write);
  return batch.commit();
}

/** Verilen adımları kuralları atlayarak uygular (öykünün önceki adımları). */
async function replay(steps) {
  const db = (await getAdminContext()).firestore();
  for (const step of steps) await send(db, step.writes);
}

const ownerDb = () => contextFor(contract.role).firestore();
const stepByCall = (call) => contract.steps.find((step) => step.call === call);

describe('sözleşme bağlamı', () => {
  test('uid ve e-posta roles.json bağlamıyla aynı (token e-postası = private/account.email)', () => {
    const def = definition(contract.role);
    expect(contract.uid).toBe(def.uid);
    expect(contract.email).toBe(def.token.email);
    expect(def.token.email_verified).toBe(true);
  });
});

describe('repository yazımları kurallardan geçer — öykü (sahibi, kurallar açık)', () => {
  test.each(contract.steps.map((step, index) => [step.call, index]))('%s', async (_call, index) => {
    await replay(contract.steps.slice(0, index));
    const step = contract.steps[index];

    await assertSucceeds(send(ownerDb(), step.writes));

    for (const write of step.writes) expect(await readDoc(write.path)).not.toBeNull();
  });
});

describe('repository yazımları kurallardan geçer — boş veritabanı', () => {
  test.each(contract.standalone.map((step) => [step.call, step]))('%s', async (_call, step) => {
    await assertSucceeds(send(ownerDb(), step.writes));

    for (const write of step.writes) expect(await readDoc(write.path)).not.toBeNull();
  });
});

describe('akış kısıtları — yük doğru, çağrı sırası yanlış → ret', () => {
  const createProfile = stepByCall('UserRepository.createProfile');

  test('doğrulanmamış oturum (kayıttan hemen sonra) profil oluşturamaz: createProfile doğrulama SONRASI çağrılır', async () => {
    const def = definition('unver');
    const retarget = (value) =>
      JSON.parse(JSON.stringify(value).split(contract.uid).join(def.uid).split(contract.email).join(def.token.email));

    await assertFails(send(contextFor('unver').firestore(), retarget(createProfile.writes)));

    for (const write of retarget(createProfile.writes)) expect(await readDoc(write.path)).toBeNull();
  });

  test('profil tamamlanmadan (interests boş) tek alanlı güncelleme reddedilir: AUT-05 yaması önce gider', async () => {
    await replay([createProfile]);
    const before = await readDoc(`users/${contract.uid}`);

    await assertFails(send(ownerDb(), stepByCall('UserRepository.updateProfile · profil fotoğrafı').writes));

    expect(await readDoc(`users/${contract.uid}`)).toEqual(before);
  });
});
