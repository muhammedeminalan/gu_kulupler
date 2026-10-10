// ViewModel testleri için `ProviderContainer` (CLAUDE.md §2, PLAN §16.2).
// `pumpEventQueue()` flutter_test'ten gelir (ayrı kısayol yok).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// [overrides] ile kapsayıcı; test sonunda `dispose` edilir
/// (`ProviderContainer.test` → `addTearDown(container.dispose)`).
ProviderContainer createContainer({List<Override> overrides = const []}) =>
    ProviderContainer.test(overrides: overrides);
