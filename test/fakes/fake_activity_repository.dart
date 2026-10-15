// `ActivityRepository` fake'i (PLAN §16.3): kulüp günlüğünü bellekte tutar.
//
//   final activity = FakeActivityRepository()
//     ..entries.add(ActivityModel(clubId: 'c01', actorId: 'u1', kind: …));
//   final page = await activity.listActivity('c01', const PageRequest());
//
// Gerçek repository gibi: yalnızca istenen kulübün kayıtları, en yeni üstte
// (`createdAt` azalan), isteğe bağlı kategori süzgeci ve sayfalama
// (`PageCursor.fake()` — `FakePager`). Günlük salt okunurdur: kayıtları asıl
// yazımı yapan repository ekler.
import 'package:gu_data/gu_data.dart';

import 'fake_base.dart';
import 'fake_pager.dart';

final class FakeActivityRepository extends FakeBase
    implements ActivityRepository {
  /// `activity/{id}` kayıtları; test ön veriyi buraya yazar.
  final List<ActivityModel> entries = <ActivityModel>[];

  final FakePager _pager = FakePager();

  @override
  Future<FirestoreResult<PageResult<ActivityModel>>> listActivity(
    String clubId,
    PageRequest page, {
    ActivityCategory? category,
  }) async {
    record('listActivity', [clubId, page, category]);
    final failure = switch (takeFailure()) {
      null => null,
      final FirestoreError error => error,
      _ => FirestoreError.unknown,
    };
    if (failure != null) return FirebaseFailure(failure);
    if (!RepositoryHelpers.isValidId(clubId)) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    final kinds = category?.kinds;
    final matching = [
      for (final entry in entries)
        if (entry.clubId == clubId &&
            (kinds == null || kinds.contains(entry.kind)))
          entry,
    ]..sort(_newestFirst);
    return FirebaseSuccess(_pager.slice(matching, page));
  }

  /// Gerçek repository gibi tüm kulüplerde sayar: kova `i` =
  /// `[fromUtc + i·7 gün, fromUtc + (i+1)·7 gün)`; zamanı olmayan kayıt
  /// sayılmaz (sunucu zamanı henüz yazılmamış).
  @override
  Future<FirestoreResult<List<int>>> countByWeek({
    required Set<ActivityKind> kinds,
    required DateTime fromUtc,
    required int weeks,
  }) async {
    record('countByWeek', [kinds, fromUtc, weeks]);
    final failure = switch (takeFailure()) {
      null => null,
      final FirestoreError error => error,
      _ => FirestoreError.unknown,
    };
    if (failure != null) return FirebaseFailure(failure);
    if (kinds.isEmpty ||
        kinds.length > RepositoryHelpers.whereInMax ||
        weeks <= 0) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    final counts = List<int>.filled(weeks, 0);
    for (final entry in entries) {
      final at = entry.createdAt;
      if (at == null || !kinds.contains(entry.kind) || at.isBefore(fromUtc)) {
        continue;
      }
      final index = at.difference(fromUtc).inMicroseconds ~/ _weekMicros;
      if (index < weeks) counts[index]++;
    }
    return FirebaseSuccess(counts);
  }

  static final int _weekMicros = const Duration(
    days: DateTime.daysPerWeek,
  ).inMicroseconds;

  /// `createdAt` azalan; zamanı olmayan kayıt sonda.
  static int _newestFirst(ActivityModel a, ActivityModel b) {
    final left = a.createdAt;
    final right = b.createdAt;
    if (left == null || right == null) {
      return left == right ? 0 : (left == null ? 1 : -1);
    }
    return right.compareTo(left);
  }
}
