// T-42 · FakeMessagingService: arayüz sözleşmesi (izin, jeton, geçersiz
// kılma → yeni jeton, soğuk açılış yükü bir kez, akışlar).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import 'fake_messaging_service.dart';

void main() {
  test('T-42 · FakeMessagingService arayüzü uygular; jeton, yükler ve '
      'akışlar elle kurulur', () async {
    final fake = FakeMessagingService();
    final MessagingService service = fake;
    final taps = <Map<String, String>>[];
    final tokens = <String>[];
    service.openedMessageData.listen(taps.add);
    service.onTokenRefresh.listen(tokens.add);

    expect(await service.isAuthorized(), isTrue);
    expect(await service.token(), FakeMessagingService.defaultToken);
    await service.invalidateToken();
    expect(await service.token(), fake.nextToken);
    fake
      ..launchData = {'notificationId': 'n1'}
      ..tap({'notificationId': 'n2'})
      ..refreshToken('t3');
    expect(await service.initialMessageData(), {'notificationId': 'n1'});
    expect(await service.initialMessageData(), isNull);
    await service.configureForeground();

    expect(taps, [
      {'notificationId': 'n2'},
    ]);
    expect(tokens, ['t3']);
    expect(fake.foregroundConfigured, isTrue);
    expect(fake.callsTo('invalidateToken'), hasLength(1));
  });
}
