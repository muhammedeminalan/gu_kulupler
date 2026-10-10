#!/usr/bin/env node
'use strict';
/**
 * Rules ↔ Dart parite denetimi (docs/PLAN.md §11.6, docs/firestore-rules-spec.md §1.6, §1.10).
 *   node tool/check_rules_parity.js [--root dir] [--list] [--json]
 * Statiktir: emülatör gerekmez, her kalite kapısı modunda koşar (hard-delete adımından sonra).
 * Taranır: firebase/firestore.rules, firebase/storage.rules.
 * Kaynak: packages/gu_data/lib/src/constants/{limits,email_domain_policy,firestore_fields}.dart,
 *         packages/gu_data/lib/src/core/soft_delete.dart, firebase/test/budget/*_result.json.
 *
 * Kurallar:
 *  RP01 `// limit: <ad>` etiketli satırdaki sayı/süre `Limits.<ad>` ile eşleşmiyor (ya da ad bilinmiyor)
 *  RP02 etiketsiz sayısal literal (0 ve 1 hariç) ya da etiketsiz `duration.value(n, birim)`
 *  RP03 desen paritesi: e-posta alan adı regex'i ≠ EmailDomainPolicy; etiketli desen ≠ Limits deseni
 *  RP04 soft delete anahtar listesi ≠ SoftDelete.affectedKeys − {updatedAt}
 *  RP05 Limits.notificationFanOutChunkSize ≠ firebase/test/budget/fanout_result.json#chunkSize
 *  RP06 Limits.accountDeletionChunk ≠ account_deletion_result.json#chunk ya da Rules `// budget: chunk=<N>`
 *
 * Etiket: satır sonu yorumu `// limit: ad` (aynı satırda birden çok sınır: `// limit: adMin, adMax`).
 * Süre sabitleri birimden bağımsız karşılaştırılır (`duration.value(7,'d')` = `Duration(days: 7)`);
 * `<ad>Minutes|Hours|Days|Seconds` eki süre sabitinin kendisine çözülür (`clockSkewToleranceMinutes`).
 * Rules dosyası yoksa adım uyarıyla atlanır; bütçe dosyası yoksa RP05/RP06 uyarıyla atlanır.
 * Satır içi istisna YOKTUR.
 */
const fs = require('fs');
const path = require('path');
const core = require('./lib/scan_core');
const dart = require('./lib/dart_sources');

const TITLE = 'check_rules_parity';
const RULES_FILES = ['firebase/firestore.rules', 'firebase/storage.rules'];
const FANOUT_RESULT = 'firebase/test/budget/fanout_result.json';
const ACCOUNT_DELETION_RESULT = 'firebase/test/budget/account_deletion_result.json';

const RULE_LIST = [
  ['RP01', '`// limit: <ad>` satırındaki sayı/süre Limits sabitiyle eşleşmiyor'],
  ['RP02', 'etiketsiz sayısal literal (0 ve 1 hariç) ya da etiketsiz duration.value(...)'],
  ['RP03', 'desen paritesi: e-posta alan adı regex\'i / etiketli desen Dart kaynağıyla farklı'],
  ['RP04', 'soft delete anahtar listesi SoftDelete.affectedKeys − {updatedAt} ile farklı'],
  ['RP05', 'Limits.notificationFanOutChunkSize ≠ fanout_result.json#chunkSize'],
  ['RP06', 'Limits.accountDeletionChunk ≠ account_deletion_result.json#chunk / Rules `// budget: chunk=<N>`'],
];

/** Etiketsiz kalabilen literal'ler (yalnızca 0 ve 1). */
const FREE_LITERALS = [0, 1];

/** Süre sabitine çözülen etiket ekleri. */
const UNIT_SUFFIX = /^(\w+?)(Minutes|Hours|Days|Seconds)$/;

/** Soft delete yüklerinde Rules'un `touches` ile ayrıca eklediği anahtar. */
const UPDATED_AT = 'updatedAt';

const MARKER = new RegExp(`"${core.STR_MARK}(\\d+)${core.STR_MARK}"`, 'g');
const DURATION_CALL = new RegExp(`duration\\.value\\(\\s*(\\d+)\\s*,\\s*"${core.STR_MARK}(\\d+)${core.STR_MARK}"\\s*\\)`, 'g');
const NUMBER = /(?<![\w.$])\d+(?:\.\d+)?(?![\w.])/g;
const PRODUCT = /(?<![\w.$])\d+(?:\s*\*\s*\d+)+(?![\w.])/g;
const LABEL = /\blimit:\s*([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)/;
const BUDGET = /\bbudget:\s*chunk\s*=\s*(\d+)/;

const sameSet = (a, b) => a.length === b.length && [...a].sort().join('\u0000') === [...b].sort().join('\u0000');
const fmtSeconds = (s) => `${s} sn`;

/**
 * Etiket adını Limits sabitine çözer.
 * @returns {{numbers: number[], seconds: number[], pattern: string|null}|null} bilinmeyen ad → null
 */
function resolveLabel(name, limits) {
  if (name in limits.ints) return { numbers: [limits.ints[name]], seconds: [], pattern: null };
  if (name in limits.durations) return { numbers: [], seconds: [limits.durations[name]], pattern: null };
  if (name in limits.strings) return { numbers: [], seconds: [], pattern: limits.strings[name] };
  const suffix = UNIT_SUFFIX.exec(name);
  if (name in limits.intLists) {
    // `pollDurationsDays`: gün sayıları hem düz sayı hem `duration.value(n,'d')` olarak geçebilir.
    const unit = suffix ? dart.DART_UNIT_SECONDS[suffix[2].toLowerCase()] : null;
    return {
      numbers: limits.intLists[name],
      seconds: unit ? limits.intLists[name].map((n) => n * unit) : [],
      pattern: null,
    };
  }
  if (suffix && suffix[1] in limits.durations) {
    return { numbers: [], seconds: [limits.durations[suffix[1]]], pattern: null };
  }
  return null;
}

/** Bir Rules satırının parite açısından içeriği. */
function analyzeLine(line) {
  const labelMatch = LABEL.exec(line.comment);
  const labels = labelMatch ? labelMatch[1].split(',').map((s) => s.trim()) : [];
  const durations = [];
  let code = line.code.replace(DURATION_CALL, (_, n, idx) => {
    durations.push({ n: Number(n), unit: line.strs[Number(idx)] });
    return ' ';
  });
  // `duration.value(` kalıbı çözülemediyse (değişken argüman vb.) yine de etiket ister.
  const rawDurationCall = /duration\.value\s*\(/.test(code);
  code = code.replace(MARKER, ' ');
  code = code.replace(PRODUCT, (expr) => String(dart.evalIntProduct(expr)));
  const numbers = (code.match(NUMBER) || []).map(Number);
  return { labels, durations, numbers, rawDurationCall, strs: line.strs };
}

function checkLimits(rel, lines, limits, viol) {
  lines.forEach((line, i) => {
    const info = analyzeLine(line);
    let mismatch = false;
    const push = (rule, msg) => viol.push({ file: rel, line: i + 1, rule, msg, text: line.raw });
    const pushMismatch = (msg) => {
      mismatch = true;
      push('RP01', msg);
    };
    const taggable = info.numbers.filter((n) => !FREE_LITERALS.includes(n));
    const hasDuration = info.durations.length > 0 || info.rawDurationCall;

    if (info.labels.length === 0) {
      if (taggable.length > 0) {
        push('RP02', `etiketsiz sayısal literal (${taggable.join(', ')}) → satır sonuna \`// limit: <Limits adı>\``);
      } else if (hasDuration) {
        push('RP02', 'etiketsiz duration.value(...) → satır sonuna `// limit: <Limits adı>`');
      }
      return;
    }

    const resolved = [];
    for (const name of info.labels) {
      const r = resolveLabel(name, limits);
      if (!r) push('RP01', `bilinmeyen Limits sabiti: ${name} (${dart.PATHS.limits})`);
      else resolved.push({ name, ...r });
    }
    if (resolved.length !== info.labels.length) return;

    const allowedNumbers = resolved.flatMap((r) => r.numbers);
    const allowedSeconds = resolved.flatMap((r) => r.seconds);
    const names = info.labels.join(', ');

    for (const n of taggable) {
      if (!allowedNumbers.includes(n)) {
        pushMismatch(`sayı ${n}, Limits.${names} (${allowedNumbers.join(', ') || 'sayı değil'}) ile eşleşmiyor`);
      }
    }
    const callSeconds = [];
    for (const d of info.durations) {
      const unit = dart.RULES_UNIT_SECONDS[d.unit];
      if (unit === undefined) {
        pushMismatch(`duration.value birimi tanınmıyor: '${d.unit}'`);
        continue;
      }
      const seconds = d.n * unit;
      callSeconds.push(seconds);
      if (!allowedSeconds.includes(seconds)) {
        pushMismatch(
          `süre duration.value(${d.n}, '${d.unit}') = ${fmtSeconds(seconds)}, Limits.${names} (${allowedSeconds.map(fmtSeconds).join(', ') || 'süre değil'}) ile eşleşmiyor`,
        );
      }
    }
    if (info.rawDurationCall) pushMismatch('duration.value(...) sabit sayı ve birimle yazılmalı (parite okunamıyor)');

    // Her etiketin satırda bir karşılığı olmalı (yanlış satıra kaymış / artık etiket). Değer zaten
    // eşleşmiyorsa aynı satır için ikinci bir "karşılıksız" ihlali yazılmaz.
    for (const r of resolved) {
      if (r.pattern !== null) {
        const expected = dart.toRulesLiteral(r.pattern);
        if (!info.strs.includes(expected)) {
          push('RP03', `desen Limits.${r.name} ile farklı → beklenen '${expected}'`);
        }
        continue;
      }
      if (mismatch) continue;
      const witnessed =
        r.numbers.some((n) => info.numbers.includes(n)) || r.seconds.some((s) => callSeconds.includes(s));
      if (!witnessed) {
        const expected = [...r.numbers, ...r.seconds.map(fmtSeconds)].join(' | ');
        push('RP01', `etiket ${r.name} satırda karşılıksız (beklenen ${expected})`);
      }
    }
  });
}

/**
 * Dizgi bir e-posta alan adı regex'i mi? `@` içerir ve ya kaçışlı nokta taşır (`\\.`) ya da
 * `email` alanına uygulanır. (`@` içeren başka desenler — ör. Instagram kullanıcı adı — kapsam dışıdır.)
 */
function isEmailDomainRegex(literal, code) {
  return literal.includes('@') && (literal.includes('\\\\.') || /\bemail\b/.test(code));
}

function checkEmailRegex(rel, lines, domains, viol) {
  const expected = dart.toRulesLiteral(dart.emailRulesRegex(domains));
  let found = 0;
  let helperLine = 0;
  lines.forEach((line, i) => {
    if (/\bfunction\s+(emailOk|signedInVerified)\s*\(/.test(line.code)) helperLine = helperLine || i + 1;
    for (const s of line.strs) {
      if (!isEmailDomainRegex(s, line.code)) continue;
      found += 1;
      if (s !== expected) {
        viol.push({
          file: rel, line: i + 1, rule: 'RP03', text: line.raw,
          msg: `e-posta alan adı regex'i EmailDomainPolicy.allowedDomains ile farklı → beklenen '${expected}'`,
        });
      }
    }
  });
  if (helperLine && found === 0) {
    viol.push({
      file: rel, line: helperLine, rule: 'RP03', text: lines[helperLine - 1].raw,
      msg: `e-posta yardımcı fonksiyonunda alan adı regex'i yok → beklenen '${expected}'`,
    });
  }
}

/**
 * `function <name>(…) { … }` gövdesinin birleşik kod metnindeki aralığı.
 * @returns {{from: number, to: number, line: number}|null} tanım yoksa null
 */
function functionBody(joined, name) {
  const head = new RegExp(`\\bfunction\\s+${name}\\s*\\([^)]*\\)\\s*\\{`).exec(joined.text);
  if (!head) return null;
  const from = head.index + head[0].length;
  let depth = 1;
  let to = from;
  while (to < joined.text.length && depth > 0) {
    if (joined.text[to] === '{') depth += 1;
    else if (joined.text[to] === '}') depth -= 1;
    to += 1;
  }
  return { from, to: to - 1, line: core.lineAt(joined.offs, head.index) + 1 };
}

/** Birleşik kod metninin [from, to) aralığındaki dizgi literal'lerinin içerikleri, sırayla. */
function stringsIn(lines, joined, from, to) {
  const out = [];
  const re = new RegExp(MARKER.source, 'g');
  re.lastIndex = from;
  let m;
  while ((m = re.exec(joined.text)) && m.index < to) {
    out.push(lines[core.lineAt(joined.offs, m.index)].strs[Number(m[1])]);
  }
  return out;
}

function checkSoftDeleteKeys(rel, lines, softDeleteKeys, viol) {
  const joined = core.joinCode(lines);
  const expected = softDeleteKeys.filter((k) => k !== UPDATED_AT);
  for (const name of ['isSoftDelete', 'isRestore']) {
    const fn = functionBody(joined, name);
    if (!fn) {
      viol.push({ file: rel, line: 1, rule: 'RP04', msg: `\`function ${name}\` yok (docs/firestore-rules-spec.md §2)`, text: '' });
      continue;
    }
    // touches([ … ]) çağrısının ilk liste argümanı
    const call = /touches\(\s*\[([^\]]*)\]/.exec(joined.text.slice(fn.from, fn.to));
    const keys = call ? stringsIn(lines, joined, fn.from + call.index, fn.from + call.index + call[0].length) : null;
    if (!keys || !sameSet(keys, expected)) {
      viol.push({
        file: rel, line: fn.line, rule: 'RP04', text: lines[fn.line - 1].raw,
        msg: `${name}: touches([...]) anahtarları [${(keys || []).join(', ')}] ≠ SoftDelete.affectedKeys − {updatedAt} [${expected.join(', ')}]`,
      });
    }
  }
  const touches = functionBody(joined, 'touches');
  const touchesKeys = touches ? stringsIn(lines, joined, touches.from, touches.to) : [];
  if (softDeleteKeys.includes(UPDATED_AT) && !touchesKeys.includes(UPDATED_AT)) {
    viol.push({
      file: rel, line: touches ? touches.line : 1, rule: 'RP04', text: touches ? lines[touches.line - 1].raw : '',
      msg: "`touches(keys)` izinli anahtarlara 'updatedAt' eklemiyor (SoftDelete.affectedKeys)",
    });
  }
}

function readJson(root, rel) {
  const file = path.join(root, rel);
  if (!fs.existsSync(file)) return null;
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function checkBudgets(root, limits, parsed, viol, warn) {
  const fanout = readJson(root, FANOUT_RESULT);
  if (!fanout) warn(`RP05 atlandı: ${FANOUT_RESULT} yok (T-25 bütçe ölçümü üretir)`);
  else if (fanout.chunkSize !== limits.ints.notificationFanOutChunkSize) {
    viol.push({
      file: FANOUT_RESULT, line: 1, rule: 'RP05', text: '',
      msg: `chunkSize ${fanout.chunkSize} ≠ Limits.notificationFanOutChunkSize ${limits.ints.notificationFanOutChunkSize}`,
    });
  }

  const expected = limits.ints.accountDeletionChunk;
  for (const { rel, lines } of parsed) {
    lines.forEach((line, i) => {
      const m = BUDGET.exec(line.comment);
      if (m && Number(m[1]) !== expected) {
        viol.push({
          file: rel, line: i + 1, rule: 'RP06', text: line.raw,
          msg: `\`// budget: chunk=${m[1]}\` ≠ Limits.accountDeletionChunk ${expected}`,
        });
      }
    });
  }
  const deletion = readJson(root, ACCOUNT_DELETION_RESULT);
  if (!deletion) warn(`RP06 atlandı: ${ACCOUNT_DELETION_RESULT} yok (T-29 bütçe ölçümü üretir)`);
  else if (deletion.chunk !== expected) {
    viol.push({
      file: ACCOUNT_DELETION_RESULT, line: 1, rule: 'RP06', text: '',
      msg: `chunk ${deletion.chunk} ≠ Limits.accountDeletionChunk ${expected}`,
    });
  }
}

function main(argv) {
  if (argv.includes('--list')) {
    for (const [id, msg] of RULE_LIST) console.log(`${id}\t${msg}`);
    return 0;
  }
  const root = core.projectRoot(argv);
  const json = argv.includes('--json');
  // Uyarılar kapı günlüğünde `UYARI` önekiyle görünür; --json çıktısını bozmaması için stderr'e gider.
  const warn = (msg) => (json ? console.error : console.log)(`UYARI: ${msg}`);

  const present = RULES_FILES.filter((rel) => fs.existsSync(path.join(root, rel)));
  if (present.length === 0) {
    warn(`Rules dosyası yok (${RULES_FILES.join(', ')}) — parite denetimi atlandı`);
    return core.report([], argv, TITLE);
  }
  for (const rel of RULES_FILES) if (!present.includes(rel)) warn(`${rel} yok — bu dosya atlandı`);

  const limits = dart.readLimits(root);
  const domains = dart.readEmailDomains(root);
  const softDeleteKeys = dart.readSoftDeleteKeys(root);

  const viol = [];
  const parsed = present.map((rel) => ({
    rel,
    lines: core.parse(fs.readFileSync(path.join(root, rel), 'utf8'), {}),
  }));
  for (const { rel, lines } of parsed) {
    checkLimits(rel, lines, limits, viol);
    checkEmailRegex(rel, lines, domains, viol);
    if (rel.endsWith('firestore.rules')) checkSoftDeleteKeys(rel, lines, softDeleteKeys, viol);
  }
  checkBudgets(root, limits, parsed, viol, warn);
  return core.report(viol, argv, TITLE);
}

try {
  process.exit(main(process.argv.slice(2)));
} catch (error) {
  console.error(`${TITLE}: ${error.message}`);
  process.exit(2);
}
