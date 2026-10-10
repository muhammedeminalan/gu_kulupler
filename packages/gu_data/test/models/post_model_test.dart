// T-09 · PostModel + gömülü PostImageModel / PollModel / PollOptionModel
// (PLAN §9.6.6, §9.10, §9.11): alan adları, JSON anahtarları ve varsayılanlar
// PLAN tablosundan OKUNARAK; gidiş-dönüş (Timestamp ↔ UTC DateTime), iç içe
// nesneler, eksik/geçersiz alan toleransı, copyWith + eşitlik, türetilmişler.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:json_annotation/json_annotation.dart';

import '../fakes/fake_app_clock.dart';
import '../helpers/plan_feed_schema.dart';

const String _table = '#### 9.6.6 ';

final DateTime _created = DateTime.utc(2026, 9, 30, 5, 0, 0, 123);
final DateTime _pollEnds = DateTime.utc(2026, 10, 7, 5);

const PostImageModel _image = PostImageModel(
  path: 'posts/p02/20260930T050000Z_3f9a1c2b7d4e5f60.png',
  w: 1200,
  h: 900,
);

const PollOptionModel _option = PollOptionModel(id: 'o1', text: 'Pop');

final PollModel _poll = PollModel(
  options: const [
    _option,
    PollOptionModel(id: 'o2', text: 'Rock'),
  ],
  endsAt: _pollEnds,
  showResultsAfterVote: false,
);

/// Her alanı dolu (varsayılanından farklı) gönderi. Serileştirme
/// fixture'ıdır; tür kuralları (başlık yalnızca duyuruda …) doğrulayıcıların
/// işidir.
final PostModel _full = PostModel(
  id: 'p18',
  clubId: 'c06',
  authorId: 'u_ayse',
  type: PostType.poll,
  title: 'Açık mikrofon',
  text: 'En çok hangi türü görmek istersin?',
  images: const [_image],
  poll: _poll,
  pinned: true,
  pushSent: true,
  likes: const ['u_mehmet', 'u042'],
  likeCount: 2,
  commentCount: 3,
  lastCommentRef: 'comments/cm07',
  isHidden: true,
  hiddenBy: 'u_admin',
  hiddenAt: _created.add(const Duration(days: 2)),
  editedAt: _created.add(const Duration(hours: 1)),
  createdAt: _created,
  updatedAt: _created.add(const Duration(hours: 2)),
  isDeleted: true,
  deletedAt: _created.add(const Duration(days: 3)),
  deletedBy: 'u_zeynep',
);

/// Yalnızca zorunlu alanları taşıyan belge verisi.
const Map<String, Object?> _minimalJson = {
  FirestoreFields.clubId: 'c06',
  FirestoreFields.authorId: 'u_ayse',
  FirestoreFields.text: 'Merhaba',
};

/// Modelin tüm alanları, PLAN tablosundaki sırayla (alan adı → değer).
Map<String, Object?> _fields(PostModel m) => {
  'id': m.id,
  'clubId': m.clubId,
  'authorId': m.authorId,
  'type': m.type,
  'title': m.title,
  'text': m.text,
  'images': m.images,
  'poll': m.poll,
  'pinned': m.pinned,
  'pushSent': m.pushSent,
  'likes': m.likes,
  'likeCount': m.likeCount,
  'commentCount': m.commentCount,
  'lastCommentRef': m.lastCommentRef,
  'isHidden': m.isHidden,
  'hiddenBy': m.hiddenBy,
  'hiddenAt': m.hiddenAt,
  'editedAt': m.editedAt,
  'createdAt': m.createdAt,
  'updatedAt': m.updatedAt,
  'isDeleted': m.isDeleted,
  'deletedAt': m.deletedAt,
  'deletedBy': m.deletedBy,
};

void _changes(PostModel changed, String field, Object? value) =>
    expectSingleFieldChange(
      base: _full,
      changed: changed,
      fields: _fields,
      field: field,
      value: value,
    );

Matcher _throwsChecked(String key) => throwsA(
  isA<CheckedFromJsonException>().having((e) => e.key, 'key', key),
);

void main() {
  group('T-09 · PostModel · şema', () {
    test('alan adları PLAN §9.6.6 tablosuyla birebir, props hepsini taşır', () {
      expect(_fields(_full).keys, planFieldNames(_table));
      expect(_full.props, _fields(_full).values);
    });

    test('toJson anahtarları PLAN tablosunun JSON sütunuyla aynı', () {
      // Tablo belge kimliğini JSON'a yazmaz: küme eşitliği `id` anahtarının
      // bulunmadığını da doğrular.
      expect(_full.toJson().keys.toSet(), planJsonKeys(_table));
    });

    test('null alanlar yüke girmez (include_if_null: false)', () {
      final json = PostModel.fromJson(_minimalJson, id: 'p01').toJson();

      expect(json.keys.toSet(), {
        FirestoreFields.clubId,
        FirestoreFields.authorId,
        FirestoreFields.type,
        FirestoreFields.text,
        FirestoreFields.images,
        FirestoreFields.pinned,
        FirestoreFields.pushSent,
        FirestoreFields.likes,
        FirestoreFields.likeCount,
        FirestoreFields.commentCount,
        FirestoreFields.isHidden,
        FirestoreFields.isDeleted,
      });
    });
  });

  group('T-09 · PostModel · fromJson / toJson', () {
    test('gidiş-dönüş modeli korur; zamanlar Timestamp ↔ UTC DateTime', () {
      final json = _full.toJson();
      final back = PostModel.fromJson(json, id: _full.id);

      expect(back, _full);
      for (final key in [
        FirestoreFields.hiddenAt,
        FirestoreFields.editedAt,
        FirestoreFields.createdAt,
        FirestoreFields.updatedAt,
        FirestoreFields.deletedAt,
      ]) {
        expect(json[key], isA<Timestamp>(), reason: key);
      }
      expect(json[FirestoreFields.type], 'poll');
      expect(
        [
          back.hiddenAt,
          back.editedAt,
          back.createdAt,
          back.updatedAt,
          back.deletedAt,
          back.poll!.endsAt,
        ].map((at) => at!.isUtc),
        everyElement(isTrue),
      );
      expect(
        back.createdAt!.millisecondsSinceEpoch,
        _created.millisecondsSinceEpoch,
      );
    });

    test('iç içe nesneler map olarak yazılır (explicit_to_json)', () {
      final json = _full.toJson();
      final poll = json[FirestoreFields.poll]! as Map<String, Object?>;

      expect(json[FirestoreFields.images], [_image.toJson()]);
      expect(poll[FirestoreFields.endsAt], Timestamp.fromDate(_pollEnds));
      expect(poll[FirestoreFields.options], [
        {FirestoreFields.id: 'o1', FirestoreFields.text: 'Pop'},
        {FirestoreFields.id: 'o2', FirestoreFields.text: 'Rock'},
      ]);
    });

    test('eksik anahtarlar PLAN tablosundaki varsayılanları alır', () {
      final model = PostModel.fromJson(_minimalJson, id: 'p01');
      final defaults = planDefaults(_table);
      final fields = _fields(model);

      expect({
        for (final field in defaults.keys) field: planLiteral(fields[field]),
      }, defaults);
      expect(
        model,
        const PostModel(
          id: 'p01',
          clubId: 'c06',
          authorId: 'u_ayse',
          text: 'Merhaba',
        ),
        reason: 'eksik anahtar = kurucu varsayılanı',
      );
      expect(model.isLive, isTrue);
      expect(model.createdBy, isNull);
    });

    test('tanınmayan anahtar yok sayılır', () {
      expect(
        PostModel.fromJson(const {
          ..._minimalJson,
          'commentIds': <String>[],
          'id': 'başka',
        }, id: 'p01'),
        PostModel.fromJson(_minimalJson, id: 'p01'),
      );
    });

    test('eksik zorunlu alan ve bilinmeyen tür CheckedFromJsonException', () {
      for (final key in _minimalJson.keys) {
        expect(
          () => PostModel.fromJson({..._minimalJson}..remove(key), id: 'p01'),
          _throwsChecked(key),
        );
      }
      expect(
        () => PostModel.fromJson(const {
          ..._minimalJson,
          FirestoreFields.type: 'story',
        }, id: 'p01'),
        _throwsChecked(FirestoreFields.type),
      );
    });
  });

  group('T-09 · PostModel · copyWith / eşitlik', () {
    final later = DateTime.utc(2027);

    test('parametresiz copyWith aynı modeli verir', () {
      expect(_full.copyWith(), _full);
    });

    test('her alan tek başına değişir ve eşitliği bozar', () {
      const image = PostImageModel(path: 'posts/p18/x.png', w: 1, h: 2);
      final poll = _poll.copyWith(showResultsAfterVote: true);

      _changes(_full.copyWith(id: 'p99'), 'id', 'p99');
      _changes(_full.copyWith(clubId: 'c99'), 'clubId', 'c99');
      _changes(_full.copyWith(authorId: 'u99'), 'authorId', 'u99');
      _changes(
        _full.copyWith(type: PostType.announcement),
        'type',
        PostType.announcement,
      );
      _changes(_full.copyWith(title: 'Yeni'), 'title', 'Yeni');
      _changes(_full.copyWith(text: 'Yeni metin'), 'text', 'Yeni metin');
      _changes(_full.copyWith(images: const [image]), 'images', [image]);
      _changes(_full.copyWith(poll: poll), 'poll', poll);
      _changes(_full.copyWith(pinned: false), 'pinned', false);
      _changes(_full.copyWith(pushSent: false), 'pushSent', false);
      _changes(_full.copyWith(likes: const ['u1']), 'likes', ['u1']);
      _changes(_full.copyWith(likeCount: 9), 'likeCount', 9);
      _changes(_full.copyWith(commentCount: 8), 'commentCount', 8);
      _changes(
        _full.copyWith(lastCommentRef: 'comments/cm99'),
        'lastCommentRef',
        'comments/cm99',
      );
      _changes(_full.copyWith(isHidden: false), 'isHidden', false);
      _changes(_full.copyWith(hiddenBy: 'u99'), 'hiddenBy', 'u99');
      _changes(_full.copyWith(hiddenAt: later), 'hiddenAt', later);
      _changes(_full.copyWith(editedAt: later), 'editedAt', later);
      _changes(_full.copyWith(createdAt: later), 'createdAt', later);
      _changes(_full.copyWith(updatedAt: later), 'updatedAt', later);
      _changes(_full.copyWith(isDeleted: false), 'isDeleted', false);
      _changes(_full.copyWith(deletedAt: later), 'deletedAt', later);
      _changes(_full.copyWith(deletedBy: 'u99'), 'deletedBy', 'u99');
    });

    test('null olabilen her alan clear bayrağıyla null olur', () {
      _changes(_full.copyWith(clearTitle: true), 'title', null);
      _changes(_full.copyWith(clearPoll: true), 'poll', null);
      _changes(
        _full.copyWith(clearLastCommentRef: true),
        'lastCommentRef',
        null,
      );
      _changes(_full.copyWith(clearHiddenBy: true), 'hiddenBy', null);
      _changes(_full.copyWith(clearHiddenAt: true), 'hiddenAt', null);
      _changes(_full.copyWith(clearEditedAt: true), 'editedAt', null);
      _changes(_full.copyWith(clearCreatedAt: true), 'createdAt', null);
      _changes(_full.copyWith(clearUpdatedAt: true), 'updatedAt', null);
      _changes(_full.copyWith(clearDeletedAt: true), 'deletedAt', null);
      _changes(_full.copyWith(clearDeletedBy: true), 'deletedBy', null);
    });
  });

  group('T-09 · PostModel · türetilmişler', () {
    const post = PostModel(clubId: 'c06', authorId: 'u_ayse', text: 'Merhaba');

    test('isPoll / isAnnouncement türe bağlıdır', () {
      expect(
        [
          for (final type in PostType.values)
            (
              post.copyWith(type: type).isPoll,
              post.copyWith(type: type).isAnnouncement,
            ),
        ],
        [(false, false), (false, true), (true, false)],
      );
    });

    test('pollEnded: bitiş anı kapalı sayılır; anket yoksa false', () {
      final clock = FakeAppClock(
        _pollEnds.subtract(const Duration(milliseconds: 1)),
      );

      expect(_full.pollEnded(clock), isFalse);
      clock.set(_pollEnds);
      expect(_full.pollEnded(clock), isTrue);
      expect(post.pollEnded(clock), isFalse);
    });

    test('withLike beğeniyi ekler / kaldırır, sayacı ±1 oynatır', () {
      final liked = post.withLike('u1', liked: true);
      expect(liked, post.copyWith(likes: ['u1'], likeCount: 1));
      expect(liked.likedBy('u1'), isTrue);

      final unliked = liked.withLike('u1', liked: false);
      expect(unliked, post);
      expect(unliked.likedBy('u1'), isFalse);
    });

    test('withLike durum değişmiyorsa aynı modeli döner', () {
      expect(post.withLike('u1', liked: false), same(post));
      expect(_full.withLike('u042', liked: true), same(_full));
    });
  });

  group('T-09 · PostImageModel', () {
    test('JSON anahtarları PLAN tanımıyla aynı; gidiş-dönüş korur', () {
      final json = _image.toJson();

      expect(json.keys, planEmbeddedKeys('PostImageModel'));
      expect(PostImageModel.fromJson(json), _image);
    });

    test('copyWith her alanı değiştirir, props hepsini taşır', () {
      Map<String, Object?> fields(PostImageModel m) => {
        'path': m.path,
        'w': m.w,
        'h': m.h,
      };
      void changes(PostImageModel changed, String field, Object? value) =>
          expectSingleFieldChange(
            base: _image,
            changed: changed,
            fields: fields,
            field: field,
            value: value,
          );

      expect(_image.props, fields(_image).values);
      changes(
        _image.copyWith(path: 'posts/p02/y.png'),
        'path',
        'posts/p02/y.png',
      );
      changes(_image.copyWith(w: 1), 'w', 1);
      changes(_image.copyWith(h: 2), 'h', 2);
    });
  });

  group('T-09 · PollOptionModel', () {
    test('JSON anahtarları PLAN tanımıyla aynı; gidiş-dönüş korur', () {
      final json = _option.toJson();

      expect(json.keys, planEmbeddedKeys('PollOptionModel'));
      expect(PollOptionModel.fromJson(json), _option);
    });

    test('copyWith her alanı değiştirir, props hepsini taşır', () {
      Map<String, Object?> fields(PollOptionModel m) => {
        'id': m.id,
        'text': m.text,
      };
      void changes(PollOptionModel changed, String field, Object? value) =>
          expectSingleFieldChange(
            base: _option,
            changed: changed,
            fields: fields,
            field: field,
            value: value,
          );

      expect(_option.props, fields(_option).values);
      changes(_option.copyWith(id: 'o4'), 'id', 'o4');
      changes(_option.copyWith(text: 'Caz'), 'text', 'Caz');
    });
  });

  group('T-09 · PollModel', () {
    final optionsJson = [_option.toJson()];

    test('JSON anahtarları PLAN tanımıyla aynı; gidiş-dönüş korur', () {
      final json = _poll.toJson();

      expect(json.keys, planEmbeddedKeys('PollModel'));
      expect(PollModel.fromJson(json), _poll);
    });

    test('showResultsAfterVote eksikse true (kurucu varsayılanı)', () {
      final poll = PollModel.fromJson({
        FirestoreFields.options: optionsJson,
        FirestoreFields.endsAt: Timestamp.fromDate(_pollEnds),
      });

      expect(poll, PollModel(options: const [_option], endsAt: _pollEnds));
      expect(poll.showResultsAfterVote, isTrue);
    });

    test('endsAt eksik ya da null ise CheckedFromJsonException', () {
      for (final json in [
        {FirestoreFields.options: optionsJson},
        {FirestoreFields.options: optionsJson, FirestoreFields.endsAt: null},
      ]) {
        expect(
          () => PollModel.fromJson(json),
          _throwsChecked(FirestoreFields.endsAt),
        );
      }
    });

    test('copyWith her alanı değiştirir, props hepsini taşır', () {
      Map<String, Object?> fields(PollModel m) => {
        'options': m.options,
        'endsAt': m.endsAt,
        'showResultsAfterVote': m.showResultsAfterVote,
      };
      void changes(PollModel changed, String field, Object? value) =>
          expectSingleFieldChange(
            base: _poll,
            changed: changed,
            fields: fields,
            field: field,
            value: value,
          );
      final later = DateTime.utc(2027);

      expect(_poll.props, fields(_poll).values);
      changes(_poll.copyWith(options: const [_option]), 'options', [_option]);
      changes(_poll.copyWith(endsAt: later), 'endsAt', later);
      changes(
        _poll.copyWith(showResultsAfterVote: true),
        'showResultsAfterVote',
        true,
      );
    });
  });
}
