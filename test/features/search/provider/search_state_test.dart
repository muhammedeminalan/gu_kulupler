// CLB-02 · SearchState: varsayılanlar, türetilen alanlar (`searchTerm`,
// `hasTerm`), `props` ve `copyWith` tüm alanları taşır (CLAUDE.md §2).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/features/search/provider/search_scope.dart';
import 'package:gu_kulupler/features/search/provider/search_state.dart';

import '../../../fixtures/event_model_fixtures.dart';
import '../../../fixtures/membership_model_fixtures.dart';
import '../search_test_support.dart';

void main() {
  group('CLB-02 · SearchState', () {
    test('varsayılan: boş sorgu, Kulüpler sekmesi, boş listeler', () {
      const state = SearchState();
      expect(state.query, isEmpty);
      expect(state.scope, SearchScope.clubs);
      expect(state.recent, isEmpty);
      expect(state.popular, isEmpty);
      expect(state.clubPool, isEmpty);
      expect(state.eventPool, isEmpty);
      expect(state.suggested, isEmpty);
      expect(state.managerPreviews, isEmpty);
      expect(state.clubResults, isEmpty);
      expect(state.eventResults, isEmpty);
      expect(state.recentBackup, isEmpty);
      expect(state.pendingJoinIds, isEmpty);
      expect(state.isFetching, isFalse);
      expect(state.isSearching, isFalse);
      expect(state.isError, isFalse);
      expect(state.hasTerm, isFalse);
    });

    test('searchTerm sorgunun kırpılmış halidir; yalnızca boşluk terim '
        'değildir', () {
      expect(const SearchState(query: '  satranç ').searchTerm, 'satranç');
      expect(const SearchState(query: '  satranç ').hasTerm, isTrue);
      expect(const SearchState(query: '   ').hasTerm, isFalse);
    });

    test('copyWith her alanı değiştirir; verilmeyen alan korunur; eşitlik '
        'tüm alanlara bakar', () {
      const base = SearchState();
      final manager = MembershipModelFixtures.byId('c03_u_burak');
      final variants = <SearchState>[
        base.copyWith(query: 'a'),
        base.copyWith(scope: SearchScope.events),
        base.copyWith(recent: const ['a']),
        base.copyWith(popular: const ['a']),
        base.copyWith(clubPool: [kPhoto]),
        base.copyWith(eventPool: [EventModelFixtures.e01]),
        base.copyWith(suggested: [kPhoto]),
        base.copyWith(
          managerPreviews: {
            'c03': [manager],
          },
        ),
        base.copyWith(clubResults: [kPhoto]),
        base.copyWith(eventResults: [EventModelFixtures.e01]),
        base.copyWith(recentBackup: const ['a']),
        base.copyWith(pendingJoinIds: const {'c07'}),
        base.copyWith(isFetching: true),
        base.copyWith(isSearching: true),
        base.copyWith(isError: true),
      ];
      for (final variant in variants) {
        expect(variant, isNot(base));
        expect(variant.copyWith(), variant);
      }
      expect(variants.toSet(), hasLength(variants.length));
      expect(base.copyWith(), base);
      expect(base.props, hasLength(15));
    });
  });
}
