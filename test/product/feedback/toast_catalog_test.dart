// T-07 · ToastId + ToastCatalog ↔ registry.json#toasts (K-44, KAT01–KAT04).
// Beklentiler registry / ARB / task-map'ten okunur; literal tasarım kimliği
// yazılmaz (TEST01 kanıtı sayılmasın).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/design_files.dart';
import '../../helpers/design_ids.dart';
import '../../helpers/test_l10n.dart';

/// Registry `textTr` örnek değerleri (`dialogs.js` `sample` + yakalama):
/// alan adları ARB yer tutucuları.
const ToastParams _sample = ToastParams(
  name: 'Ayşe Demir',
  no: '#GU-4821',
  what: '…',
  role: '…',
  title: '…',
  s: '42',
  date: '…',
  n: 2,
  count: 3,
);

/// [_sample] + tüm seçenek bayrakları açık.
const ToastParams _flagged = ToastParams(
  name: 'Ayşe Demir',
  no: '#GU-4821',
  what: '…',
  role: '…',
  title: '…',
  s: '42',
  date: '…',
  n: 2,
  count: 3,
  unblocked: true,
  saved: true,
  off: true,
  suspended: true,
  pinned: true,
  open: true,
);

const Map<String, Object> _sampleValues = {
  'name': 'Ayşe Demir',
  'no': '#GU-4821',
  'what': '…',
  'role': '…',
  'title': '…',
  's': '42',
  'date': '…',
  'n': 2,
  'count': 3,
};

String _fill(String arbValue) => arbValue.replaceAllMapped(
  RegExp(r'\{(\w+)\}'),
  (m) => '${_sampleValues[m.group(1)]!}',
);

void main() {
  final registry =
      (readJsonMap('design/extracted/registry.json')['toasts'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
  final excluded =
      ((readJsonMap('docs/task-map.json')['excluded']
                  as Map<String, dynamic>)['toasts']
              as Map<String, dynamic>)
          .keys
          .toSet();
  final byId = {for (final t in registry) t['id'] as String: t};
  final arbTr = readJsonMap('lib/l10n/app_tr.arb');
  final arbEn = readJsonMap('lib/l10n/app_en.arb');

  late AppLocalizations tr;
  late AppLocalizations en;
  setUpAll(() async {
    tr = await loadL10n(const Locale('tr'));
    en = await loadL10n(const Locale('en'));
  });

  group('T-07 · ToastId', () {
    test('registry 78 kimlik → 77 üye; muaf tek kimlik task-map#excluded', () {
      expect(DesignIds.toasts, hasLength(78));
      expect(excluded, hasLength(1));
      expect(DesignIds.toasts, containsAll(excluded));
      expect(ToastId.values, hasLength(77));
      expect(
        ToastId.values.map((e) => e.designId).toSet(),
        DesignIds.toasts.toSet().difference(excluded),
      );
    });

    test('üye adı kuralı: önek küçük harf + numara (pack_data.enumMember)', () {
      for (final id in ToastId.values) {
        final designId = id.designId;
        expect(
          id.name,
          designId.substring(0, 3).toLowerCase() + designId.substring(4),
        );
        expect(designId, matches(RegExp(r'^TST-X?\d{1,2}$')));
      }
    });

    test('her üyenin üstünde kendi `/// Design:` izi', () {
      final traces = parseEnumDesignTraces(
        readText('lib/product/feedback/toast_id.dart'),
      );
      expect(traces, {for (final id in ToastId.values) id.name: id.designId});
    });
  });

  group('T-07 · ToastCatalog', () {
    test('77 kayıt: her ToastId için bir ToastSpec', () {
      expect(ToastCatalog.specs.keys, ToastId.values);
      for (final id in ToastId.values) {
        expect(ToastCatalog.of(id), same(ToastCatalog.specs[id]));
      }
    });

    test('tür her kimlikte registry ile aynı; sayılar 37 / 3 / 37', () {
      final counts = <GuToastKind, int>{};
      for (final id in ToastId.values) {
        final spec = ToastCatalog.of(id);
        expect(spec.kind.name, byId[id.designId]!['kind'], reason: id.designId);
        counts[spec.kind] = (counts[spec.kind] ?? 0) + 1;
      }
      final registryCounts = <String, int>{};
      for (final t in registry.where((t) => !excluded.contains(t['id']))) {
        final kind = t['kind'] as String;
        registryCounts[kind] = (registryCounts[kind] ?? 0) + 1;
      }
      expect({
        for (final e in counts.entries) e.key.name: e.value,
      }, registryCounts);
      expect(counts, {
        GuToastKind.success: 37,
        GuToastKind.error: 3,
        GuToastKind.info: 37,
      });
    });

    test('eylem etiketi registry ile aynı (15); eylemliler undo süre türü', () {
      var withAction = 0;
      var undo = 0;
      for (final id in ToastId.values) {
        final spec = ToastCatalog.of(id);
        final expected = byId[id.designId]!['actionLabelTr'] as String?;
        expect(spec.actionLabel?.call(tr), expected, reason: id.designId);
        if (expected == null) {
          expect(spec.durationKind, ToastDurationKind.standard);
          expect(spec.undoAction, isFalse);
          continue;
        }
        withAction++;
        expect(spec.durationKind, ToastDurationKind.undo, reason: id.designId);
        expect(spec.actionLabel!(en), isNotEmpty, reason: id.designId);
        expect(spec.undoAction, expected == tr.commonUndo, reason: id.designId);
        expect(spec.actionKeyName, spec.undoAction ? 'undo' : 'action');
        if (spec.undoAction) undo++;
      }
      expect(withAction, 15);
      expect(undo, 9);
    });

    test('persistent registry ile aynı (hepsi false)', () {
      for (final id in ToastId.values) {
        expect(
          ToastCatalog.of(id).persistent,
          byId[id.designId]!['persistent'],
          reason: id.designId,
        );
      }
    });

    test('süre türleri GuMotion değerleridir (4 sn / 6 sn)', () {
      expect(ToastDurationKind.standard.duration, GuMotion.toastDefault);
      expect(ToastDurationKind.undo.duration, GuMotion.toastUndo);
      expect(GuMotion.toastDefault, const Duration(seconds: 4));
      expect(GuMotion.toastUndo, const Duration(seconds: 6));
    });

    test(
      'TR metni registry textTr ile aynı; EN metni dolu ve yer tutucusuz',
      () {
        for (final id in ToastId.values) {
          final spec = ToastCatalog.of(id);
          expect(
            spec.text(tr, _sample),
            byId[id.designId]!['textTr'],
            reason: id.designId,
          );
          final english = spec.text(en, _sample);
          expect(english.trim(), isNotEmpty, reason: id.designId);
          expect(english, isNot(contains('{')), reason: id.designId);
          expect(spec.text(tr, const ToastParams()).trim(), isNotEmpty);
          expect(spec.text(en, const ToastParams()).trim(), isNotEmpty);
        }
      },
    );

    test('seçenekli 8 toast: iki metin de ARB çiftiyle aynı (TR + EN)', () {
      var variants = 0;
      for (final id in ToastId.values) {
        final spec = ToastCatalog.of(id);
        // ARB'de `<üye><Sonek>` biçimli iki anahtar → seçenekli toast.
        final keys = arbTr.keys
            .where((k) => RegExp('^${id.name}[A-Z]').hasMatch(k))
            .toList();
        if (keys.isEmpty) {
          expect(
            spec.text(tr, _flagged),
            spec.text(tr, _sample),
            reason: '${id.designId} seçeneksiz',
          );
          continue;
        }
        variants++;
        expect(keys, hasLength(2), reason: id.designId);
        for (final (l10n, arb) in [(tr, arbTr), (en, arbEn)]) {
          final texts = {spec.text(l10n, _sample), spec.text(l10n, _flagged)};
          expect(texts, hasLength(2), reason: id.designId);
          expect(
            texts,
            {for (final k in keys) _fill(arb[k] as String)},
            reason: id.designId,
          );
        }
      }
      expect(variants, 8);
    });
  });

  group('T-07 · ToastParams', () {
    test('varsayılanlar ve değer eşitliği (tüm alanlar props içinde)', () {
      const base = ToastParams();
      expect(base.name, isEmpty);
      expect(base.n, 1);
      expect(base.count, 0);
      expect(base, const ToastParams());
      const variants = [
        ToastParams(name: 'a'),
        ToastParams(no: 'a'),
        ToastParams(what: 'a'),
        ToastParams(role: 'a'),
        ToastParams(title: 'a'),
        ToastParams(s: 'a'),
        ToastParams(date: 'a'),
        ToastParams(n: 2),
        ToastParams(count: 2),
        ToastParams(unblocked: true),
        ToastParams(saved: true),
        ToastParams(off: true),
        ToastParams(suspended: true),
        ToastParams(pinned: true),
        ToastParams(open: true),
      ];
      expect(base.props, hasLength(variants.length));
      for (final v in variants) {
        expect(v, isNot(base));
      }
      expect(variants.toSet(), hasLength(variants.length));
    });

    test('ToastSpec: undoAction eylem etiketi ister', () {
      expect(
        () => ToastSpec(
          kind: GuToastKind.info,
          text: (l10n, _) => l10n.commonUndo,
          undoAction: true,
        ),
        throwsAssertionError,
      );
    });
  });
}
