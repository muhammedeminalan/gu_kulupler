'use strict';
// tool/admin koşucularının saf testleri için bellek içi Firestore (Admin SDK'nın kullanılan alt kümesi). Test dosyası
// değildir (`*.test.js` değil). `firebase-admin` yüklenmez; betikler ÇALIŞTIRILMAZ.
//
// Desteklenen: doc(path).get() (+ updateTime) · collection(c).where(f, '==', v).orderBy(documentId()).startAfter(snap)
// .limit(n).get() · query.count().get() · batch().update(ref, data, {lastUpdateTime}) / set · commit (atomik; önkoşul
// tutmazsa `FAILED_PRECONDITION` (9), belge yoksa `NOT_FOUND` (5)). Her sorgu `queries`'e, her commit `commits`'e yazılır.

const DOC_ID = Object.freeze({ fake: '__name__' });
const SERVER_TS = Object.freeze({ fake: 'serverTimestamp' });

/** Hem belge sürümü (`updateTime`) hem veri içi zaman (Admin SDK `Timestamp` gibi `toDate()` taşır). */
class FakeTimestamp {
  constructor(ms) {
    this.ms = ms;
  }
  isEqual(other) {
    return other instanceof FakeTimestamp && other.ms === this.ms;
  }
  toDate() {
    return new Date(this.ms);
  }
}

const fieldValue = Object.freeze({
  serverTimestamp: () => SERVER_TS,
  increment: (n) => ({ fakeIncrement: n }),
});

function clone(value) {
  if (value instanceof FakeTimestamp) return value;
  if (Array.isArray(value)) return value.map(clone);
  if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, clone(v)]));
  return value;
}

function apply(doc, data, at) {
  const out = clone(doc) || {};
  for (const [key, value] of Object.entries(data)) {
    const parts = key.split('.');
    let target = out;
    for (const part of parts.slice(0, -1)) {
      if (!target[part] || typeof target[part] !== 'object') target[part] = {};
      target = target[part];
    }
    const leaf = parts[parts.length - 1];
    if (value === SERVER_TS) target[leaf] = new FakeTimestamp(at);
    else if (value && typeof value.fakeIncrement === 'number') target[leaf] = (target[leaf] || 0) + value.fakeIncrement;
    else target[leaf] = clone(value);
  }
  return out;
}

class FakeQuery {
  constructor(db, collection, spec = {}) {
    this.db = db;
    this.collectionId = collection;
    this.spec = { filters: [], order: false, after: null, limit: null, ...spec };
  }
  with(change) {
    return new FakeQuery(this.db, this.collectionId, { ...this.spec, ...change });
  }
  where(field, op, value) {
    if (op !== '==') throw new Error(`desteklenmeyen işleç: ${op}`);
    return this.with({ filters: [...this.spec.filters, [field, value]] });
  }
  orderBy(field) {
    if (field !== DOC_ID) throw new Error('yalnızca documentId() sırası');
    return this.with({ order: true });
  }
  startAfter(snapshot) {
    return this.with({ after: snapshot.id });
  }
  limit(n) {
    return this.with({ limit: n });
  }
  matching() {
    return [...this.db.store.entries()]
      .filter(([path]) => path.split('/').length === 2 && path.startsWith(`${this.collectionId}/`))
      .map(([path, entry]) => ({ path, id: path.split('/')[1], ...entry }))
      .filter((d) => this.spec.filters.every(([field, value]) => d.data[field] === value))
      .sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  }
  async get() {
    let docs = this.matching();
    if (this.spec.after !== null) docs = docs.filter((d) => d.id > this.spec.after);
    if (this.spec.limit !== null) docs = docs.slice(0, this.spec.limit);
    this.db.queries.push({ collection: this.collectionId, filters: this.spec.filters, limit: this.spec.limit, returned: docs.length });
    const snaps = docs.map((d) => this.db.snapshot(d.path));
    return { docs: snaps, size: snaps.length, empty: snaps.length === 0 };
  }
  count() {
    return {
      get: async () => {
        const count = this.matching().length;
        this.db.queries.push({ collection: this.collectionId, filters: this.spec.filters, count: true, returned: 0 });
        return { data: () => ({ count }) };
      },
    };
  }
}

class FakeBatch {
  constructor(db) {
    this.db = db;
    this.ops = [];
  }
  update(ref, data, precondition) {
    this.ops.push({ op: 'update', path: ref.path, data, precondition });
    return this;
  }
  set(ref, data) {
    this.ops.push({ op: 'set', path: ref.path, data });
    return this;
  }
  async commit() {
    if (this.db.beforeCommit) await this.db.beforeCommit(this.ops.map((o) => o.path));
    for (const { op, path, precondition } of this.ops) {
      const entry = this.db.store.get(path);
      if (op === 'update' && !entry) throw Object.assign(new Error(`NOT_FOUND ${path}`), { code: 5 });
      if (precondition && precondition.lastUpdateTime && !(entry && entry.updateTime.isEqual(precondition.lastUpdateTime))) {
        this.db.commits.push({ paths: this.ops.map((o) => o.path), rejected: true });
        throw Object.assign(new Error(`FAILED_PRECONDITION ${path}`), { code: 9 });
      }
    }
    const at = this.db.nextTick();
    for (const { op, path, data } of this.ops) {
      const current = this.db.store.get(path);
      const base = op === 'set' ? {} : current.data;
      this.db.store.set(path, { data: apply(base, data, at), updateTime: new FakeTimestamp(at) });
    }
    this.db.commits.push({
      paths: this.ops.map((o) => o.path),
      preconditioned: this.ops.map((o) => !!(o.precondition && o.precondition.lastUpdateTime)),
      rejected: false,
    });
  }
}

class FakeFirestore {
  /** @param {Record<string, object>} docs yol → veri */
  constructor(docs = {}) {
    this.store = new Map();
    this.tick = 1_000;
    this.queries = [];
    this.commits = [];
    this.beforeCommit = null;
    for (const [path, data] of Object.entries(docs)) this.put(path, data);
  }
  nextTick() {
    this.tick += 1;
    return this.tick;
  }
  /** Testin doğrudan yazımı (eşzamanlı istemci): yeni sürüm. */
  put(path, data) {
    this.store.set(path, { data: clone(data), updateTime: new FakeTimestamp(this.nextTick()) });
  }
  patch(path, data) {
    const at = this.nextTick();
    this.store.set(path, { data: apply(this.store.get(path).data, data, at), updateTime: new FakeTimestamp(at) });
  }
  data(path) {
    const entry = this.store.get(path);
    return entry ? clone(entry.data) : undefined;
  }
  snapshot(path) {
    const entry = this.store.get(path);
    const id = path.split('/').pop();
    const ref = this.doc(path);
    if (!entry) return { id, ref, exists: false, data: () => undefined, updateTime: undefined };
    return { id, ref, exists: true, data: () => clone(entry.data), updateTime: entry.updateTime };
  }
  doc(path) {
    return { path, id: path.split('/').pop(), get: async () => this.snapshot(path) };
  }
  collection(name) {
    return new FakeQuery(this, name);
  }
  batch() {
    return new FakeBatch(this);
  }
}

FakeFirestore.documentId = () => DOC_ID;

module.exports = { FakeFirestore, FakeTimestamp, fieldValue };
