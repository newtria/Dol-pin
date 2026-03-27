import '../../l10n/app_localizations.dart';

enum ReservationStatus {
  pending,
  accepted,
  paid,
  pickedUp('picked_up'),
  returned_('returned'),
  completed,
  cancelled,
  disputed;

  const ReservationStatus([this._value]);
  final String? _value;

  String get value => _value ?? name;

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
