// Uçtan uca (T-42 bağlama): `npm run test:e2e` — Functions emülatörü (firebase.functions-test.json: auth 9170,
// Firestore 8090, functions 5011) açıkken GERÇEK bağlı tetikleyiciler; gönderici LoggingPushSender (FCM'e gidilmez).
/** @type {import('jest').Config} */
module.exports = {
  testEnvironment: 'node',
  roots: ['<rootDir>/e2e'],
  testMatch: ['**/*.e2e.test.ts'],
  testTimeout: 60000,
  transform: { '^.+\\.ts$': ['ts-jest', { tsconfig: 'tsconfig.test.json' }] },
};
