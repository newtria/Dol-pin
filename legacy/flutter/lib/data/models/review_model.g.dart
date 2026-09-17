// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReviewModel _$ReviewModelFromJson(Map<String, dynamic> json) => _ReviewModel(
  id: json['id'] as String,
  reservationId: json['reservation_id'] as String,
  reviewerId: json['reviewer_id'] as String,
  revieweeId: json['reviewee_id'] as String,
  rating: (json['rating'] as num).toInt(),
  content: json['content'] as String?,
  reviewType: json['review_type'] as String,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$ReviewModelToJson(_ReviewModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'reservation_id': instance.reservationId,
      'reviewer_id': instance.reviewerId,
      'reviewee_id': instance.revieweeId,
      'rating': instance.rating,
      'content': instance.content,
      'review_type': instance.reviewType,
      'created_at': instance.createdAt?.toIso8601String(),
    };
