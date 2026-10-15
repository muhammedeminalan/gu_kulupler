// T-42 bağlama (CD-165 c, d) · sunucu ↔ istemci push sözleşmesi: firebase/test/contracts/push_contract.json.
// Aynı dosyayı Dart tarafı packages/gu_data/test/notifications/push_contract_test.dart okur (NotificationPreferenceFilter,
// NotificationNavigator.openPush ayrıştırması, FcmTokenModel). Bir taraf tek başına değişirse iki testten biri kırılır.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { Timestamp } from 'firebase-admin/firestore';
import { NotificationType, refsFrom } from '../src/lib/model';
import { allows, settingsFrom } from '../src/lib/preference_filter';
import { pushData, tokensFrom } from '../src/lib/push_payload';

interface Contract {
  preferences: Array<{
    name: string;
    settings: Record<string, unknown> | null;
    clubId: string;
    allowed: Record<string, boolean>;
  }>;
  payloads: Array<{ notificationId: string; type: NotificationType; refs: Record<string, string>; data: Record<string, string> }>;
  tokens: { stored: Array<Record<string, unknown>>; read: Array<{ token: string; locale: string }> };
}

const contract = JSON.parse(
  readFileSync(join(__dirname, '..', '..', 'firebase', 'test', 'contracts', 'push_contract.json'), 'utf8'),
) as Contract;

describe('push sözleşmesi (Dart ile ortak dosya)', () => {
  test.each(contract.preferences.map((row) => [row.name, row] as const))('tercih süzgeci — %s', (_name, row) => {
    const settings = settingsFrom(row.settings ?? undefined);
    const actual = Object.fromEntries(
      Object.keys(row.allowed).map((type) => [type, allows(type, { clubId: row.clubId }, settings)]),
    );
    expect(actual).toEqual(row.allowed);
  });

  test.each(contract.payloads.map((row) => [row.type, row] as const))('data yükü — %s', (_type, row) => {
    const data = pushData(row.notificationId, row.type, refsFrom(row.refs));
    expect(data).toEqual(row.data);
    for (const value of Object.values(data)) expect(typeof value).toBe('string');
  });

  test('jeton öğesi: sunucu istemcinin yazdığı token + locale alanını okur (locale yoksa tr)', () => {
    const stored = contract.tokens.stored.map((item) => ({
      ...item,
      updatedAt: item.updatedAt === '@now' ? Timestamp.now() : item.updatedAt,
    }));
    expect(tokensFrom(stored)).toEqual(contract.tokens.read);
  });
});
