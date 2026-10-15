// CD-165 c · sessiz saat: Europe/Istanbul, [from, to), gece yarısı aşımı, from == to → sessiz değil.
import { settingsFrom } from '../src/lib/preference_filter';
import { isQuietNow } from '../src/lib/quiet_hours';

// Istanbul = UTC+3 (yaz saati yok): yerel saat → UTC anı.
const at = (local: string) => new Date(`2026-10-15T${local}:00+03:00`);
const quiet = (from: string, to: string, local: string, on = true) =>
  isQuietNow(settingsFrom({ quiet: on, quietFrom: from, quietTo: to }), at(local));

describe('quiet_hours', () => {
  test('gece yarısını aşan aralık [22:00, 08:00)', () => {
    expect([quiet('22:00', '08:00', '21:59'), quiet('22:00', '08:00', '22:00'), quiet('22:00', '08:00', '03:00')]).toEqual([
      false,
      true,
      true,
    ]);
    expect([quiet('22:00', '08:00', '07:59'), quiet('22:00', '08:00', '08:00')]).toEqual([true, false]);
  });

  test('gün içi aralık, from == to, kapalı anahtar ve bozuk biçim → sessiz değil', () => {
    expect([quiet('13:00', '14:00', '13:30'), quiet('13:00', '14:00', '14:00')]).toEqual([true, false]);
    expect(quiet('09:00', '09:00', '09:00')).toBe(false);
    expect(quiet('22:00', '08:00', '23:00', false)).toBe(false);
    expect(quiet('24:00', '08:00', '01:00')).toBe(false);
  });

  test('saat dilimi Istanbul: 19:30 UTC = 22:30 yerel → sessiz', () => {
    const s = settingsFrom({ quiet: true });
    expect(isQuietNow(s, new Date('2026-10-15T19:30:00Z'))).toBe(true);
    expect(isQuietNow(s, new Date('2026-10-15T18:30:00Z'))).toBe(false);
  });
});
