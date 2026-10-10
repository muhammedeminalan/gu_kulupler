'use strict';
// Tohuma göre düz renkli yer tutucu PNG üretir (PLAN §9.12 `posts.images`). Bağımlılık yok: Node `zlib`.
// Paletli (renk tipi 3, 8 bit) tek renk: 1200×900 görsel birkaç yüz bayttır.
const zlib = require('zlib');

const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const DEFAULT_WIDTH = 1200;
const DEFAULT_HEIGHT = 900;
const COLOR_TYPE_PALETTE = 3;
const BIT_DEPTH = 8;

const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n += 1) {
    let c = n;
    for (let k = 0; k < 8; k += 1) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c >>> 0;
  }
  return table;
})();

function crc32(buffer) {
  let crc = 0xffffffff;
  for (const byte of buffer) crc = CRC_TABLE[(crc ^ byte) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const head = Buffer.alloc(8);
  head.writeUInt32BE(data.length, 0);
  head.write(type, 4, 'ascii');
  const tail = Buffer.alloc(4);
  tail.writeUInt32BE(crc32(Buffer.concat([head.subarray(4), data])), 0);
  return Buffer.concat([head, data, tail]);
}

/** 32 bit FNV-1a özeti. */
function fnv1a(text) {
  let hash = 0x811c9dc5;
  for (const unit of Buffer.from(text, 'utf8')) hash = Math.imul(hash ^ unit, 0x01000193) >>> 0;
  return hash;
}

/** Tohumdan türetilen renk: [r, g, b]. */
function colorOf(seed) {
  const hash = fnv1a(seed);
  return [(hash >>> 16) & 0xff, (hash >>> 8) & 0xff, hash & 0xff];
}

/**
 * Düz renkli PNG.
 * @param {string} seed renk tohumu (aynı tohum → aynı bayt dizisi)
 * @param {number} [width=1200]
 * @param {number} [height=900]
 * @returns {Buffer}
 */
function placeholderPng(seed, width = DEFAULT_WIDTH, height = DEFAULT_HEIGHT) {
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header[8] = BIT_DEPTH;
  header[9] = COLOR_TYPE_PALETTE;
  // sıkıştırma 0, süzgeç 0, geçmeli tarama yok
  // Her satır: süzgeç baytı (0) + piksel başına palet dizini (0).
  const rows = Buffer.alloc(height * (width + 1));
  return Buffer.concat([
    PNG_SIGNATURE,
    chunk('IHDR', header),
    chunk('PLTE', Buffer.from(colorOf(seed))),
    chunk('IDAT', zlib.deflateSync(rows, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

module.exports = { DEFAULT_WIDTH, DEFAULT_HEIGHT, placeholderPng, colorOf, crc32 };
