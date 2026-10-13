// CLB-04 / CLB-05 · ClubApplicationState: varsayılanlar, `props` / `copyWith`
// tüm alanlar, evre eşlemesi, not farkı / sınırı ve yeniden başvuru beklemesi
// (PLAN §12.6).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/clubs/provider/club_application_state.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';

import '../../../fixtures/club_model_fixtures.dart';
import '../../../fixtures/membership_model_fixtures.dart';

void main() {
  final now = DateTime.utc(2026, 10, 12, 16, 30);
  final club = ClubModelFixtures.byId('c06');
  final pending = MembershipModelFixtures.byId('c06_u_mehmet');
  final rejected = MembershipModelFixtures.byId('c05_u_mehmet');

  ClubApplicationState withStatus(MembershipStatus status) =>
      ClubApplicationState(membership: pending.copyWith(status: status));

  group('CLB-05 · ClubApplicationState', () {
    test('varsayılan: kulüp ve üyelik yok, not boş, bayraklar kapalı', () {
      const state = ClubApplicationState();
      expect(state.club, isNull);
      expect(state.membership, isNull);
      expect(state.note, '');
      expect(state.savedNote, '');
      expect(state.errors, isEmpty);
      expect(state.submitError, isNull);
      expect(state.showNotificationPrompt, isFalse);
      expect(state.isFetching, isFalse);
      expect(state.isError, isFalse);
      expect(state.isNotFound, isFalse);
      expect(state.isSaving, isFalse);
      expect(state.isCancelling, isFalse);
      expect(state.isJoining, isFalse);
      expect(state.phase, ApplicationPhase.none);
      expect(state.isDirty, isFalse);
      expect(state.isBusy, isFalse);
      expect(state.canSaveNote, isFalse);
    });

    test('props tüm alanları içerir (13 alan)', () {
      final full = ClubApplicationState(
        club: club,
        membership: pending,
        note: 'yeni',
        savedNote: 'eski',
        errors: const {ApplicationField.note: FormFieldError.required},
        submitError: SubmitError.unknown,
        showNotificationPrompt: true,
        isFetching: true,
        isError: true,
        isNotFound: true,
        isSaving: true,
        isCancelling: true,
        isJoining: true,
      );
      expect(full.props, [
        club,
        pending,
        'yeni',
        'eski',
        const {ApplicationField.note: FormFieldError.required},
        SubmitError.unknown,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
      ]);
      expect(const ClubApplicationState(), const ClubApplicationState());
    });

    test('copyWith: her alan tek başına değişir, diğerleri korunur', () {
      const base = ClubApplicationState();
      const errors = {ApplicationField.note: FormFieldError.required};
      final variants = <ClubApplicationState>[
        base.copyWith(club: club),
        base.copyWith(membership: pending),
        base.copyWith(note: 'a'),
        base.copyWith(savedNote: 'b'),
        base.copyWith(errors: errors),
        base.copyWith(submitError: SubmitError.conflict),
        base.copyWith(showNotificationPrompt: true),
        base.copyWith(isFetching: true),
        base.copyWith(isError: true),
        base.copyWith(isNotFound: true),
        base.copyWith(isSaving: true),
        base.copyWith(isCancelling: true),
        base.copyWith(isJoining: true),
      ];
      expect(variants[0].club, club);
      expect(variants[1].membership, pending);
      expect(variants[2].note, 'a');
      expect(variants[3].savedNote, 'b');
      expect(variants[4].errors, errors);
      expect(variants[5].submitError, SubmitError.conflict);
      expect(variants[6].showNotificationPrompt, isTrue);
      expect(variants[7].isFetching, isTrue);
      expect(variants[8].isError, isTrue);
      expect(variants[9].isNotFound, isTrue);
      expect(variants[10].isSaving, isTrue);
      expect(variants[11].isCancelling, isTrue);
      expect(variants[12].isJoining, isTrue);
      // Her varyant yalnızca kendi alanında tabandan ayrılır.
      for (final (index, variant) in variants.indexed) {
        expect(variant, isNot(base), reason: 'varyant $index');
        final changed = [
          for (final (i, value) in variant.props.indexed)
            if (value != base.props[i]) i,
        ];
        expect(changed, [index], reason: 'varyant $index');
      }
      expect(base.copyWith(), base);
    });

    test(
      'copyWith: clear bayrakları alanı null yapar ve değere üstün gelir',
      () {
        final state = ClubApplicationState(
          membership: pending,
          submitError: SubmitError.unknown,
        );
        expect(state.copyWith().membership, pending);
        expect(state.copyWith().submitError, SubmitError.unknown);
        expect(state.copyWith(clearMembership: true).membership, isNull);
        expect(
          state
              .copyWith(membership: rejected, clearMembership: true)
              .membership,
          isNull,
        );
        expect(state.copyWith(clearSubmitError: true).submitError, isNull);
        expect(
          state
              .copyWith(
                submitError: SubmitError.network,
                clearSubmitError: true,
              )
              .submitError,
          isNull,
        );
      },
    );

    test('evre: üyelik durumundan; belge yok, iptal ve ayrılma "yok"', () {
      expect(ApplicationPhase.of(null), ApplicationPhase.none);
      expect(const ClubApplicationState().phase, ApplicationPhase.none);
      const expected = {
        MembershipStatus.pending: ApplicationPhase.pending,
        MembershipStatus.active: ApplicationPhase.approved,
        MembershipStatus.rejected: ApplicationPhase.rejected,
        MembershipStatus.removed: ApplicationPhase.removed,
        MembershipStatus.cancelled: ApplicationPhase.none,
        MembershipStatus.left: ApplicationPhase.none,
      };
      expect(expected.keys.toSet(), MembershipStatus.values.toSet());
      for (final MapEntry(key: status, value: phase) in expected.entries) {
        expect(ApplicationPhase.of(status), phase, reason: status.name);
        expect(withStatus(status).phase, phase, reason: status.name);
      }
    });

    test('isDirty: kırpılmış not sunucudakinden farklıysa', () {
      const saved = ClubApplicationState(note: 'not', savedNote: 'not');
      expect(saved.isDirty, isFalse);
      expect(saved.copyWith(note: '  not \n').isDirty, isFalse);
      expect(saved.copyWith(note: 'not!').isDirty, isTrue);
      expect(saved.copyWith(note: '').isDirty, isTrue);
    });

    test('canSaveNote: bekleyen başvuru + değişmiş not + sınırın içinde', () {
      final base = ClubApplicationState(
        membership: pending,
        note: 'yeni',
        savedNote: 'eski',
      );
      expect(base.canSaveNote, isTrue);
      expect(base.copyWith(note: 'eski').canSaveNote, isFalse);
      expect(
        base.copyWith(membership: rejected).canSaveNote,
        isFalse,
        reason: 'bekleyen başvuru değil',
      );

      final atLimit = base.copyWith(note: 'a' * Limits.applicationNoteMax);
      expect(atLimit.isNoteTooLong, isFalse);
      expect(atLimit.canSaveNote, isTrue);
      final over = base.copyWith(note: 'a' * (Limits.applicationNoteMax + 1));
      expect(over.isNoteTooLong, isTrue);
      expect(over.canSaveNote, isFalse);
      // Sınır kırpılmış metne uygulanır.
      final padded = base.copyWith(
        note: ' ${'a' * Limits.applicationNoteMax} ',
      );
      expect(padded.isNoteTooLong, isFalse);
    });

    test('isBusy: kayıt, iptal ya da katılım sürerken', () {
      const base = ClubApplicationState();
      expect(base.copyWith(isSaving: true).isBusy, isTrue);
      expect(base.copyWith(isCancelling: true).isBusy, isTrue);
      expect(base.copyWith(isJoining: true).isBusy, isTrue);
      expect(base.copyWith(isFetching: true).isBusy, isFalse);
    });

    test('yeniden başvuru: bekleme anı yoksa ya da geldiyse açık', () {
      const none = ClubApplicationState();
      expect(none.retryAfter, isNull);
      expect(none.canReapplyAt(now), isTrue);
      expect(none.remainingUntilRetry(now), isNull);

      final until = now.add(const Duration(days: 3, hours: 2));
      final waiting = ClubApplicationState(
        membership: rejected.copyWith(retryAfter: until),
      );
      expect(waiting.retryAfter, until);
      expect(waiting.canReapplyAt(now), isFalse);
      expect(
        waiting.remainingUntilRetry(now),
        const Duration(days: 3, hours: 2),
      );
      // Tam bekleme anında açılır.
      expect(waiting.canReapplyAt(until), isTrue);
      expect(waiting.remainingUntilRetry(until), isNull);
      expect(
        waiting.canReapplyAt(until.add(const Duration(seconds: 1))),
        isTrue,
      );

      final cleared = ClubApplicationState(
        membership: rejected.copyWith(clearRetryAfter: true),
      );
      expect(cleared.canReapplyAt(now), isTrue);
    });
  });
}
