import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/src/extensions/string_x.dart';

void main() {
  group('T-01 · TurkishCaseX trLower / trUpper (PLAN §7.14, CD-11)', () {
    test("'ISPARTA'.trLower() == 'ısparta'", () {
      expect('ISPARTA'.trLower(), 'ısparta');
    });

    test("'İSTANBUL'.trLower() == 'istanbul' (birleşik nokta yok)", () {
      final lower = 'İSTANBUL'.trLower();
      expect(lower, 'istanbul');
      expect(lower.length, 8);
      expect(lower.contains('̇'), isFalse);
    });

    test("'istanbul'.trUpper() == 'İSTANBUL'", () {
      expect('istanbul'.trUpper(), 'İSTANBUL');
    });

    test("'ığdır'.trUpper() == 'IĞDIR'", () {
      expect('ığdır'.trUpper(), 'IĞDIR');
    });

    test('diğer Türkçe harfler ve karışık metin', () {
      expect('çağşöü'.trUpper(), 'ÇAĞŞÖÜ');
      expect('ÇAĞŞÖÜ'.trLower(), 'çağşöü');
      expect('Iğdır İli'.trLower(), 'ığdır ili');
      expect('kılıç'.trUpper(), 'KILIÇ');
    });

    test('gidiş-dönüş Türkçe harfleri korur', () {
      const words = ['istanbul', 'ısparta', 'ığdır', 'şişli', 'çiğdem'];
      for (final w in words) {
        expect(w.trUpper().trLower(), w, reason: w);
      }
    });

    test('boş metin değişmez', () {
      expect(''.trUpper(), '');
      expect(''.trLower(), '');
    });
  });

  group('T-01 · TurkishCaseX upperFor (PLAN §7.10)', () {
    test("'istanbul'.upperFor(tr) == 'İSTANBUL'", () {
      expect('istanbul'.upperFor(const Locale('tr')), 'İSTANBUL');
    });

    test("'istanbul'.upperFor(en) == 'ISTANBUL'", () {
      expect('istanbul'.upperFor(const Locale('en')), 'ISTANBUL');
    });

    test('ülke kodu dil seçimini değiştirmez', () {
      expect('bugün'.upperFor(const Locale('tr', 'TR')), 'BUGÜN');
      expect('dün'.upperFor(const Locale('en', 'US')), 'DÜN');
      expect('ilk'.upperFor(const Locale('en', 'TR')), 'ILK');
    });
  });

  group('T-01 · TurkishCaseX initials (core.js:422)', () {
    test("'Ayşe Demir'.initials == 'AD'", () {
      expect('Ayşe Demir'.initials, 'AD');
    });

    test("boş ve yalnız boşluk → '?'", () {
      expect(''.initials, '?');
      expect('  '.initials, '?');
      expect('\t\n '.initials, '?');
    });

    test('tek kelime → ilk harf, Türkçe büyük', () {
      expect('ayşe'.initials, 'A');
      expect('ilkay'.initials, 'İ');
      expect('ışık'.initials, 'I');
      expect('?'.initials, '?');
    });

    test('3 kelime → ilk ve son kelimenin ilk harfi', () {
      expect('Mehmet Ali Yılmaz'.initials, 'MY');
      expect('ilker can işık'.initials, 'İİ');
    });

    test('baştaki/sondaki ve çoklu boşluklar yok sayılır', () {
      expect('  zeynep   öztürk  '.initials, 'ZÖ');
      expect('çağla\tşen'.initials, 'ÇŞ');
    });
  });
}
