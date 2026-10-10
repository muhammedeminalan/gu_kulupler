'use strict';
/**
 * Türkçe küçük harf dönüşümü (CD-11): önce `İ → i` ve `I → ı`, sonra `toLowerCase()`.
 * gu_ui `trLower()` ve packages/gu_data/test/fixtures/demo_data.dart `_trLower` ile aynı sonucu verir;
 * `nameLower` alanları (users, clubs) bununla üretilir. Yerel ayardan bağımsızdır.
 * @param {string} text
 * @returns {string}
 */
function trLower(text) {
  return text.replace(/İ/g, 'i').replace(/I/g, 'ı').toLowerCase();
}

module.exports = { trLower };
