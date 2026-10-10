'use strict';
// Rules testleri (PLAN §11.6, CD-40). Koşucu: `npm test` = firebase emulators:exec … "jest --runInBand".
// Emülatör paylaşımlı durum taşır: testler tek süreçte, sırayla koşar (--runInBand).
module.exports = {
  testEnvironment: 'node',
  testTimeout: 30000,
  setupFilesAfterEnv: ['<rootDir>/test/setup/env.js'],
  testMatch: ['<rootDir>/test/**/*.test.js'],
};
