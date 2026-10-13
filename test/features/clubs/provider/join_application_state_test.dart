// SHT-05 · JoinApplicationState: varsayılanlar, türetilmiş alanlar (kirli
// form, not zorunluluğu, anında katılım, bekleme süresi), `props` ve
// `copyWith` (tüm alanlar + temizleme bayrakları).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/clubs/provider/join_application_state.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';

import '../../../fixtures/club_model_fixtures.dart';
import '../../../fixtures/membership_model_fixtures.dart';

final ClubModel _club = ClubModelFixtures.byId('c03');
final MembershipModel _membership = MembershipModelFixtures.c01Mehmet;
final DateTime _now = DateTime.utc(2026, 10, 12, 16, 30);

void main() {
  group('SHT-05 · JoinApplicationState', () {
    test('varsayılan: kulüp yok, not boş, bayraklar kapalı', () {
      const state = JoinApplicationState();
      expect(state.club, isNull);
      expect(state.membership, isNull);
      expect(state.note, '');
      expect(state.errors, isEmpty);
      expect(state.isFetching, isFalse);
      expect(state.isError, isFalse);
      expect(state.isSubmitting, isFalse);
      expect(state.submitError, isNull);
      expect(state.isDirty, isFalse);
      expect(state.requireNote, isFalse);
      expect(state.isInstant, isFalse);
      expect(state.retryAfter, isNull);
      expect(state.isWaiting(_now), isFalse);
    });

    test('`isDirty`: not boş değilse (boşluk dahil) kirlidir', () {
      expect(const JoinApplicationState(note: 'a').isDirty, isTrue);
      expect(const JoinApplicationState(note: ' ').isDirty, isTrue);
    });

    test('`isInstant`: yalnızca onaysız kulüp + eski kaydı olmayan '
        'kullanıcı', () {
      final open = _club.copyWith(approvalRequired: false);
      expect(JoinApplicationState(club: _club).isInstant, isFalse);
      expect(JoinApplicationState(club: open).isInstant, isTrue);
      for (final status in MembershipStatus.values) {
        final state = JoinApplicationState(
          club: open,
          membership: _membership.copyWith(status: status),
        );
        expect(
          state.isInstant,
          !JoinApplicationState.reviewStatuses.contains(status),
          reason: status.name,
        );
      }
      expect(JoinApplicationState.reviewStatuses, {
        MembershipStatus.rejected,
        MembershipStatus.removed,
        MembershipStatus.cancelled,
      });
    });

    test('`requireNote`: kulüp not istiyor ve başvuru onaya gidiyorsa', () {
      final noted = _club.copyWith(requireNote: true);
      expect(JoinApplicationState(club: noted).requireNote, isTrue);
      expect(
        JoinApplicationState(
          club: _club.copyWith(requireNote: false),
        ).requireNote,
        isFalse,
      );
      // Anında katılımda not yazılmaz.
      expect(
        JoinApplicationState(
          club: noted.copyWith(approvalRequired: false),
        ).requireNote,
        isFalse,
      );
    });

    test('`retryAfter` / `isWaiting`: üyelikteki an gelecekteyse bekler', () {
      final later = JoinApplicationState(
        membership: _membership.copyWith(
          status: MembershipStatus.rejected,
          retryAfter: _now.add(const Duration(seconds: 1)),
        ),
      );
      expect(later.retryAfter, _now.add(const Duration(seconds: 1)));
      expect(later.isWaiting(_now), isTrue);
      expect(later.isWaiting(_now.add(const Duration(seconds: 1))), isFalse);
      expect(later.isWaiting(_now.add(const Duration(days: 1))), isFalse);
      expect(
        JoinApplicationState(membership: _membership).isWaiting(_now),
        isFalse,
      );
    });

    test('`props` tüm alanları taşır; her alan eşitliği bozar', () {
      const base = JoinApplicationState();
      expect(base.props, hasLength(8));
      final variants = [
        JoinApplicationState(club: _club),
        JoinApplicationState(membership: _membership),
        const JoinApplicationState(note: 'x'),
        const JoinApplicationState(
          errors: {JoinApplicationField.note: FormFieldError.required},
        ),
        const JoinApplicationState(isFetching: true),
        const JoinApplicationState(isError: true),
        const JoinApplicationState(isSubmitting: true),
        const JoinApplicationState(submitError: SubmitError.unknown),
      ];
      for (final variant in variants) {
        expect(variant, isNot(base));
      }
      expect(const JoinApplicationState(), base);
    });

    test('`copyWith` her alanı değiştirir, verilmeyeni korur', () {
      final full = const JoinApplicationState().copyWith(
        club: _club,
        membership: _membership,
        note: 'not',
        errors: {JoinApplicationField.note: FormFieldError.tooLong},
        isFetching: true,
        isError: true,
        isSubmitting: true,
        submitError: SubmitError.conflict,
      );
      expect(
        full,
        JoinApplicationState(
          club: _club,
          membership: _membership,
          note: 'not',
          errors: const {JoinApplicationField.note: FormFieldError.tooLong},
          isFetching: true,
          isError: true,
          isSubmitting: true,
          submitError: SubmitError.conflict,
        ),
      );
      expect(full.copyWith(), full);
    });

    test('`clearMembership` ve `clearSubmitError` alanı siler ve aynı adlı '
        'parametreden önce gelir', () {
      final full = JoinApplicationState(
        club: _club,
        membership: _membership,
        submitError: SubmitError.network,
      );
      final cleared = full.copyWith(
        membership: _membership,
        clearMembership: true,
        submitError: SubmitError.unknown,
        clearSubmitError: true,
      );
      expect(cleared.membership, isNull);
      expect(cleared.submitError, isNull);
      expect(cleared.club, _club);
    });
  });
}
