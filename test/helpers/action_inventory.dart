// Aksiyon envanteri (D-18, D-19, PLAN §16.2, CD-86, CD-122(4)(6)(8)).
//
// Ekrandaki `GuKey.action` anahtar kümesi ↔ `design/extracted/
// screens-actions.json`. Muaf (demo) ve dinamik kalıplar tek kaynaktan,
// `tool/check_design_coverage.js` ile aynı dosyalardan okunur:
//   tool/design_exempt_actions.txt   beklenmez; ekranda bulunursa hata (K-02)
//   tool/design_dynamic_actions.txt  envanterde olmayan koşullu anahtarlar;
//                                    bulunursa fazla sayılmaz (CD-86)
// `NAV.*` (kabuk) yalnızca `includeShell: true` iken ve ekran
// `registry.tabRoot` ise beklenir/sayılır (K-17, CD-53; T-11'de
// `pumpApp(wrapInShell:)` ile bağlanır); aksi halde yok sayılır.
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import 'design_files.dart';
import 'design_ids.dart';

/// Muaf (demo/mock) aksiyon kalıpları dosyası (CD-122(4)).
const String kExemptActionsFile = 'tool/design_exempt_actions.txt';

/// Dinamik/koşullu aksiyon kalıpları dosyası (CD-86, CD-122(5)).
const String kDynamicActionsFile = 'tool/design_dynamic_actions.txt';

/// Kabuk anahtarı öneki (`NAV.tab.clubs`).
const String kNavPrefix = 'NAV';

/// Envanter `roles` değeri → onu kapsayan test rolleri (CD-122(6)).
///
/// `all` her rolü; `member` (kulüp içi görünüm) üye, yönetici ve süper
/// admini (`viewInside`, domain-model §4); `manager`, `admin` ve `guest`
/// yalnızca kendisini kapsar (navigation.md guard `M`, `S`, `G`).
const Map<String, Set<String>> kInventoryRoleCoverage = {
  'all': {'guest', 'member', 'manager', 'admin'},
  'guest': {'guest'},
  'member': {'member', 'manager', 'admin'},
  'manager': {'manager'},
  'admin': {'admin'},
};

/// Bir ekranın beklenen ↔ bulunan anahtar farkı ([ActionInventory.diff]).
final class ActionInventoryDiff extends Equatable {
  const ActionInventoryDiff({
    required this.screenId,
    required this.expected,
    required this.found,
    this.missing = const {},
    this.extra = const {},
    this.exemptFound = const {},
    this.dynamicFound = const {},
    this.roleError,
  });

  final String screenId;

  /// Beklenen anahtarlar (muaf, `extraExempt` ve kapsam dışı `NAV.*` hariç).
  final Set<String> expected;

  /// Ekranla ilgili bulunan anahtarlar (ekran öneki, envanterdeki diğer
  /// önekler — ör. ekran içi dialog — ve kabuk açıksa `NAV`).
  final Set<String> found;

  /// Beklenen ama bulunmayan.
  final Set<String> missing;

  /// Bulunan ama envanterde ve dinamik kalıplarda olmayan.
  final Set<String> extra;

  /// Uygulanmış muaf (demo) aksiyonlar — K-02 ihlali.
  final Set<String> exemptFound;

  /// Dinamik kalıba uyduğu için aklanan fazla anahtarlar (bilgi).
  final Set<String> dynamicFound;

  /// `role` envanter `roles` alanınca kapsanmıyorsa açıklama.
  final String? roleError;

  /// Fark yok.
  bool get isClean =>
      missing.isEmpty &&
      extra.isEmpty &&
      exemptFound.isEmpty &&
      roleError == null;

  /// Hata mesajı (`expectActionInventory`).
  String describe() {
    String list(Set<String> s) => (s.toList()..sort()).join(', ');
    final out = StringBuffer(
      'Aksiyon envanteri ($screenId) uyuşmuyor — beklenen '
      '${expected.length}, bulunan ${found.length}:',
    );
    if (roleError != null) out.write('\n  rol: $roleError');
    if (missing.isNotEmpty) {
      out.write(
        '\n  eksik (${missing.length}): ${list(missing)} — '
        "GuKey.action('…') ekle ya da rol farkıysa extraExempt",
      );
    }
    if (extra.isNotEmpty) {
      out.write(
        '\n  fazla (${extra.length}): ${list(extra)} — kaldır ya da '
        '$kDynamicActionsFile dosyasına gerekçeyle ekle',
      );
    }
    if (exemptFound.isNotEmpty) {
      out.write(
        '\n  muaf (demo) aksiyon uygulanmış (${exemptFound.length}): '
        '${list(exemptFound)} — K-02, $kExemptActionsFile',
      );
    }
    return out.toString();
  }

  @override
  List<Object?> get props => [
    screenId,
    expected,
    found,
    missing,
    extra,
    exemptFound,
    dynamicFound,
    roleError,
  ];
}

abstract final class ActionInventory {
  /// Ekran → envanter anahtarları (51 ekran; `screens-actions.json`).
  static Map<String, Set<String>> load() => {
    for (final meta in DesignIds.screenMeta.values)
      meta.id: meta.actions.toSet(),
  };

  /// Muaf (demo) kalıplar — [kExemptActionsFile].
  static List<String> get exemptPatterns => readPatterns(kExemptActionsFile);

  /// Dinamik kalıplar — [kDynamicActionsFile].
  static List<String> get dynamicPatterns => readPatterns(kDynamicActionsFile);

  /// Ekran bir sekme kökü mü (`registry.tabRoot`).
  static bool isTabRoot(String screenId) =>
      DesignIds.tabRoots.containsValue(screenId);

  /// Anahtarın kimlik öneki (`<ID>` ya da `NAV`); geçersizse `null`.
  static String? prefixOf(String key) =>
      GuKey.pattern.firstMatch(key)?.group(1);

  /// [screenId] için beklenen anahtarlar: envanter − muaf kalıplar
  /// ([exemptPatterns] verilmezse dosyadan) − `NAV.*` (yalnızca
  /// [includeShell] ve sekme kökünde beklenir).
  static Set<String> expected(
    String screenId, {
    Iterable<String>? exemptPatterns,
    bool includeShell = false,
  }) {
    final actions = _meta(screenId).actions;
    final exempt = (exemptPatterns ?? ActionInventory.exemptPatterns).toList();
    final shell = includeShell && isTabRoot(screenId);
    return {
      for (final a in actions)
        if (!matchesAnyGlob(exempt, a) && (shell || prefixOf(a) != kNavPrefix))
          a,
    };
  }

  /// Ağaçtaki (sahne dışı hariç) `GuKey.action` biçimli `ValueKey<String>`
  /// değerleri.
  static Set<String> found(WidgetTester tester) => {
    for (final w in tester.widgetList(
      find.byWidgetPredicate((w) => w.key is ValueKey<String>),
    ))
      if ((w.key! as ValueKey<String>).value case final v when GuKey.isValid(v))
        v,
  };

  /// `*` şablonlarını [found] içindeki eşleşen anahtarlara genişletir;
  /// jokersiz şablon olduğu gibi kalır, eşleşmeyen jokerli şablon düşer.
  static Set<String> expand(Set<String> templates, Set<String> found) => {
    for (final t in templates)
      if (t.contains('*')) ...found.where(globToRegExp(t).hasMatch) else t,
  };

  /// Envanter [screenRoles] değeri [role]'ü kapsıyor mu
  /// ([kInventoryRoleCoverage]); bilinmeyen rol `ArgumentError`.
  static bool roleCovers(String screenRoles, String role) {
    final known = kInventoryRoleCoverage['all']!;
    if (!known.contains(role)) {
      throw ArgumentError.value(role, 'role', 'bilinen roller: $known');
    }
    return kInventoryRoleCoverage[screenRoles]?.contains(role) ?? false;
  }

  /// Saf fark: [found] (ör. [ActionInventory.found]) ↔ [screenId] envanteri.
  /// [extraExempt] kalıpları beklenenden düşer (rol görünümü farkı);
  /// [exemptPatterns]/[dynamicPatterns] verilmezse dosyalardan okunur.
  static ActionInventoryDiff diff(
    String screenId,
    Set<String> found, {
    String? role,
    Set<String> extraExempt = const {},
    bool includeShell = false,
    Iterable<String>? exemptPatterns,
    Iterable<String>? dynamicPatterns,
  }) {
    final meta = _meta(screenId);
    final exempt = (exemptPatterns ?? ActionInventory.exemptPatterns).toList();
    final dynamics = (dynamicPatterns ?? ActionInventory.dynamicPatterns)
        .toSet();
    final shell = includeShell && isTabRoot(screenId);

    final inventory = expected(
      screenId,
      exemptPatterns: exempt,
      includeShell: includeShell,
    );
    final want = {
      for (final a in inventory)
        if (!matchesAnyGlob(extraExempt, a)) a,
    };
    final prefixes = {
      screenId,
      for (final a in meta.actions)
        if (prefixOf(a) case final p? when p != kNavPrefix) p,
      if (shell) kNavPrefix,
    };
    final relevant = {
      for (final k in found)
        if (prefixes.contains(prefixOf(k))) k,
    };
    final exemptFound = {
      for (final k in relevant)
        if (matchesAnyGlob(exempt, k)) k,
    };
    final dynamicFound = expand(
      dynamics,
      relevant,
    ).difference(inventory).difference(exemptFound);

    return ActionInventoryDiff(
      screenId: screenId,
      expected: want,
      found: relevant,
      missing: want.difference(relevant),
      extra: relevant
          .difference(inventory)
          .difference(dynamicFound)
          .difference(exemptFound),
      exemptFound: exemptFound,
      dynamicFound: dynamicFound,
      roleError: role == null || roleCovers(meta.roles, role)
          ? null
          : '"$role" rolü $screenId envanterince kapsanmıyor '
                '(roles: ${meta.roles})',
    );
  }

  static ScreenMeta _meta(String screenId) =>
      DesignIds.screenMeta[screenId] ??
      (throw ArgumentError.value(
        screenId,
        'screenId',
        'screens-actions.json envanterinde yok',
      ));
}

/// Ekrandaki `GuKey.action` kümesi [screenId] envanterine eşit değilse testi
/// düşürür (eksik, fazla, uygulanmış muaf, rol kapsamı). [role] verilirse
/// envanter `roles` alanının onu kapsadığı doğrulanır; rol görünümünde
/// olmayan beklenen anahtarlar [extraExempt] ile gerekçelenir.
void expectActionInventory(
  WidgetTester tester,
  String screenId, {
  String? role,
  Set<String> extraExempt = const {},
  bool includeShell = false,
}) {
  final diff = ActionInventory.diff(
    screenId,
    ActionInventory.found(tester),
    role: role,
    extraExempt: extraExempt,
    includeShell: includeShell,
  );
  if (!diff.isClean) fail(diff.describe());
}
