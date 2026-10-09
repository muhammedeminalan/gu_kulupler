import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('T-00 · gu_data workspace', () {
    test('cloud_firestore bağımlılığı çözülür (Timestamp)', () {
      final ts = Timestamp.fromMillisecondsSinceEpoch(0);
      expect(ts.toDate().toUtc().year, 1970);
    });
  });
}
