// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reservation_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReservationModel _$ReservationModelFromJson(Map<String, dynamic> json) =>
    _ReservationModel(
      id: json['id'] as String,
      itemId: json['item_id'] as String,
      borrowerId: json['borrower_id'] as String,
      lenderId: json['lender_id'] as String,
      rentalDate: DateTime.parse(json['rental_date'] as String),
      returnDate: DateTime.parse(json['return_date'] as String),
      rentalFee: (json['rental_fee'] as num).toInt(),
      deposit: (json['deposit'] as num).toInt(),
      totalPaid: (json['total_paid'] as num).toInt(),
      currency: json['currency'] as String,
      status: json['status'] as String? ?? 'pending',
      pickupConfirmedAt: json['pickup_confirmed_at'] == null
          ? null
          : DateTime.parse(json['pickup_confirmed_at'] as String),
      returnConfirmedAt: json['return_confirmed_at'] == null
          ? null
          : DateTime.parse(json['return_confirmed_at'] as String),
      returnPhoto: json['return_photo'] as String?,
      paymentProvider: json['payment_provider'] as String?,
      paymentId: json['payment_id'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$ReservationModelToJson(_ReservationModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'item_id': instance.itemId,
      'borrower_id': instance.borrowerId,
      'lender_id': instance.lenderId,
      'rental_date': instance.rentalDate.toIso8601String(),
      'return_date': instance.returnDate.toIso8601String(),
      'rental_fee': instance.rentalFee,
      'deposit': instance.deposit,
      'total_paid': instance.totalPaid,
      'currency': instance.currency,
      'status': instance.status,
      'pickup_confirmed_at': instance.pickupConfirmedAt?.toIso8601String(),
      'return_confirmed_at': instance.returnConfirmedAt?.toIso8601String(),
      'return_photo': instance.returnPhoto,
      'payment_provider': instance.paymentProvider,
      'payment_id': instance.paymentId,
      'created_at': instance.createdAt?.toIso8601String(),
    };
