import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('explore filters', () {
    late String categoryChips;
    late String exploreScreen;

    setUpAll(() {
      categoryChips = File(
        'lib/features/explore/widgets/category_chips.dart',
      ).readAsStringSync();
      exploreScreen = File(
        'lib/features/explore/screens/explore_screen.dart',
      ).readAsStringSync();
    });

    test('exposes every rental category including etc', () {
      expect(categoryChips, contains("('all', l.categoryAll"));
      expect(categoryChips, contains("('etc', l.categoryOther"));
    });

    test('loads all rentals when no chip or search is selected', () {
      expect(exploreScreen, contains('RentalFilter get _currentFilter'));
      expect(exploreScreen, contains('paginatedRentalsFilterProvider(filter)'));
      expect(exploreScreen, isNot(contains('selectCategoryOrSearch')));
    });
  });
}
