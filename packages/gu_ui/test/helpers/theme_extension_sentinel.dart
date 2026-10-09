// ThemeExtension `copyWith` / `lerp` nöbetçi (sentinel) testleri (T-01).
//
// Her alana FARKLI bir nöbetçi değer verilir; böylece `copyWith`'te ya da
// `lerp`'te iki alanın çapraz bağlanması (`titleM: mix(titleL, …)`,
// `e2: e2 ?? this.e3` …) alan haritası karşılaştırmasında yakalanır. Alan
// adları `copyWith`'in adlandırılmış parametreleridir; çağrı
// `Function.apply` + `Symbol(ad)` ile yapılır (yansıma gerekmez).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Alan adı → değer (tanım sırasıyla).
typedef FieldMap<T> = Map<String, Object?> Function(T value);

/// `index`. alanın `salt` kümesindeki nöbetçi değeri; her (alan, salt) çifti
/// için farklı olmalıdır.
typedef Sentinel = Object Function(String field, int index, int salt);

/// Aynı alanın iki değeri arasındaki beklenen ara değer (ör. `Color.lerp`).
typedef FieldLerp =
    Object? Function(String field, Object? a, Object? b, double t);

/// `original.copyWith` ve `lerp` için nöbetçi testlerini kaydeder.
///
/// * `copyWith()` → eşit, özdeş değil.
/// * Tüm alanlar nöbetçi → alan haritası == nöbetçi harita.
/// * Her alan tek tek → yalnız o alan değişir, diğerleri korunur.
/// * `a.lerp(b, 1)` alan alan == `b`; `a.lerp(b, 0)` == `a`; `t = 0.5`
///   alan alan [lerpField] ile (a, b iki farklı nöbetçi küme).
/// * `lerp(null, t)` → kendisi.
void registerSentinelTests<T extends ThemeExtension<T>>({
  required String name,
  required T original,
  required FieldMap<T> fields,
  required Sentinel sentinel,
  required FieldLerp lerpField,
}) {
  final names = fields(original).keys.toList(growable: false);

  Map<String, Object?> sentinels(int salt) => {
    for (var i = 0; i < names.length; i++)
      names[i]: sentinel(names[i], i, salt),
  };

  T copy(T base, Map<String, Object?> values) =>
      Function.apply(base.copyWith, const [], {
            for (final e in values.entries) Symbol(e.key): e.value,
          })
          as T;

  group('T-01 · $name nöbetçi copyWith / lerp', () {
    test('nöbetçi değerler alanlar arasında ve kümeler arasında farklı', () {
      final all = [...sentinels(0).values, ...sentinels(1).values];
      expect(all.toSet(), hasLength(all.length));
      expect(names.toSet(), hasLength(names.length));
    });

    test('copyWith() değişmeden eşit kopya', () {
      final same = copy(original, const {});
      expect(identical(same, original), isFalse);
      expect(same, original);
      expect(same.hashCode, original.hashCode);
    });

    test('copyWith: ${names.length} alanın tamamı → nöbetçi harita', () {
      expect(fields(copy(original, sentinels(0))), sentinels(0));
    });

    test('copyWith: her alan tek başına; diğerleri korunur', () {
      final before = fields(original);
      for (var i = 0; i < names.length; i++) {
        final value = sentinel(names[i], i, 0);
        final after = fields(copy(original, {names[i]: value}));
        expect(after, {...before, names[i]: value}, reason: names[i]);
      }
    });

    test('lerp(b, 1) alan alan == b; lerp(b, 0) alan alan == a', () {
      final a = copy(original, sentinels(0));
      final b = copy(original, sentinels(1));
      expect(fields(a.lerp(b, 1) as T), sentinels(1));
      expect(fields(a.lerp(b, 0) as T), sentinels(0));
    });

    test('lerp(b, 0.5) alan alan ara değer', () {
      final a = copy(original, sentinels(0));
      final b = copy(original, sentinels(1));
      final mid = fields(a.lerp(b, 0.5) as T);
      final av = sentinels(0);
      final bv = sentinels(1);
      for (final n in names) {
        expect(mid[n], lerpField(n, av[n], bv[n], 0.5), reason: n);
      }
    });

    test('lerp(null, t) → kendisi', () {
      expect(identical(original.lerp(null, 0.5), original), isTrue);
    });
  });
}
