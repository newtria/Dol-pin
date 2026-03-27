// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rental_item_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RentalItemModel _$RentalItemModelFromJson(Map<String, dynamic> json) =>
    _RentalItemModel(
      id: json['id'] as String,
      lenderId: json['lender_id'] as String,
      concertId: json['concert_id'] as String?,
      category: json['category'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      photos: (json['photos'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      dailyPrice: (json['daily_price'] as num).toInt(),
      currency: json['currency'] as String,
      deposit: (json['deposit'] as num).toInt(),
      conditionGrade: json['condition_grade'] as String?,
      vlmTag: json['vlm_tag'] as String?,
      btVerified: json['bt_verified'] as bool? ?? false,
      imei: json['imei'] as String?,
      imeiVerified: json['imei_verified'] as bool? ?? false,
      pickupMethod: json['pickup_method'] as String,
      pickupLocation: json['pickup_location'] as Map<String, dynamic>?,
      availableFrom: json['available_from'] == null
          ? null
          : DateTime.parse(json['available_from'] as String),
      availableTo: json['available_to'] == null
          ? null
          : DateTime.parse(json['available_to'] as String),
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$RentalItemModelToJson(_RentalItemModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'lender_id': instance.lenderId,
      'concert_id': instance.concertId,
      'category': instance.category,
      'title': instance.title,
      'description': instance.description,
      'photos': instance.photos,
      'daily_price': instance.dailyPrice,
      'currency': instance.currency,
      'deposit': instance.deposit,
      'condition_grade': instance.conditionGrade,
      'vlm_tag': instance.vlmTag,
      'bt_verified': instance.btVerified,
      'imei': instance.imei,
      'imei_verified': instance.imeiVerified,
      'pickup_method': instance.pickupMethod,
      'pickup_location': instance.pickupLocation,
      'available_from': instance.availableFrom?.toIso8601String(),
      'available_to': instance.availableTo?.toIso8601String(),
      'status': instance.status,
      'created_at': instance.createdAt?.toIso8601String(),
    };
