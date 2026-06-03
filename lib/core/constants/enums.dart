import '../../l10n/app_localizations.dart';

/// Reservation lifecycle. Mirrors the Postgres `reservation_status` ENUM
/// from migration 017. See docs/escrow-state-machine.md for the diagram.
///
/// Naming differences from the old enum:
/// - `accepted` removed: payment is the acceptance signal (no separate
///   lender-approval step before PortOne capture).
/// - `completed` → `settled`: explicitly names the money-distributed
///   terminal state; `completed` was ambiguous.
/// - `returned_` → `returned`: the underscore was only there to avoid the
///   Dart reserved word `return`, but `returned` is fine as an identifier.
/// - `settled` and `resolved` added (terminal states).
enum ReservationStatus {
  pending,
  paid,
  pickedUp('picked_up'),
  returned,
  settled,
  cancelled,
  disputed,
  resolved;

  const ReservationStatus([this._value]);
  final String? _value;

  String get value => _value ?? name;

  /// Terminal states cannot be transitioned out of. Three of them, one per
  /// money-distribution outcome (see docs/escrow-state-machine.md).
  bool get isTerminal => switch (this) {
        settled || cancelled || resolved => true,
        _ => false,
      };

  static ReservationStatus fromString(String s) =>
      values.firstWhere((e) => e.value == s, orElse: () => pending);
}

enum ItemStatus {
  active,
  rented,
  paused,
  deleted;

  static ItemStatus fromString(String s) =>
      values.firstWhere((e) => e.name == s, orElse: () => active);
}

enum ItemCategory {
  lightstick,
  phone,
  camera,
  slogan,
  costume,
  etc;

  String get label => switch (this) {
        lightstick => 'Lightstick',
        phone => 'Phone',
        camera => 'Camera',
        slogan => 'Slogan',
        costume => 'Costume',
        etc => 'Other',
      };

  String localizedLabel(AppLocalizations l) => switch (this) {
        lightstick => l.categoryLightstick,
        phone => l.categoryPhone,
        camera => l.categoryCamera,
        slogan => l.categorySlogan,
        costume => l.categoryCostume,
        etc => l.categoryOther,
      };

  static ItemCategory fromString(String s) =>
      values.firstWhere((e) => e.name == s, orElse: () => etc);
}

enum ConditionGrade {
  S,
  A,
  B,
  C;

  static ConditionGrade fromString(String s) =>
      values.firstWhere((e) => e.name == s, orElse: () => A);
}

enum PickupMethod {
  direct,
  delivery,
  both;

  String get label => switch (this) {
        direct => 'Direct Meetup',
        delivery => 'Delivery',
        both => 'Both',
      };

  String localizedLabel(AppLocalizations l) => switch (this) {
        direct => l.pickupDirect,
        delivery => l.pickupDelivery,
        both => l.pickupBoth,
      };

  static PickupMethod fromString(String s) =>
      values.firstWhere((e) => e.name == s, orElse: () => direct);
}

enum LenderGrade {
  power,
  regular,
  newbie;

  static LenderGrade fromString(String s) =>
      values.firstWhere((e) => e.name == s, orElse: () => newbie);
}
