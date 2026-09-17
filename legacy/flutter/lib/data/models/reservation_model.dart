import 'package:freezed_annotation/freezed_annotation.dart';

part 'reservation_model.freezed.dart';
part 'reservation_model.g.dart';

@freezed
abstract class ReservationModel with _$ReservationModel {
  const factory ReservationModel({
    required String id,
    @JsonKey(name: 'item_id') required String itemId,
    @JsonKey(name: 'borrower_id') required String borrowerId,
    @JsonKey(name: 'lender_id') required String lenderId,
    @JsonKey(name: 'rental_date') required DateTime rentalDate,
    @JsonKey(name: 'return_date') required DateTime returnDate,
    @JsonKey(name: 'rental_fee') required int rentalFee,
    required int deposit,
    @JsonKey(name: 'total_paid') required int totalPaid,
    required String currency,
    @Default('pending') String status,
    @JsonKey(name: 'pickup_confirmed_at') DateTime? pickupConfirmedAt,
    @JsonKey(name: 'return_confirmed_at') DateTime? returnConfirmedAt,
    @JsonKey(name: 'return_photo') String? returnPhoto,
    @JsonKey(name: 'payment_provider') String? paymentProvider,
    @JsonKey(name: 'payment_id') String? paymentId,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _ReservationModel;

  factory ReservationModel.fromJson(Map<String, dynamic> json) =>
      _$ReservationModelFromJson(json);
}
