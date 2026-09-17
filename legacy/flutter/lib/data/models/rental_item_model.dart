import 'package:freezed_annotation/freezed_annotation.dart';

part 'rental_item_model.freezed.dart';
part 'rental_item_model.g.dart';

@freezed
abstract class RentalItemModel with _$RentalItemModel {
  const factory RentalItemModel({
    required String id,
    @JsonKey(name: 'lender_id') required String lenderId,
    @JsonKey(name: 'concert_id') String? concertId,
    required String category,
    required String title,
    String? description,
    required List<String> photos,
    @JsonKey(name: 'daily_price') required int dailyPrice,
    required String currency,
    required int deposit,
    @JsonKey(name: 'condition_grade') String? conditionGrade,
    @JsonKey(name: 'vlm_tag') String? vlmTag,
    @JsonKey(name: 'bt_verified') @Default(false) bool btVerified,
    String? imei,
    @JsonKey(name: 'imei_verified') @Default(false) bool imeiVerified,
    @JsonKey(name: 'pickup_method') required String pickupMethod,
    @JsonKey(name: 'pickup_location') Map<String, dynamic>? pickupLocation,
    @JsonKey(name: 'available_from') DateTime? availableFrom,
    @JsonKey(name: 'available_to') DateTime? availableTo,
    @Default('active') String status,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _RentalItemModel;

  factory RentalItemModel.fromJson(Map<String, dynamic> json) =>
      _$RentalItemModelFromJson(json);
}
