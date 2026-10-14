'use strict';
// T-19 — `posts/{postId}` (rules-spec §3.5; PLAN §11.1 satır 6; sözleşme docs/plans/T-19.md §6).
//
//  1. Rol × işlem matrisi: `expectations/posts.json` (okuma, yayın, düzenleme, beğeni, silme / geri alma,
//     gizleme, sabitleme; askıdaki hesap / kulüp; W-51 seed biçimi).
//  2. Yayın (C): alan beyaz listesi, sınırlar (Limits ile aynı sayılar), tür ↔ başlık / anket, görsel
//     yolu (CD-39), anket bitişi (CD-32), sıfır sayaçlar.
//  3. Düzenleme (U): yalnızca `text` / `title` / `images` + `editedAt`.
//  4. Sabitleme: `posts.pinned` ↔ `clubs.pinnedPostId` iki yönlü bağ (pin / unpin / sabit gönderiyi silme).
//  5. Gizleme (süper admin) ve silme: sayaçlar ve sabitleme alanları dışarıda kalır.
//  6. Günlük (`activity`): gönderi yayınının sabit kimlikli tek kaydı.
// Beğeni ve yorum sayaçları `counters.test.js`, duyuru limiti `announcement_limit.test.js`, sorgu
// sözleşmesi `queries.test.js` dosyasındadır.
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { Timestamp, doc, getDoc, serverTimestamp, updateDoc } = require('firebase/firestore');
const budget = require('../helpers/budget');
const { contextFor, CLUB, OTHER_CLUB } = require('../helpers/contexts');
const { readDoc, seedFixture } = require('../helpers/fixtures');
const { runMatrix } = require('../helpers/matrix');
const payloads = require('../helpers/payloads');

const BOARD = 'u_board';
const CLUB_PATH = `clubs/${CLUB}`;
const NEW = 'p_new';
const NEW_PATH = `posts/${NEW}`;
const MINUTE_MS = 60 * 1000;

const dbOf = (role) => contextFor(role).firestore();
const commit = (role, writes) => budget.buildBatch(dbOf(role), Object.values(writes)).commit();
const expectWrite = (request, expected) => (expected === 'allow' ? assertSucceeds(request) : assertFails(request));
const drop = (writes, name) => Object.fromEntries(Object.entries(writes).filter(([key]) => key !== name));
const clientTime = () => Timestamp.fromMillis(Date.now() - MINUTE_MS);
const text = (length) => 'a'.repeat(length);

/** Yönetim kurulu üyesinin yayın batch'i (gönderi + günlük); `extra` gönderi alanlarını ezer / ekler. */
const publish = (type, extra, postId = NEW) => {
  const writes = payloads.createPostWrites({ club: CLUB, uid: BOARD, type, postId });
  return { ...writes, post: { ...writes.post, data: { ...writes.post.data, ...extra } } };
};
const images = (count, postId = NEW) => Array.from({ length: count }, (_, i) => payloads.postImage(postId, i));
const poll = (patch) => ({ poll: { ...payloads.pollOf(), ...patch } });
const options = (...texts) => texts.map((t, i) => ({ id: `o${i + 1}`, text: t }));

runMatrix('posts.json');

describe('posts · create — biçim ve sınırlar (rules-spec §3.5 C; Limits ile aynı sayılar)', () => {
  test('yayın batch\'i gönderiyi sıfır sayaçlarla ve sunucu zamanıyla yazar (istemci biçimi: null alan anahtarı yok)', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('board', publish('post')));
    const post = await readDoc(NEW_PATH);
    expect(Object.keys(post).sort()).toEqual([
      'authorId', 'clubId', 'commentCount', 'createdAt', 'deletedAt', 'deletedBy', 'images', 'isDeleted', 'isHidden',
      'likeCount', 'likes', 'pinned', 'pushSent', 'text', 'type', 'updatedAt',
    ]);
    expect(post).toMatchObject({ clubId: CLUB, authorId: BOARD, type: 'post', likes: [], likeCount: 0, commentCount: 0, pinned: false, pushSent: false, isHidden: false });
    expect(post.createdAt.toMillis()).toBe(post.updatedAt.toMillis());
  });

  // Satır: [başlık, tür, gönderi alanı ezmesi].
  test.each([
    ['metin tam sınırda (1000)', 'post', { text: text(1000) }],
    ['duyuru başlığı tam sınırda (80)', 'announcement', { title: text(80) }],
    ['dört görsel, hepsi kendi klasöründe (CD-39)', 'post', { images: images(4) }],
    ['dört seçenekli anket, seçenek metni tam sınırda (60)', 'poll', poll({ options: options('A', 'B', 'C', text(60)) })],
    ['anket bitişi +1 gün', 'poll', poll({ endsAt: payloads.pollOf(undefined, 1).endsAt })],
    ['anket bitişi +3 gün, istemci saati 4 dk ileride (CD-32 toleransı)', 'poll', poll({ endsAt: payloads.pollOf(undefined, 3, 4 * MINUTE_MS).endsAt })],
    ['anket bitişi +7 gün, istemci saati 4 dk geride', 'poll', poll({ endsAt: payloads.pollOf(undefined, 7, -4 * MINUTE_MS).endsAt })],
    ['bildirimsiz duyuru (pushSent: false) sayaç istemez', 'announcement', {}],
  ])('%s → allow', async (_title, type, extra) => {
    await seedFixture('base');
    await assertSucceeds(commit('board', publish(type, extra)));
    expect(await readDoc(NEW_PATH)).toMatchObject({ type, authorId: BOARD });
  });

  test.each([
    ['başkası adına (authorId)', 'post', { authorId: 'u_president' }],
    ['yönetici olmadığı kulübe (clubId: c02)', 'post', { clubId: OTHER_CLUB }],
    ['tanımsız tür', 'post', { type: 'story' }],
    ['boş metin', 'post', { text: '' }],
    ['yalnızca boşluktan oluşan metin', 'post', { text: '   ' }],
    ['metin sınırın üstünde (1001)', 'post', { text: text(1001) }],
    ['metin dizgi değil', 'post', { text: 42 }],
    ['duyuru başlıksız', 'announcement', { title: null }],
    ['duyuru başlığı yalnızca boşluk', 'announcement', { title: '  ' }],
    ['duyuru başlığı sınırın üstünde (81)', 'announcement', { title: text(81) }],
    ['düz gönderide başlık', 'post', { title: 'Başlık' }],
    ['ankette başlık', 'poll', { title: 'Başlık' }],
    ['beş görsel', 'post', { images: images(5) }],
    ['görsel başka gönderinin klasöründe (CD-39)', 'post', { images: [payloads.postImage('p01')] }],
    ['görsel yolu kullanıcı klasöründe', 'post', { images: [{ path: payloads.avatarPathOf(BOARD), w: 1, h: 1 }] }],
    ['görsel dosya adı desen dışı', 'post', { images: [{ path: `posts/${NEW}/kapak.jpg`, w: 1, h: 1 }] }],
    ['dördüncü görsel başka klasörde (liste sonu da denetlenir)', 'post', { images: [...images(3), payloads.postImage('p01')] }],
    ['görselde fazladan anahtar', 'post', { images: [{ ...payloads.postImage(NEW), url: 'https://example.com/x.jpg' }] }],
    ['görsel boyutu sıfır', 'post', { images: [{ ...payloads.postImage(NEW), w: 0 }] }],
    ['görsel listesi dizi değil', 'post', { images: 'yok' }],
    ['düz gönderide anket', 'post', poll({})],
    ['anket türünde anket yok', 'poll', { poll: null }],
    ['tek seçenek', 'poll', poll({ options: options('A') })],
    ['beş seçenek', 'poll', poll({ options: options('A', 'B', 'C', 'D', 'E') })],
    ['seçenek kimlikleri sırasız (o2, o1)', 'poll', poll({ options: [{ id: 'o2', text: 'A' }, { id: 'o1', text: 'B' }] })],
    ['seçenek kimliği serbest', 'poll', poll({ options: [{ id: 'o1', text: 'A' }, { id: 'evet', text: 'B' }] })],
    ['seçenek metni boş', 'poll', poll({ options: options('A', ' ') })],
    ['seçenek metni sınırın üstünde (61)', 'poll', poll({ options: options('A', text(61)) })],
    ['seçenekte fazladan anahtar (votes)', 'poll', poll({ options: [{ id: 'o1', text: 'A', votes: 99 }, { id: 'o2', text: 'B' }] })],
    ['ankette fazladan anahtar', 'poll', poll({ totalVotes: 10 })],
    ['anket bitişi +2 gün (izinli süre değil)', 'poll', poll({ endsAt: payloads.pollOf(undefined, 2).endsAt })],
    ['anket bitişi +7 gün + 6 dk (tolerans dışı)', 'poll', poll({ endsAt: payloads.pollOf(undefined, 7, 6 * MINUTE_MS).endsAt })],
    ['anket bitişi geçmişte', 'poll', poll({ endsAt: clientTime() })],
    ['anket bitişi zaman damgası değil', 'poll', poll({ endsAt: '2026-10-20' })],
    ['likeCount 1', 'post', { likeCount: 1 }],
    ['likes dolu', 'post', { likes: [BOARD], likeCount: 1 }],
    ['commentCount 1', 'post', { commentCount: 1 }],
    ['lastCommentRef dolu', 'post', { lastCommentRef: 'comments/cm01' }],
    ['pinned true', 'post', { pinned: true }],
    ['isHidden true', 'post', { isHidden: true }],
    ['hiddenBy dolu', 'post', { hiddenBy: BOARD }],
    ['editedAt dolu', 'post', { editedAt: serverTimestamp() }],
    ['düz gönderide pushSent', 'post', { pushSent: true }],
    ['ankette pushSent', 'poll', { pushSent: true }],
    ['beyaz liste dışı alan', 'post', { voteCount: 0 }],
    ['createdAt istemci saati', 'post', { createdAt: clientTime() }],
    ['silinmiş olarak doğan gönderi', 'post', { isDeleted: true }],
  ])('%s → deny', async (_title, type, extra) => {
    await seedFixture('base');
    await assertFails(commit('board', publish(type, extra)));
    expect(await readDoc(NEW_PATH)).toBeNull();
  });

  test('kimlik düzenli ifade karakteri taşıyamaz: `.*` kimlikli gönderi başka klasörün görselini gösteremez', async () => {
    await seedFixture('base');
    const wild = payloads.postCreate({ club: CLUB, uid: BOARD }, { images: [payloads.postImage('p01')] });
    await assertFails(commit('board', { post: { op: 'set', path: 'posts/.*', data: wild } }));
    await assertFails(commit('board', { post: { op: 'set', path: 'posts/p(x)', data: payloads.postCreate({ club: CLUB, uid: BOARD }) } }));
  });

  test('var olan gönderinin üzerine yeniden yayın (set) reddedilir', async () => {
    await seedFixture('base');
    const again = payloads.postCreate({ club: CLUB, uid: BOARD });
    await assertFails(commit('board', { post: { op: 'set', path: 'posts/p01', data: again } }));
    expect((await readDoc('posts/p01')).type).toBe('poll');
  });
});

describe('posts · update — düzenleme (rules-spec §3.5 U yazar)', () => {
  // `p01` temel veri kümesinde ankettir; anket sorusu (`text`) değişmediği için düzenleme vakaları onu düz
  // gönderiye (PLAIN) ya da duyuruya (ANNOUNCEMENT) çevirir, ankete özgü vakalar POLL ile olduğu gibi bırakır.
  const plain = (extra) => ({ patch: { 'posts/p01': { type: 'post', poll: null, ...extra } } });
  const PLAIN = plain();
  const POLL = Object.freeze({});
  const ANNOUNCEMENT = { patch: { 'posts/p01': { type: 'announcement', title: 'Eski başlık', poll: null } } };
  const SAME_QUESTION = { text: payloads.POLL_QUESTION };
  const edit = (role, data, path = 'posts/p01') => updateDoc(doc(dbOf(role), path), payloads.postEdit(data));

  // Satır: [başlık, yük ezmesi, beklenti, veri düzenlemesi?]. Hedef: `p01` (yazarı u_board).
  test.each([
    ['metin + görseller (kendi klasörü)', { images: images(2, 'p01') }, 'allow'],
    ['duyuruda başlık', { title: 'Yeni başlık' }, 'allow', ANNOUNCEMENT],
    ['duyuruda başlığı boşaltma', { title: null }, 'deny', ANNOUNCEMENT],
    ['ankette başlık ekleme', { ...SAME_QUESTION, title: 'Başlık' }, 'deny', POLL],
    ['boş metin', { text: ' ' }, 'deny'],
    ['metin sınırın üstünde', { text: text(1001) }, 'deny'],
    ['görsel başka gönderinin klasöründe', { images: [payloads.postImage('p02')] }, 'deny'],
    ['beş görsel', { images: images(5, 'p01') }, 'deny'],
    ['editedAt istemci saati', { editedAt: clientTime() }, 'deny'],
    ['tür değişimi', { type: 'announcement', title: 'Başlık' }, 'deny'],
    ['anket seçenekleri', { ...SAME_QUESTION, poll: payloads.pollOf(['A', 'B', 'C']) }, 'deny', POLL],
    // Güvenlik incelemesi (CD-141 madde 11, bulgu 3): oylar değiştirilemez (TST-10) ve üyelerce okunur;
    // soru yayından sonra değişirse üyeler vermedikleri bir karara oy vermiş görünür.
    ['ankette soru (text) değişimi: oylar başka soruya taşınamaz', { text: 'Bütçe başkana devredilsin mi?' }, 'deny', POLL],
    ['ankette soru aynı kalırken görsel', { ...SAME_QUESTION, images: images(1, 'p01') }, 'allow', POLL],
    // Bulgu 2: askıdaki / silinmiş kulüpte yayın yasağı eski gönderi yeniden yazılarak dolanılamaz.
    ['askıdaki kulüpte düzenleme', {}, 'deny', { patch: { ...PLAIN.patch, [CLUB_PATH]: { status: 'suspended' } } }],
    ['pushSent', { pushSent: true }, 'deny'],
    ['pinned (kulüp yazımı olmadan)', { pinned: true }, 'deny'],
    ['likeCount', { likeCount: 50 }, 'deny'],
    ['commentCount', { commentCount: 0 }, 'deny'],
    ['authorId devri', { authorId: 'u_president' }, 'deny'],
    ['clubId taşıma', { clubId: OTHER_CLUB }, 'deny'],
    ['isHidden', { isHidden: true }, 'deny'],
    ['silinmiş gönderi', {}, 'deny', plain({ isDeleted: true, deletedBy: BOARD })],
  ])('%s → %s', async (_title, data, expected, edits = PLAIN) => {
    const seeded = await seedFixture('base', undefined, edits);
    await expectWrite(edit('board', data), expected);
    const post = await readDoc('posts/p01');
    if (expected === 'allow') expect(post.editedAt.toMillis()).toBe(post.updatedAt.toMillis());
    else expect(post).toMatchObject({ editedAt: null, text: seeded['posts/p01'].text });
  });

  test('istemci biçimli gönderi (null alan anahtarı yok — W-51) yazarınca düzenlenir', async () => {
    await seedFixture('base');
    await assertSucceeds(edit('president', {}, 'posts/p02'));
    expect(await readDoc('posts/p02')).toMatchObject({ text: 'Düzenlenmiş metin.', likeCount: 1, commentCount: 1 });
  });
});

describe('posts · sabitleme — `pinned` ↔ `clubs.pinnedPostId` (sözleşme §6.a 9–11)', () => {
  const PINNED = { patch: { 'posts/p01': { pinned: true }, [CLUB_PATH]: { pinnedPostId: 'p01' } } };
  const CLIENT_CLUB = { unset: { [CLUB_PATH]: ['pinnedPostId', 'logoPath', 'coverPath', 'advisor', 'suspendReason'] } };
  const pin = (extra) => payloads.pinWrites({ club: CLUB, postId: 'p02', ...extra });
  const clubWrite = (pinnedPostId, club = CLUB) => ({ op: 'update', path: `clubs/${club}`, data: { pinnedPostId, ...payloads.baseUpdate() } });
  const pinState = async () => [(await readDoc(CLUB_PATH)).pinnedPostId ?? null, (await readDoc('posts/p01')).pinned, (await readDoc('posts/p02')).pinned];

  test('pin: gönderi + kulüp tek işlemde; `pinnedPostId` anahtarı olmayan kulüp belgesinde de (W-51)', async () => {
    await seedFixture('base', undefined, CLIENT_CLUB);
    await assertSucceeds(commit('board', pin()));
    expect(await pinState()).toEqual(['p02', false, true]);
    expect((await readDoc(CLUB_PATH)).memberCount).toBe(5);
  });

  test('yeniden sabitleme: eski sabit aynı işlemde kalkar; unpin kulübü boşaltır', async () => {
    await seedFixture('base', undefined, PINNED);
    await assertSucceeds(commit('president', pin({ oldPostId: 'p01' })));
    expect(await pinState()).toEqual(['p02', false, true]);
    await assertSucceeds(commit('board', payloads.unpinWrites({ club: CLUB, postId: 'p02' })));
    expect(await pinState()).toEqual([null, false, false]);
  });

  // Satır: [başlık, bağlam, yazımlar, veri düzenlemesi?] — hepsi ret; durum değişmez.
  test.each([
    ['eski sabit kaldırılmadan ikinci gönderi sabitlenir', 'board', () => pin(), PINNED],
    ['gönderi yazılmadan `pinnedPostId` değişir', 'board', () => drop(pin(), 'post')],
    ['kulüp yazılmadan `pinned: true`', 'board', () => drop(pin(), 'club')],
    ['kulüp başka gönderiyi gösterirken `pinned: true`', 'board', () => ({ ...pin(), club: clubWrite('p01') })],
    ['kulüp olmayan gönderiyi gösterir', 'board', () => ({ club: clubWrite('p_missing') })],
    ['başka kulübün gönderisi bu kulübe sabitlenir', 'otherManager', () => ({ club: clubWrite('p02', OTHER_CLUB) })],
    ['başka kulübün yöneticisi gönderiyi kendi kulübüne sabitler (gönderi + kulüp)', 'otherManager', () => ({ ...pin(), club: clubWrite('p02', OTHER_CLUB) })],
    ['silinmiş gönderi sabitlenir', 'board', () => pin(), { patch: { 'posts/p02': { isDeleted: true, deletedBy: BOARD } } }],
    ['gizli gönderi sabitlenir', 'board', () => pin(), { patch: { 'posts/p02': { isHidden: true, hiddenBy: 'u_super' } } }],
    ['unpin: kulüp gönderiyi göstermeye devam eder', 'board', () => drop(payloads.unpinWrites({ club: CLUB, postId: 'p01' }), 'club'), PINNED],
    ['unpin: gönderi sabit kalır', 'board', () => drop(payloads.unpinWrites({ club: CLUB, postId: 'p01' }), 'post'), PINNED],
    ['sabitleme yazımı başka alan taşır (kulüp: summary)', 'board', () => ({ ...pin(), club: { op: 'update', path: CLUB_PATH, data: { pinnedPostId: 'p02', summary: 'x', ...payloads.baseUpdate() } } })],
    ['sabitleme yazımı başka alan taşır (gönderi: text)', 'board', () => ({ ...pin(), post: { op: 'update', path: 'posts/p02', data: { pinned: true, text: 'x', ...payloads.baseUpdate() } } })],
    ['süper admin sabitlemeyi (silme olmadan) kaldırır', 'super', () => payloads.unpinWrites({ club: CLUB, postId: 'p01' }), PINNED],
    ['üye sabitler', 'member', () => pin()],
  ])('%s → deny', async (_title, role, build, edits = {}) => {
    const seeded = await seedFixture('base', undefined, edits);
    await assertFails(commit(role, build()));
    expect(await pinState()).toEqual([seeded[CLUB_PATH].pinnedPostId, seeded['posts/p01'].pinned, seeded['posts/p02'].pinned]);
  });

  test('sabit gönderiyi silme: yönetici de süper admin de aynı işlemde sabitlemeyi kaldırır; tek başına silme reddedilir', async () => {
    for (const [role, uid] of [['president', 'u_president'], ['super', 'u_super']]) {
      await seedFixture('base', undefined, PINNED);
      const writes = payloads.removePostWrites({ club: CLUB, uid, postId: 'p01', pinned: true });
      await assertFails(commit(role, drop(writes, 'club')));
      await assertFails(commit(role, { post: { op: 'update', path: 'posts/p01', data: payloads.softDelete(uid) } }));
      await assertSucceeds(commit(role, writes));
      expect(await readDoc('posts/p01')).toMatchObject({ isDeleted: true, deletedBy: uid, pinned: false, commentCount: 1 });
      expect((await readDoc(CLUB_PATH)).pinnedPostId).toBeNull();
    }
  });

  // Güvenlik incelemesi (CD-141 madde 11, bulgu 5 — kabul edilen davranış, W-70): gizleme sabitlemeye
  // dokunmaz; kulüp gizlenen gönderiyi göstermeye devam eder. Üye o gönderiyi okuyamaz → akış (T-20) sabit
  // gönderi okumasındaki `permission-denied` / `notFound` sonucunu "sabit gönderi yok" sayar.
  test('sabit gönderi gizlenince işaretçi kalır: üye okuyamaz, yönetici unpin ile temizler', async () => {
    await seedFixture('base', undefined, PINNED);
    await assertSucceeds(updateDoc(doc(dbOf('super'), 'posts/p01'), payloads.hidePayload('u_super')));
    expect(await pinState()).toEqual(['p01', true, false]);
    await assertFails(getDoc(doc(dbOf('member'), 'posts/p01')));
    await assertSucceeds(commit('board', payloads.unpinWrites({ club: CLUB, postId: 'p01' })));
    expect(await pinState()).toEqual([null, false, false]);
  });

  test('silme yazımı sabitleme dışında alan taşıyamaz; geri alınan gönderi yeniden sabitlenmez', async () => {
    await seedFixture('base', undefined, PINNED);
    const writes = payloads.removePostWrites({ club: CLUB, uid: BOARD, postId: 'p01', pinned: true });
    const withText = { ...writes, post: { ...writes.post, data: { ...writes.post.data, text: 'x' } } };
    await assertFails(commit('board', withText));
    await assertSucceeds(commit('board', writes));
    await assertFails(updateDoc(doc(dbOf('board'), 'posts/p01'), { ...payloads.restore(), pinned: true }));
    await assertSucceeds(updateDoc(doc(dbOf('board'), 'posts/p01'), payloads.restore()));
    expect(await pinState()).toEqual([null, false, false]);
  });
});

describe('posts · gizleme (süper admin) — sayaç ve sabitleme değişmez', () => {
  const hide = (data) => updateDoc(doc(dbOf('super'), 'posts/p02'), data);

  test('gizle → göster: gizleyen ve sunucu zamanı yazılır, sonra ikisi null olur; istemci biçimli belgede (W-51)', async () => {
    await seedFixture('base');
    await assertSucceeds(hide(payloads.hidePayload('u_super')));
    const hidden = await readDoc('posts/p02');
    expect(hidden).toMatchObject({ isHidden: true, hiddenBy: 'u_super', commentCount: 1, likeCount: 1, pinned: false });
    expect(hidden.hiddenAt.toMillis()).toBe(hidden.updatedAt.toMillis());
    // Gizlenen gönderi üyeye kapanır, yazarına (aktif yönetici) açık kalır.
    await assertFails(getDoc(doc(dbOf('member'), 'posts/p02')));
    await assertSucceeds(getDoc(doc(dbOf('president'), 'posts/p02')));
    await assertSucceeds(hide(payloads.unhidePayload()));
    expect(await readDoc('posts/p02')).toMatchObject({ isHidden: false, hiddenBy: null, hiddenAt: null });
  });

  test.each([
    ['gizleyen başka kullanıcı', { hiddenBy: BOARD }],
    ['hiddenAt istemci saati', { hiddenAt: clientTime() }],
    ['gizlerken sayaç değişimi', { commentCount: 0 }],
    ['gizlerken silme', { isDeleted: true }],
    ['gizlerken metin değişimi', { text: 'x' }],
    ['zaten görünür gönderiyi "göster"', payloads.unhidePayload()],
  ])('%s → deny', async (_title, extra) => {
    await seedFixture('base');
    await assertFails(hide({ ...payloads.hidePayload('u_super'), ...extra }));
    expect((await readDoc('posts/p02')).isHidden).toBe(false);
  });
});

describe('activity · create — gönderi yayınının günlüğü (rules-spec §3.11; sabit kimlik CD-137 8t)', () => {
  const logPath = (kind, postId = NEW, uid = BOARD, club = CLUB) => payloads.postActivityPath(club, uid, kind, postId);
  /** Günlük yazımını ezer; `path` verilmezse kimlik ezilmiş alanlardan yeniden kurulur. */
  const withLog = (writes, extra, path) => {
    const data = { ...writes.activity.data, ...extra };
    return { ...writes, activity: { op: 'set', path: path || logPath(data.kind, data.refs.postId, BOARD, data.clubId), data } };
  };

  test.each([
    ['post', 'post_created'],
    ['announcement', 'announcement'],
    ['poll', 'poll'],
  ])('%s yayını `%s` kaydını yazar: beş alan, `refs` yalnızca postId', async (type, kind) => {
    await seedFixture('base');
    await assertSucceeds(commit('board', publish(type)));
    const entry = await readDoc(logPath(kind));
    expect(Object.keys(entry).sort()).toEqual(['actorId', 'clubId', 'createdAt', 'kind', 'refs']);
    expect(entry).toMatchObject({ clubId: CLUB, actorId: BOARD, kind, refs: { postId: NEW } });
  });

  // Satır: [başlık, yazım üreticisi] — taban: yönetim kurulu üyesinin düz gönderi yayını.
  test.each([
    ['gönderi yazılmadan günlük', () => drop(publish('post'), 'post')],
    ['var olan gönderi için günlük (yayın bu işlemde değil)', () => drop(withLog(publish('post'), { refs: { postId: 'p01' }, kind: 'poll' }), 'post')],
    ['tür ↔ kind uyuşmuyor (post → announcement)', () => withLog(publish('post'), { kind: 'announcement' })],
    ['tür ↔ kind uyuşmuyor (poll → post_created)', () => withLog(publish('poll'), { kind: 'post_created' })],
    ['serbest kimlik', () => withLog(publish('post'), {}, 'activity/a_free')],
    ['aynı işlemde ikinci günlük (serbest kimlikle)', () => ({ ...publish('post'), again: { op: 'set', path: 'activity/a_free', data: payloads.postActivity(CLUB, BOARD, 'post_created', NEW) } })],
    ['başka kulübün günlüğüne (clubId: c02)', () => withLog(publish('post'), { clubId: OTHER_CLUB })],
    ['actorId başka kullanıcı', () => withLog(publish('post'), { actorId: 'u_president' })],
    ['refs fazladan dolu alan (userId)', () => withLog(publish('post'), { refs: { postId: NEW, userId: BOARD } })],
    ['refs beyaz liste dışı anahtar', () => withLog(publish('post'), { refs: { postId: NEW, text: 'x' } })],
    ['createdAt istemci saati', () => withLog(publish('post'), { createdAt: clientTime() })],
    ['beyaz liste dışı alan', () => withLog(publish('post'), { note: 'x' })],
  ])('%s → deny', async (_title, build) => {
    await seedFixture('base');
    await assertFails(commit('board', build()));
    expect(await readDoc(logPath('post_created'))).toBeNull();
    expect(await readDoc('activity/a_free')).toBeNull();
  });

  test('başkasının yayınına günlük yazılamaz; yayından sonra aynı kayıt yeniden yazılamaz', async () => {
    await seedFixture('base');
    const writes = publish('post');
    const foreign = { op: 'set', path: logPath('post_created', NEW, 'u_president'), data: payloads.postActivity(CLUB, 'u_president', 'post_created', NEW) };
    await assertFails(commit('president', { activity: foreign }));
    await assertSucceeds(commit('board', writes));
    await assertFails(commit('president', { activity: foreign }));
    await assertFails(commit('board', { activity: writes.activity }));
  });

  test('seed biçimli `refs` (açık null alanlar — W-51) kabul edilir', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('board', withLog(publish('post'), { refs: { postId: NEW, userId: null, eventId: null, role: null } })));
  });
});
