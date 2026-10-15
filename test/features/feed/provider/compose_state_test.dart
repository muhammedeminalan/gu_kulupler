// FED-03 · ComposeState: varsayılanlar, `copyWith` (tüm alanlar + önizleme
// temizleme bayrağı), değer eşitliği, türetilmişler (geçerlilik, hak, görsel
// ve seçenek sınırları, kilitli anket), `ComposeImage`, taslak kodlaması
// (`ComposeDraft` — CD-45).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/feed/provider/compose_state.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';

import '../../../fakes/fake_image_picker_service.dart';
import '../compose_test_support.dart';

void main() {
  group('FED-03 · ComposeState', () {
    test('varsayılan: boş gönderi formu, bayraklar kapalı', () {
      const state = ComposeState();
      expect(state.type, PostType.post);
      expect(state.title, isEmpty);
      expect(state.text, isEmpty);
      expect(state.images, isEmpty);
      expect(state.pollOptions, ['', '']);
      expect(state.pollDuration, PollDuration.d3);
      expect(state.showResultsAfterVote, isTrue);
      expect(state.pushEnabled, isTrue);
      expect(state.pinAfterPublish, isFalse);
      expect(state.quotaUsed, 0);
      expect(state.quotaLimit, Limits.announcementDailyLimit);
      expect(state.errors, isEmpty);
      expect(state.club, isNull);
      expect(state.editPost, isNull);
      expect(state.preview, isNull);
      expect(state.hasDraft || state.isDirty || state.isSubmitting, isFalse);
      expect(state.isSavingDraft || state.isSubmitError, isFalse);
      expect(state.isLoadingEdit || state.isError, isFalse);
      expect(state.isEditing || state.isPreview || state.isValid, isFalse);
    });

    test('copyWith her alanı değiştirir; clearPreview önizlemeyi kapatır; '
        'props değer eşitliği taşır', () {
      final images = [ComposeImage.remote(kEditPost.images.first)];
      const errors = {ComposeField.text: FormFieldError.required};
      final full = const ComposeState().copyWith(
        type: PostType.poll,
        title: 'başlık',
        text: 'metin',
        images: images,
        pollOptions: const ['a', 'b', 'c'],
        pollDuration: PollDuration.d7,
        showResultsAfterVote: false,
        pushEnabled: false,
        pinAfterPublish: true,
        quotaUsed: 1,
        quotaLimit: 3,
        hasDraft: true,
        errors: errors,
        isDirty: true,
        isSubmitting: true,
        isSavingDraft: true,
        isSubmitError: true,
        isLoadingEdit: true,
        isError: true,
        preview: kEditPost,
        club: kComposeClub,
        editPost: kEditPoll,
      );
      expect(full.props, [
        PostType.poll,
        'başlık',
        'metin',
        images,
        ['a', 'b', 'c'],
        PollDuration.d7,
        false,
        false,
        true,
        1,
        3,
        true,
        errors,
        true,
        true,
        true,
        true,
        true,
        true,
        kEditPost,
        kComposeClub,
        kEditPoll,
      ]);
      expect(full.copyWith(), full);
      expect(full, isNot(const ComposeState()));
      expect(full.isPreview, isTrue);
      final closed = full.copyWith(clearPreview: true, preview: kEditPost);
      expect(closed.preview, isNull);
      expect(closed.copyWith(preview: kEditPost), full);
    });

    test('geçerlilik türe göre: metin; duyuruda başlık; ankette iki dolu '
        'seçenek (kırpılarak)', () {
      const state = ComposeState(text: ' Merhaba ');
      expect(state.isValid, isTrue);
      expect(state.copyWith(text: '   ').isValid, isFalse);
      final announcement = state.copyWith(type: PostType.announcement);
      expect(announcement.isValid, isFalse);
      expect(announcement.copyWith(title: 'Başlık').isValid, isTrue);
      final poll = state.copyWith(
        type: PostType.poll,
        pollOptions: const [' a ', '  ', 'b'],
      );
      expect(poll.filledOptions, ['a', 'b']);
      expect(poll.isValid, isTrue);
      expect(poll.copyWith(pollOptions: const ['a', '']).isValid, isFalse);
    });

    test('hak, görsel ve seçenek sınırları; düzenlenen anket kilitlidir', () {
      const state = ComposeState(quotaUsed: 1);
      expect(state.limitReached, isFalse);
      expect(state.pushActive, isTrue);
      final full = state.copyWith(quotaUsed: 2);
      expect(full.limitReached, isTrue);
      expect(full.pushActive, isFalse);
      expect(state.copyWith(pushEnabled: false).pushActive, isFalse);

      expect(state.canAddImage, isTrue);
      expect(
        state
            .copyWith(
              images: [
                for (var index = 0; index < Limits.postImagesMax; index++)
                  ComposeImage.local(kFakeJpeg),
              ],
            )
            .canAddImage,
        isFalse,
      );

      expect(state.canAddPollOption, isTrue);
      expect(state.canRemovePollOption, isFalse);
      final four = state.copyWith(pollOptions: const ['a', 'b', 'c', 'd']);
      expect(four.canAddPollOption, isFalse);
      expect(four.canRemovePollOption, isTrue);

      final locked = four.copyWith(type: PostType.poll, editPost: kEditPoll);
      expect(locked.isEditing && locked.isPollLocked, isTrue);
      expect(locked.canAddPollOption || locked.canRemovePollOption, isFalse);
      expect(four.copyWith(editPost: kEditPost).isPollLocked, isFalse);
    });

    test('ComposeImage: yeni görsel yüklenince baytlarını korur; önizleme '
        'modeli yüklenmemişte geçici yol taşır', () {
      final local = ComposeImage.local(kFakeJpeg);
      expect(local.isUploaded, isFalse);
      expect(local.previewModel(2).path, ComposeImage.previewPath(2));
      expect(local.previewModel(2).w, kFakeJpeg.width);
      final model = kEditPost.images.first;
      final uploaded = local.withUploaded(model);
      expect(uploaded.isUploaded, isTrue);
      expect(uploaded.picked, same(kFakeJpeg));
      expect(uploaded.previewModel(2), model);
      expect(uploaded, isNot(local));
      expect(ComposeImage.remote(model).picked, isNull);
      expect(ComposeImage.remote(model), ComposeImage.remote(model));
    });
  });

  group('FED-03 · ComposeDraft (CD-45)', () {
    test('kodla → çöz alanları geri verir; görseller ve geçici durum '
        'saklanmaz', () {
      final state = const ComposeState().copyWith(
        type: PostType.announcement,
        title: 'başlık',
        text: 'metin',
        images: [ComposeImage.local(kFakeJpeg)],
        pollOptions: const ['a', 'b', 'c'],
        pollDuration: PollDuration.d1,
        showResultsAfterVote: false,
        pushEnabled: false,
        pinAfterPublish: true,
        quotaUsed: 2,
        isDirty: true,
        club: kComposeClub,
      );
      expect(
        ComposeDraft.decode(
          ComposeDraft.encode(state, ownerUid: kComposeUid),
          uid: kComposeUid,
        ),
        const ComposeState().copyWith(
          type: PostType.announcement,
          title: 'başlık',
          text: 'metin',
          pollOptions: const ['a', 'b', 'c'],
          pollDuration: PollDuration.d1,
          showResultsAfterVote: false,
          pushEnabled: false,
          pinAfterPublish: true,
          hasDraft: true,
        ),
      );
    });

    test('taslak yok / bozuk / yanlış biçim → null; eksik ve sınır dışı '
        'değerler varsayılana düşer ya da kesilir', () {
      ComposeState? decode(String? json) =>
          ComposeDraft.decode(json, uid: kComposeUid);
      const owner = '"ownerUid":"$kComposeUid"';
      expect(decode(null), isNull);
      expect(decode(''), isNull);
      expect(decode('{bozuk'), isNull);
      expect(decode('[1, 2]'), isNull);

      final empty = decode('{$owner}')!;
      expect(empty, const ComposeState(hasDraft: true));

      final odd = decode(
        '{$owner,"type":"video","title":7,"text":"${'x' * 1200}",'
        '"options":["a",3,"b","c","d","e"],"duration":5}',
      )!;
      expect(odd.type, PostType.post);
      expect(odd.title, isEmpty);
      expect(odd.text, hasLength(Limits.postTextMax));
      expect(odd.pollOptions, ['a', 'b', 'c', 'd']);
      expect(odd.pollDuration, PollDuration.d3);
      expect(decode('{$owner,"options":["a"]}')!.pollOptions, ['a', '']);
    });

    test("T-45 · A3-02 · taslak yazarın uid'siyle etiketlenir: başka hesap "
        've etiketsiz (eski) kayıt null', () {
      final json = ComposeDraft.encode(
        const ComposeState(text: 'yayımlanmamış duyuru'),
        ownerUid: 'u_a',
      );
      expect(
        ComposeDraft.decode(json, uid: 'u_a')!.text,
        'yayımlanmamış duyuru',
      );
      expect(ComposeDraft.decode(json, uid: 'u_b'), isNull);
      expect(ComposeDraft.decode('{"text":"eski"}', uid: 'u_a'), isNull);
      expect(
        ComposeDraft.decode('{"ownerUid":7,"text":"x"}', uid: 'u_a'),
        isNull,
      );
    });
  });
}
