// T-11 · WriteGuardMixin: çevrimdışı yazma engeli — tek mekanizma (Q-12).
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/core/connectivity/connectivity_gate.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';

import '../../fakes/fake_connectivity_service.dart';
import '../../fakes/fake_feedback_service.dart';
import '../../fakes/register_fakes.dart';

/// Yazan bir ViewModel'in en küçük hali: kapıdan geçerse yazar.
final class _Writer with ProjectDependencyMixin, WriteGuardMixin {
  int writes = 0;

  void write() {
    if (!ensureOnline()) return;
    writes++;
  }
}

void main() {
  late FakeConnectivityService service;
  late FakeFeedbackService feedback;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    service = GetIt.I<ConnectivityService>() as FakeConnectivityService;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
  });

  group('T-11 · WriteGuardMixin', () {
    test('çevrimiçi → true, toast yok, yazma gerçekleşir', () {
      final writer = _Writer();
      expect(writer.ensureOnline(), isTrue);
      writer.write();
      expect(writer.writes, 1);
      expect(feedback.toasts, isEmpty);
    });

    test('çevrimdışı → false + çevrimdışı toastı; yazma gerçekleşmez', () {
      service.isOffline = true;
      final writer = _Writer();
      expect(writer.ensureOnline(), isFalse);
      expect(feedback.toasts, [ToastId.tst24]);

      writer.write();
      expect(writer.writes, 0);
      expect(feedback.toasts, [ToastId.tst24, ToastId.tst24]);
    });

    test('bağlantı gelince aynı örnek yeniden yazabilir', () {
      service.isOffline = true;
      final writer = _Writer()..write();
      service.isOffline = false;
      writer.write();
      expect(writer.writes, 1);
      expect(feedback.toasts, [ToastId.tst24]);
    });

    test('simüle çevrimdışılık da yazmayı engeller', () {
      GetIt.I<ConnectivityGate>().simulatedOffline = true;
      expect(_Writer().ensureOnline(), isFalse);
      expect(feedback.toasts, [ToastId.tst24]);
    });
  });
}
