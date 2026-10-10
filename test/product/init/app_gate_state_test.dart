// T-11 · AppGateState: props / copyWith tüm alanlar (PLAN §12.16).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/init/app_gate_state.dart';

void main() {
  group('T-11 · AppGateState', () {
    const a = AppGateState();

    test('props tüm alanları içerir (alan sayısı = 7)', () {
      expect(a.props.length, 7);
    });

    test('varsayılanlar: tüm kapılar kapalı', () {
      expect(a.minSupportedBuild, 0);
      expect(a.currentBuild, 0);
      expect(a.isUpdateRequired, isFalse);
      expect(a.isSessionExpired, isFalse);
      expect(a.maintenanceMessage, isEmpty);
      expect(a.isFetching, isFalse);
      expect(a.isError, isFalse);
    });

    test('copyWith her alanı taşır ve eşitliği bozar', () {
      expect(a.copyWith(minSupportedBuild: 5).minSupportedBuild, 5);
      expect(a.copyWith(minSupportedBuild: 5), isNot(a));
      expect(a.copyWith(currentBuild: 3).currentBuild, 3);
      expect(a.copyWith(currentBuild: 3), isNot(a));
      expect(a.copyWith(isUpdateRequired: true).isUpdateRequired, isTrue);
      expect(a.copyWith(isUpdateRequired: true), isNot(a));
      expect(a.copyWith(isSessionExpired: true).isSessionExpired, isTrue);
      expect(a.copyWith(isSessionExpired: true), isNot(a));
      expect(a.copyWith(maintenanceMessage: 'x').maintenanceMessage, 'x');
      expect(a.copyWith(maintenanceMessage: 'x'), isNot(a));
      expect(a.copyWith(isFetching: true).isFetching, isTrue);
      expect(a.copyWith(isFetching: true), isNot(a));
      expect(a.copyWith(isError: true).isError, isTrue);
      expect(a.copyWith(isError: true), isNot(a));
    });

    test('copyWith parametresiz aynı değeri verir', () {
      final b = a.copyWith(
        minSupportedBuild: 9,
        currentBuild: 4,
        isUpdateRequired: true,
        isSessionExpired: true,
        maintenanceMessage: 'Bakım',
        isFetching: true,
        isError: true,
      );
      expect(b.copyWith(), b);
    });

    test('türetilmiş hasMaintenanceMessage', () {
      expect(a.hasMaintenanceMessage, isFalse);
      expect(a.copyWith(maintenanceMessage: 'x').hasMaintenanceMessage, isTrue);
    });
  });
}
