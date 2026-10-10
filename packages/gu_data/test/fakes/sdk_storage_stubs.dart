// El yazımı `firebase_storage` SDK çiftleri (mock kütüphanesi yok —
// docs/testing.md §1.2). `firebase_storage_mocks` hata fırlatamadığı, ilerleme
// yayınlamadığı ve askıda kalamadığı için bu testler bunları kullanır.
import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// `firebase_storage` kaynaklı hata.
FirebaseException storageException(String code, {String? message}) =>
    FirebaseException(plugin: 'firebase_storage', code: code, message: message);

/// Yükleme anlık görüntüsü: aktarılan / toplam bayt.
final class StubTaskSnapshot implements TaskSnapshot {
  /// [ref] nesnesine [bytesTransferred] / [totalBytes] aktarılmış görüntü.
  StubTaskSnapshot(this.ref, {this.bytesTransferred = 0, this.totalBytes = 0});

  @override
  final Reference ref;

  @override
  final int bytesTransferred;

  @override
  final int totalBytes;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Elle tamamlanan yükleme görevi: [complete] / [fail] çağrılana kadar
/// askıda kalır; [progress] ile ilerleme olayı yayınlar.
final class StubUploadTask implements UploadTask {
  /// Verilen nesneye yükleme görevi.
  StubUploadTask(this._ref);

  final Reference _ref;
  final Completer<TaskSnapshot> _completer = Completer<TaskSnapshot>();
  final StreamController<TaskSnapshot> _events =
      StreamController<TaskSnapshot>();

  /// [cancel] çağrı sayısı.
  int cancels = 0;

  /// İlerleme dinleyicisi hâlâ bağlı mı?
  bool get hasProgressListener => _events.hasListener;

  /// [bytesTransferred] / [totalBytes] ilerleme olayı yayınlar.
  void progress(int bytesTransferred, int totalBytes) => _events.add(
    StubTaskSnapshot(
      _ref,
      bytesTransferred: bytesTransferred,
      totalBytes: totalBytes,
    ),
  );

  /// Yüklemeyi başarıyla bitirir.
  void complete() => _completer.complete(StubTaskSnapshot(_ref));

  /// Yüklemeyi [error] ile bitirir (SDK gibi olay akışına da yazar).
  void fail(Object error) {
    _events.addError(error);
    _completer.completeError(error);
  }

  @override
  Stream<TaskSnapshot> get snapshotEvents => _events.stream;

  @override
  Future<bool> cancel() async {
    cancels++;
    return true;
  }

  @override
  Future<S> then<S>(
    FutureOr<S> Function(TaskSnapshot value) onValue, {
    Function? onError,
  }) => _completer.future.then(onValue, onError: onError);

  @override
  Future<TaskSnapshot> timeout(
    Duration timeLimit, {
    FutureOr<TaskSnapshot> Function()? onTimeout,
  }) => _completer.future.timeout(timeLimit, onTimeout: onTimeout);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Yüklemesi elle yönetilen, kısa çağrıları [error] ile biten (ya da askıda
/// kalan) nesne referansı.
final class StubReference implements Reference {
  /// [fullPath] yolundaki nesne; [error] verilmezse kısa çağrılar askıda
  /// kalır.
  StubReference(this.fullPath, {this.error});

  @override
  final String fullPath;

  /// Kısa çağrıların ([getDownloadURL], [getMetadata]) fırlattığı hata;
  /// `null` ise çağrı tamamlanmaz.
  final Object? error;

  /// [putData] ile başlatılan görevler, başlatma sırasıyla.
  final List<StubUploadTask> tasks = [];

  @override
  UploadTask putData(Uint8List data, [SettableMetadata? metadata]) {
    final task = StubUploadTask(this);
    tasks.add(task);
    return task;
  }

  @override
  Future<String> getDownloadURL() =>
      error == null ? Completer<String>().future : Future.error(error!);

  @override
  Future<FullMetadata> getMetadata() =>
      error == null ? Completer<FullMetadata>().future : Future.error(error!);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Her yol için aynı [StubReference] örneğini veren depolama.
final class StubStorage implements FirebaseStorage {
  /// [error] verilmezse kısa çağrılar askıda kalır.
  StubStorage({this.error});

  /// Kısa çağrıların fırlattığı hata; `null` ise çağrı tamamlanmaz.
  final Object? error;

  /// [ref] ile istenen yollar → referanslar.
  final Map<String, StubReference> references = {};

  /// Başlatılan tek yükleme görevi. Görev bir `Future` olduğundan testler
  /// onu doğrudan değil aşağıdaki yardımcılarla yönetir.
  StubUploadTask get _task =>
      references.values.expand((reference) => reference.tasks).single;

  /// Yüklemenin [bytesTransferred] / [totalBytes] ilerleme olayını yayınlar.
  void progress(int bytesTransferred, int totalBytes) =>
      _task.progress(bytesTransferred, totalBytes);

  /// Yüklemeyi başarıyla bitirir.
  void completeUpload() => _task.complete();

  /// Yüklemeyi [error] ile bitirir.
  void failUpload(Object error) => _task.fail(error);

  /// Yükleme görevinin iptal edilme sayısı.
  int get uploadCancels => _task.cancels;

  /// Yüklemenin ilerleme dinleyicisi hâlâ bağlı mı?
  bool get hasProgressListener => _task.hasProgressListener;

  @override
  Reference ref([String? path]) => references.putIfAbsent(
    path ?? '',
    () => StubReference(path ?? '', error: error),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
