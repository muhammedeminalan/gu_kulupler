'use strict';
/**
 * Yerel admin paneli (tool/admin/panel.js) — çalıştırılabilir betiklerin beyaz listesi ve argüman kurucusu (saf;
 * firebase-admin yüklemez; tool/test ile sınanır).
 *
 * Panel betikleri değiştirmeden alt süreç olarak çalıştırır: hedef proje / anahtar / emülatör seçimi panele aittir
 * (`--project`, `--key`, `--emulator` arayüzden verilemez), `--yes` yalnızca "Uygula" ile eklenir. Değerler tek
 * satırlık düz metindir; kabuk kullanılmaz (argüman dizisi).
 */

/**
 * Betik kimliği → dosya, başlık, izinli değer / bayrak argümanları (betiklerin SPEC'iyle aynı; parite testi).
 * `omitted`: betikte olup panelde bilinçli olarak verilmeyen argümanlar.
 */
const SCRIPTS = Object.freeze({
  stats: { file: 'stats.js', title: 'İstatistik', values: [], flags: ['--json'] },
  userinfo: { file: 'user_info.js', title: 'Kullanıcı bilgisi', values: ['--email', '--uid'], flags: ['--json'] },
  remoteconfig: { file: 'set_remote_config.js', title: 'Bakım ve güncelleme', values: ['--maintenance', '--min-build'], flags: ['--maintenance-off'] },
  superadmin: { file: 'set_superadmin.js', title: 'Süper admin', values: ['--uid', '--email'], flags: ['--revoke', '--list'] },
  push: { file: 'send_push.js', title: 'Push bildirimi', values: ['--title', '--body', '--email'], flags: ['--all'] },
  system: { file: 'send_system_notification.js', title: 'Sistem bildirimi', values: ['--text-key', '--email'], flags: ['--all'] },
  advisor: { file: 'set_advisor.js', title: 'Danışman', values: ['--club', '--email'], flags: ['--remove'] },
  review: { file: 'create_review_account.js', title: 'İnceleme hesabı', values: ['--email'], flags: ['--reset-password'] },
  deletion: { file: 'finish_account_deletion.js', title: 'Hesap silme temizliği', values: ['--uid'], flags: ['--all-deleted'] },
  // `--bucket` panelde verilmez: varsayılan kova (<proje>.firebasestorage.app).
  demo: { file: 'seed_demo_content.js', title: 'Demo içerik', values: [], flags: [], omitted: ['--bucket'] },
});

/** Panelin kendisinin yönettiği argümanlar (arayüzden gelemez). */
const RESERVED = Object.freeze(['--project', '--key', '--emulator', '--yes', '--help', '-h']);
const VALUE_MAX = 500;

/**
 * Arayüz isteğinden betik argümanlarını kurar; geçersiz istekte hata.
 * @param {string} id SCRIPTS anahtarı
 * @param {{values?: Record<string, string>, flags?: string[]}} input
 * @param {boolean} apply `true` → `--yes` eklenir
 * @returns {{file: string, args: string[]}}
 */
function buildArgs(id, input, apply) {
  const script = Object.prototype.hasOwnProperty.call(SCRIPTS, id) ? SCRIPTS[id] : null;
  if (!script) throw new Error(`bilinmeyen betik: ${id}`);
  const args = [];
  for (const [flag, raw] of Object.entries(input?.values || {})) {
    if (RESERVED.includes(flag) || !script.values.includes(flag)) throw new Error(`izinsiz argüman: ${flag}`);
    const value = typeof raw === 'string' ? raw.trim() : '';
    if (!value) continue;
    if (value.length > VALUE_MAX) throw new Error(`${flag} en çok ${VALUE_MAX} karakter`);
    if (/[\r\n\0]/.test(value)) throw new Error(`${flag} tek satır olmalı`);
    if (value.startsWith('-')) throw new Error(`${flag} değeri '-' ile başlayamaz`);
    args.push(flag, value);
  }
  for (const flag of input?.flags || []) {
    if (RESERVED.includes(flag) || !script.flags.includes(flag)) throw new Error(`izinsiz bayrak: ${flag}`);
    if (!args.includes(flag)) args.push(flag);
  }
  if (apply) args.push('--yes');
  return { file: script.file, args };
}

/** Panel onayı: elle yazılan proje kimliği hedefle birebir aynı mı (boşluk kırpılır). */
const confirmOk = (answer, projectId) => typeof answer === 'string' && answer.trim() === projectId;

module.exports = { SCRIPTS, RESERVED, VALUE_MAX, buildArgs, confirmOk };
