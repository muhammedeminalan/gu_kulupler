// T-28 · FakeSupportRepository sözleşmesi (PLAN §16.3): `tickets`,
// `attachments`; ön denetim → ek → belge sırası ve `GU-XXXXXX` numarası.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/fake_app_clock.dart';
import 'fake_support_repository.dart';
import 'register_fakes.dart';

const String _me = 'u_ayse';

SupportAttachment _png([int length = 8]) => SupportAttachment(
  bytes: Uint8List(length)..fillRange(0, length, 1),
  contentType: 'image/png',
);

void main() {
  late FakeSupportRepository fake;

  setUp(() => fake = FakeSupportRepository(FakeAppClock(kDefaultFakeNowUtc)));

  group('T-28 · FakeSupportRepository', () {
    test('SupportRepository arayüzünü uygular; registerDefaultFakes '
        'kaydeder', () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      expect(GetIt.I<SupportRepository>(), isA<FakeSupportRepository>());
    });

    test('createTicket: numara deseni, ek yolu `support/{ticketNo}/…`, '
        'yükleyen üst verisi; listMine en yeni önce', () async {
      final first = await fake.createTicket(
        userId: _me,
        subject: SupportSubject.bug,
        message: 'Uygulama açılmıyor',
        attachment: _png(),
      );
      final ticket = first.dataOrNull!;
      expect(
        RegExp(FirestoreIds.supportTicketNoPattern).hasMatch(ticket.ticketNo),
        isTrue,
      );
      // Belge kimliği talep numarasıdır (`supportTickets/{ticketNo}`).
      expect(ticket.id, ticket.ticketNo);
      expect(ticket.status, TicketStatus.open);
      expect(ticket.attachmentPaths, hasLength(1));
      expect(
        StoragePaths.isSupportFile(
          ticket.attachmentPaths.single,
          ticket.ticketNo,
        ),
        isTrue,
      );
      expect(fake.attachments.single.uploaderId, _me);

      fake.put(
        SupportTicketModel(
          id: 'old',
          ticketNo: 'GU-ZZZZZZ',
          userId: _me,
          subject: SupportSubject.other,
          message: 'Eski',
          createdAt: kDefaultFakeNowUtc.subtract(const Duration(days: 1)),
        ),
      );
      final mine = (await fake.listMine(_me)).dataOrNull!;
      expect(mine.map((t) => t.id), [ticket.id, 'old']);
    });

    test('ön denetim: boş / 500+ mesaj belge hatası, tür ve boyut yükleme '
        'hatası — hiçbir şey yazılmaz', () async {
      final empty = await fake.createTicket(
        userId: _me,
        subject: SupportSubject.bug,
        message: '',
      );
      expect(
        empty.errorOrNull,
        const MediaDocumentError(FirestoreError.invalidArgument),
      );
      final long = await fake.createTicket(
        userId: _me,
        subject: SupportSubject.bug,
        message: 'a' * (Limits.supportMessageMax + 1),
      );
      expect(long.errorOrNull, isA<MediaDocumentError>());
      final big = await fake.createTicket(
        userId: _me,
        subject: SupportSubject.bug,
        message: 'Ek',
        attachment: _png(Limits.imageMaxBytes),
      );
      expect(big.errorOrNull, const MediaUploadError(StorageError.sizeLimit));
      expect(fake.tickets, isEmpty);
      expect(fake.attachments, isEmpty);
    });

    test('failNext(FirestoreError): ek yüklenmiş kalır, belge '
        'yazılmaz', () async {
      fake.failNext(FirestoreError.permissionDenied);
      final result = await fake.createTicket(
        userId: _me,
        subject: SupportSubject.account,
        message: 'Ek',
        attachment: _png(),
      );
      expect(
        result.errorOrNull,
        const MediaDocumentError(FirestoreError.permissionDenied),
      );
      expect(fake.attachments, hasLength(1));
      expect(fake.tickets, isEmpty);
    });
  });
}
