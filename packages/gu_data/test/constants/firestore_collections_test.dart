// T-08 · FirestoreCollections: PLAN §9.5 listesiyle ad + değer paritesi,
// tekillik ve domain-model §2 koleksiyon yollarıyla uyum.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/repo_sources.dart';

/// `FirestoreCollections` üyelerinin gerçek değerleri (ad kümesi PLAN §9.5 ve
/// kaynak dosyayla karşılaştırılır).
const Map<String, String> _actual = {
  'users': FirestoreCollections.users,
  'privateSub': FirestoreCollections.privateSub,
  'accountDoc': FirestoreCollections.accountDoc,
  'clubs': FirestoreCollections.clubs,
  'memberships': FirestoreCollections.memberships,
  'contactDoc': FirestoreCollections.contactDoc,
  'posts': FirestoreCollections.posts,
  'votesSub': FirestoreCollections.votesSub,
  'comments': FirestoreCollections.comments,
  'events': FirestoreCollections.events,
  'rsvps': FirestoreCollections.rsvps,
  'notifications': FirestoreCollections.notifications,
  'reports': FirestoreCollections.reports,
  'activity': FirestoreCollections.activity,
  'settings': FirestoreCollections.settings,
  'blocks': FirestoreCollections.blocks,
  'savedPosts': FirestoreCollections.savedPosts,
  'supportTickets': FirestoreCollections.supportTickets,
  'announcementCounters': FirestoreCollections.announcementCounters,
};

/// Kök koleksiyonlar (D-25: 15 düz koleksiyon).
const List<String> _rootNames = [
  'users',
  'clubs',
  'memberships',
  'posts',
  'comments',
  'events',
  'rsvps',
  'notifications',
  'reports',
  'activity',
  'settings',
  'blocks',
  'savedPosts',
  'supportTickets',
  'announcementCounters',
];

/// PLAN §9.5 `FirestoreCollections` maddesindeki `ad='değer'` çiftleri.
Map<String, String> _readPlanCollections() {
  final line = readRepoFile('docs/PLAN.md')
      .split('\n')
      .singleWhere(
        (l) =>
            l.startsWith('- `FirestoreCollections` (`static const String`):'),
      );
  final pair = RegExp(r"^(\w+)='([^']*)'$");
  return {
    for (final span in codeSpans(line))
      if (pair.firstMatch(span) case final match?)
        match.group(1)!: match.group(2)!,
  };
}

/// `firestore_collections.dart` içindeki `static const String` bildirimleri.
Map<String, String> _readSourceMembers() {
  final source = readRepoFile(
    'packages/gu_data/lib/src/constants/firestore_collections.dart',
  );
  return {
    for (final match in RegExp(
      r"^ {2}static const String (\w+) =\s*'([^']*)';",
      multiLine: true,
    ).allMatches(source))
      match.group(1)!: match.group(2)!,
  };
}

void main() {
  group('T-08 · FirestoreCollections · PLAN §9.5 paritesi', () {
    test('PLAN listesi okunur: 19 ad', () {
      expect(_readPlanCollections(), hasLength(19));
    });

    test('adlar ve değerler PLAN §9.5 ile birebir (sıra dahil)', () {
      final plan = _readPlanCollections();

      expect(_actual, plan);
      expect(_actual.keys.toList(), plan.keys.toList());
    });

    test('kaynak dosya üyeleri PLAN ile birebir (fazla/eksik yok)', () {
      final source = _readSourceMembers();

      expect(source, _readPlanCollections());
      expect(source, _actual);
    });

    test('kaynak dosyada static const String dışında üye yok', () {
      final source = readRepoFile(
        'packages/gu_data/lib/src/constants/firestore_collections.dart',
      );
      final memberLines = source
          .substring(
            source.indexOf('abstract final class FirestoreCollections {'),
          )
          .split('\n')
          .where((line) => RegExp('^ {2}[A-Za-z_@]').hasMatch(line));

      expect(memberLines, hasLength(19));
      expect(memberLines, everyElement(startsWith('  static const String ')));
    });
  });

  group('T-08 · FirestoreCollections · adlar', () {
    test('19 değerin tamamı tekildir', () {
      expect(_actual.values.toSet(), hasLength(19));
    });

    test('15 kök koleksiyon + 2 alt koleksiyon + 2 sabit belge adı', () {
      final subs = _actual.keys.where((name) => name.endsWith('Sub'));
      final docs = _actual.keys.where((name) => name.endsWith('Doc'));
      final roots = _actual.keys.where(
        (name) => !name.endsWith('Sub') && !name.endsWith('Doc'),
      );

      expect(roots, _rootNames);
      expect(subs, ['privateSub', 'votesSub']);
      expect(docs, ['accountDoc', 'contactDoc']);
    });

    test('kök koleksiyonda Dart adı = Firestore adı', () {
      for (final name in _rootNames) {
        expect(_actual[name], name);
      }
    });

    test('alt koleksiyon ve sabit belge değerleri', () {
      expect(FirestoreCollections.privateSub, 'private');
      expect(FirestoreCollections.votesSub, 'votes');
      expect(FirestoreCollections.accountDoc, 'account');
      expect(FirestoreCollections.contactDoc, 'contact');
    });

    test('her değer geçerli bir Firestore yol parçasıdır', () {
      for (final MapEntry(key: name, value: id) in _actual.entries) {
        expect(id, matches(RegExp(r'^[a-z][A-Za-z]*$')), reason: name);
        expect(id, isNot(contains('/')), reason: name);
        expect(id, isNot(startsWith('__')), reason: name);
      }
    });
  });

  group('T-08 · FirestoreCollections · domain-model §2 uyumu', () {
    /// `### 2.x `<yol>`` başlıklarındaki belge yolları.
    List<String> schemaPaths() => [
      for (final match in RegExp(
        r'^### 2\.\d+ `([^`]+)`',
        multiLine: true,
      ).allMatches(readRepoFile('docs/domain-model.md')))
        match.group(1)!,
    ];

    test('şema başlıkları okunur: 16 yol', () {
      expect(schemaPaths(), hasLength(16));
    });

    test('şemadaki kök koleksiyon kümesi = 15 kök sabit', () {
      final roots = {for (final path in schemaPaths()) path.split('/').first};

      expect(roots, _rootNames.toSet());
      expect(roots, {for (final name in _rootNames) _actual[name]});
    });

    test('users/{uid}/private/account yolu sabitlerden kurulur', () {
      const built =
          '${FirestoreCollections.users}/{uid}/'
          '${FirestoreCollections.privateSub}/'
          '${FirestoreCollections.accountDoc}';

      expect(schemaPaths(), contains(built));
    });

    test('memberships/{id}/private/contact yolu sabitlerden kurulur', () {
      const built =
          '${FirestoreCollections.memberships}/{id}/'
          '${FirestoreCollections.privateSub}/'
          '${FirestoreCollections.contactDoc}';

      expect(readRepoFile('docs/domain-model.md'), contains('`$built`'));
    });

    test('posts/{postId}/votes/{uid} yolu sabitlerden kurulur', () {
      const built =
          '${FirestoreCollections.posts}/{postId}/'
          '${FirestoreCollections.votesSub}/{uid}';

      expect(readRepoFile('docs/PLAN.md'), contains('`$built`'));
    });

    test('koleksiyon grubu adı Rules taslağındaki private yolu ile aynı', () {
      expect(
        readRepoFile('docs/firestore-rules-spec.md'),
        contains(
          'match /{path=**}/${FirestoreCollections.privateSub}/{doc}',
        ),
      );
    });
  });
}
