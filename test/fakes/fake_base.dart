// El yazımı fake'lerin ortak tabanı (testing.md §1.2, PLAN §16.3; mock
// kütüphanesi yok). Fake gerçek arayüzü uygular, bellekte çalışır:
//
//   final class FakeClubRepository extends FakeBase implements ClubRepository {
//     @override
//     Future<FirebaseResult<List<ClubModel>>> fetchActiveClubs() async {
//       record('fetchActiveClubs');
//       if (takeFailure() case final error?) return FirebaseFailure(error);
//       return FirebaseSuccess(clubs);
//     }
//   }
import 'package:equatable/equatable.dart';

/// Fake'e yapılan tek çağrı: metot adı + argümanlar (sırasıyla).
final class FakeCall extends Equatable {
  const FakeCall(this.method, [this.args = const []]);

  final String method;
  final List<Object?> args;

  @override
  List<Object?> get props => [method, args];

  @override
  String toString() => '$method(${args.join(', ')})';
}

/// [FakeBase.failNext] varsayılan hatası.
final class FakeFailure implements Exception {
  const FakeFailure([this.message = 'fake failure']);

  final String message;

  @override
  String toString() => 'FakeFailure: $message';
}

/// Çağrı günlüğü ([calls]) ve tek seferlik hata enjeksiyonu ([failNext]).
abstract class FakeBase {
  /// Tüm çağrılar, geliş sırasıyla.
  final List<FakeCall> calls = <FakeCall>[];

  Object? _pendingFailure;

  /// Fake metodu başında çağrılır: günlüğe [method] + [args] eklenir.
  void record(String method, [List<Object?> args = const []]) =>
      calls.add(FakeCall(method, args));

  /// Yalnızca [method] çağrıları.
  List<FakeCall> callsTo(String method) =>
      calls.where((c) => c.method == method).toList(growable: false);

  /// Bir sonraki [takeFailure] [error]'ı döndürür (tek seferlik).
  void failNext([Object error = const FakeFailure()]) =>
      _pendingFailure = error;

  /// Bekleyen hata var mı.
  bool get hasPendingFailure => _pendingFailure != null;

  /// Bekleyen hatayı döndürür ve temizler; yoksa `null`.
  Object? takeFailure() {
    final failure = _pendingFailure;
    _pendingFailure = null;
    return failure;
  }

  /// Günlüğü ve bekleyen hatayı sıfırlar.
  void resetFake() {
    calls.clear();
    _pendingFailure = null;
  }
}
