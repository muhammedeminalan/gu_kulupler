// CD-165 b2 · süper admin dizini: claim superadmin === true ve devre dışı değil; sayfalama; 10 dk önbellek.
import { AuthSuperAdminDirectory, UserLister } from '../src/lib/super_admins';

const user = (uid: string, claims?: Record<string, unknown>, disabled = false) => ({ uid, customClaims: claims, disabled });

describe('AuthSuperAdminDirectory', () => {
  test('claim + etkin süzgeci, tüm sayfalar, önbellek süresi içinde Auth yeniden çağrılmaz', async () => {
    const pages: Record<string, { users: unknown[]; pageToken?: string }> = {
      first: { users: [user('a', { superadmin: true }), user('b', { superadmin: 'true' }), user('c')], pageToken: 'p2' },
      p2: { users: [user('d', { superadmin: true }, true), user('e', { superadmin: true, other: 1 })] },
    };
    const listUsers = jest.fn(async (_max?: number, token?: string) => pages[token ?? 'first']);
    let clock = 0;
    const dir = new AuthSuperAdminDirectory({ listUsers } as unknown as UserLister, () => clock);

    expect(await dir.list()).toEqual(['a', 'e']);
    expect(listUsers).toHaveBeenCalledTimes(2);
    clock = 10 * 60 * 1000 - 1;
    await dir.list();
    expect(listUsers).toHaveBeenCalledTimes(2);
    clock = 10 * 60 * 1000;
    await dir.list();
    expect(listUsers).toHaveBeenCalledTimes(4);
  });
});
