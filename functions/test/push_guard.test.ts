// T-45 S2-01 / A5-03 · push freni kapsam kilidi (push_guard.ts). Tekrarlanabilen karar türleri (M9 ↔ M12b çıkar / geri
// al, M5 / M6 ↔ M12a karar / geri al, M10 rol aç-kapa) artık (tür, kulüp, alıcı) başına Istanbul günü başına bir push'la
// sınırlı (T-42 CD-165 sunucu freni kalıbı); gelen kutusu belgesi değişmez.
import { gateIdFor, GATE_PREFIX, istanbulDay } from '../src/lib/push_guard';

const now = new Date('2026-10-15T12:00:00+03:00');
const refs = { clubId: 'c01', eventId: 'e01', applicantId: 'u_app', role: 'board' };

const DECISIONS = ['removed_from_club', 'role_changed', 'application_approved', 'application_rejected'];

describe('gateIdFor', () => {
  test.each(['event_new', 'application_received', 'new_report'])('%s kapsam kilitlidir', (type) => {
    const id = gateIdFor(type, refs, 'u1', 'member', now);
    expect(id).not.toBeNull();
    expect(id?.startsWith(`${GATE_PREFIX}${type}_`)).toBe(true);
  });

  test.each(DECISIONS)('%s: (tür, kulüp, alıcı) başına Istanbul günü başına tek kilit', (type) => {
    const id = gateIdFor(type, refs, 'u1', 'unchecked', now);
    expect(id).toMatch(new RegExp(`^${GATE_PREFIX}${type}_[0-9a-f]{20}_u1$`));
    // Aynı gün (rol / saat farkı) → aynı kilit: döngünün ikinci turu `throttled`.
    expect(gateIdFor(type, { ...refs, role: 'member' }, 'u1', 'unchecked', new Date('2026-10-15T23:59:00+03:00'))).toBe(id);
    expect(gateIdFor(type, refs, 'u1', 'unchecked', new Date('2026-10-15T00:00:00+03:00'))).toBe(id);
    // Başka kulüp, başka alıcı, ertesi Istanbul günü → ayrı kilit.
    expect(gateIdFor(type, { ...refs, clubId: 'c02' }, 'u1', 'unchecked', now)).not.toBe(id);
    expect(gateIdFor(type, refs, 'u2', 'unchecked', now)).not.toBe(id);
    expect(gateIdFor(type, refs, 'u1', 'unchecked', new Date('2026-10-16T00:00:00+03:00'))).not.toBe(id);
  });

  test('karar türleri birbirinin kilidini paylaşmaz (tür kimlikte)', () => {
    const ids = DECISIONS.map((type) => gateIdFor(type, refs, 'u1', 'unchecked', now));
    expect(new Set(ids).size).toBe(DECISIONS.length);
  });

  test.each(['announcement', 'event_cancelled', 'waitlist_promoted', 'report_resolved', 'system'])(
    '%s kilitsiz (tek seferlik olay ya da Rules bağı)',
    (type) => {
      expect(gateIdFor(type, refs, 'u1', 'unchecked', now)).toBeNull();
    },
  );

  test('Istanbul günü UTC gece yarısıyla değil yerel gece yarısıyla döner', () => {
    expect(istanbulDay(new Date('2026-10-15T20:59:00Z'))).toBe('2026-10-15');
    expect(istanbulDay(new Date('2026-10-15T21:00:00Z'))).toBe('2026-10-16');
  });
});
