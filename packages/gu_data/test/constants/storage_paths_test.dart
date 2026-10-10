// T-10 · StoragePaths: yol üreticileri, dosya adı şeması, doğrulayıcılar ve
// seed yollarıyla uyum (PLAN §9.4, §9.12, §10.2, §11.5; D-10, CD-39, CD-47).
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/fake_app_clock.dart';
import '../fixtures/demo_data.dart';

/// PLAN §10.2 örneği: `20261008T201501Z_3f9a1c2b7d4e5f60.jpg`.
const String _file = '20261008T201501Z_3f9a1c2b7d4e5f60.jpg';
final DateTime _stamp = DateTime.utc(2026, 10, 8, 20, 15, 1);
const List<int> _hexBytes = [0x3f, 0x9a, 0x1c, 0x2b, 0x7d, 0x4e, 0x5f, 0x60];

/// Önceden verilen baytları sırayla döndüren el yazımı [Random].
final class _ScriptedRandom implements Random {
  _ScriptedRandom(this._values);

  final List<int> _values;

  /// `nextInt` çağrılarına verilen `max` değerleri, sırayla.
  final List<int> maxArguments = [];

  @override
  int nextInt(int max) {
    final value = _values[maxArguments.length % _values.length];
    maxArguments.add(max);
    return value;
  }

  @override
  bool nextBool() => throw UnsupportedError('nextBool beklenmiyor');

  @override
  double nextDouble() => throw UnsupportedError('nextDouble beklenmiyor');
}

/// Beş kök: üretici + doğrulayıcı + beklenen klasör.
final List<
  ({
    String root,
    String Function(String id, String file) build,
    bool Function(String path, String id) check,
  })
>
_roots = [
  (
    root: 'users',
    build: StoragePaths.userAvatar,
    check: StoragePaths.isUserAvatar,
  ),
  (root: 'clubs', build: StoragePaths.clubLogo, check: StoragePaths.isClubFile),
  (
    root: 'clubs',
    build: StoragePaths.clubCover,
    check: StoragePaths.isClubFile,
  ),
  (
    root: 'events',
    build: StoragePaths.eventCover,
    check: StoragePaths.isEventCover,
  ),
  (
    root: 'posts',
    build: StoragePaths.postImage,
    check: StoragePaths.isPostImage,
  ),
  (
    root: 'support',
    build: StoragePaths.supportAttachment,
    check: StoragePaths.isSupportFile,
  ),
];

void main() {
  group('T-10 · StoragePaths · newFileName', () {
    test('PLAN örneği: <UTC damga>_<16 hex>.<uzantı>', () {
      final random = _ScriptedRandom(_hexBytes);

      final name = StoragePaths.newFileName(
        FakeAppClock(_stamp),
        random,
        'jpg',
      );

      expect(name, _file);
      expect(random.maxArguments, List.filled(8, 256));
    });

    test('damga alanları sıfırla doldurulur; küçük baytlar iki hex hane', () {
      final name = StoragePaths.newFileName(
        FakeAppClock(DateTime.utc(2027, 1, 2, 3, 4, 5)),
        _ScriptedRandom([0, 1, 15, 16, 255, 0, 0, 10]),
        'png',
      );

      expect(name, '20270102T030405Z_00010f10ff00000a.png');
    });

    test('üç uzantı kabul edilir; diğerleri ArgumentError', () {
      final clock = FakeAppClock(_stamp);

      for (final ext in ['jpg', 'png', 'webp']) {
        expect(
          StoragePaths.newFileName(clock, _ScriptedRandom(_hexBytes), ext),
          endsWith('.$ext'),
        );
      }
      for (final ext in ['jpeg', 'JPG', 'gif', '', '.jpg', 'image/jpeg']) {
        expect(
          () =>
              StoragePaths.newFileName(clock, _ScriptedRandom(_hexBytes), ext),
          throwsArgumentError,
          reason: '"$ext"',
        );
      }
    });

    test(
      'güvenli rastgele kaynakla üretilen adlar şemaya uyar ve tekildir',
      () {
        final clock = FakeAppClock(_stamp);
        final random = Random.secure();
        final names = {
          for (var i = 0; i < 200; i++)
            StoragePaths.newFileName(clock, random, 'webp'),
        };

        expect(names, hasLength(200));
        expect(
          names,
          everyElement(matches(RegExp('^${StoragePaths.fileNamePattern}\$'))),
        );
      },
    );

    test('izinli içerik türleri uzantılara eşlenir', () {
      expect(StoragePaths.extensionByContentType, {
        'image/jpeg': 'jpg',
        'image/png': 'png',
        'image/webp': 'webp',
      });
    });
  });

  group('T-10 · StoragePaths · üreticiler ve doğrulayıcılar', () {
    test(
      'her yol <kök>/<kimlik>/<dosya> biçimindedir ve kendi doğrulayıcısından '
      'geçer',
      () {
        for (final (:root, :build, :check) in _roots) {
          final path = build('GU-7K3Q9X', _file);

          expect(path, '$root/GU-7K3Q9X/$_file');
          expect(check(path, 'GU-7K3Q9X'), isTrue, reason: root);
        }
      },
    );

    test('doğrulayıcı başka kimliği, başka kökü ve şema dışı dosya adını '
        'reddeder', () {
      for (final (:root, :build, :check) in _roots) {
        final path = build('id1', _file);
        final otherRoot = root == 'users' ? 'posts' : 'users';
        final rejected = [
          (path, 'id2'),
          (path, ''),
          ('$root/../$_file', '..'),
          (path, 'id'),
          ('$otherRoot/id1/$_file', 'id1'),
          ('$root/id1/avatar.jpg', 'id1'),
          ('$root/id1/logo.jpg', 'id1'),
          ('$root/id1/cover.jpg', 'id1'),
          ('$root/id1/0.jpg', 'id1'),
          ('$root/id1/${_file.toUpperCase()}', 'id1'),
          ('$root/id1/${_file.replaceFirst('.jpg', '.gif')}', 'id1'),
          ('$root/id1/alt/$_file', 'id1'),
          ('$root/id1/alt/$_file', 'id1/alt'),
          ('/$path', 'id1'),
          ('$path\n', 'id1'),
          ('x$path', 'id1'),
          ('$root/id1', 'id1'),
        ];

        for (final (candidate, id) in rejected) {
          expect(check(candidate, id), isFalse, reason: '$candidate · "$id"');
        }
      }
    });

    test('kimlikteki regex karakterleri düz metin sayılır', () {
      expect(
        StoragePaths.isUserAvatar('users/uXa/$_file', 'u.a'),
        isFalse,
      );
      expect(
        StoragePaths.isUserAvatar(StoragePaths.userAvatar('u.a', _file), 'u.a'),
        isTrue,
      );
      expect(
        StoragePaths.isUserAvatar('users/anything/$_file', '.*'),
        isFalse,
      );
    });

    test('üretici boş ya da "/" içeren kimliği ve şema dışı dosya adını '
        'reddeder (ArgumentError)', () {
      for (final (:root, :build, check: _) in _roots) {
        for (final id in ['', 'a/b', '/', '../x', '.', '..']) {
          expect(
            () => build(id, _file),
            throwsArgumentError,
            reason: '$root "$id"',
          );
        }
        for (final file in [
          '',
          'avatar.jpg',
          'cover.jpg',
          '0.jpg',
          'x/$_file',
          '$_file ',
          _file.replaceFirst('.jpg', '.gif'),
        ]) {
          expect(
            () => build('id1', file),
            throwsArgumentError,
            reason: '$root "$file"',
          );
        }
      }
    });
  });

  group('T-10 · StoragePaths · seed uyumu (PLAN §9.12)', () {
    test('demo gönderi görsellerinin yolları isPostImage doğrulayıcısından '
        'geçer', () {
      final docs = DemoDataFixture.build();
      var images = 0;

      for (final MapEntry(key: postId, value: post)
          in docs[FirestoreCollections.posts]!.entries) {
        for (final image in (post['images'] as List<Object?>?) ?? const []) {
          final path = (image! as Map<String, Object?>)['path']! as String;
          images++;

          expect(StoragePaths.isPostImage(path, postId), isTrue, reason: path);
        }
      }
      expect(images, greaterThan(0));
    });
  });
}
