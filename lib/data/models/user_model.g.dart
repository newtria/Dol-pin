// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserModel _$UserModelFromJson(Map<String, dynamic> json) => _UserModel(
  id: json['id'] as String,
  phone: json['phone'] as String,
  nickname: json['nickname'] as String,
  profileImage: json['profile_image'] as String?,
  isLender: json['is_lender'] as bool? ?? false,
  identityVerified: json['identity_verified'] as bool? ?? false,
  lenderGrade: json['lender_grade'] as String? ?? 'newbie',
  favGroups:
      (json['fav_groups'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  country: json['country'] as String,
  region: json['region'] as String?,
  locale: json['locale'] as String? ?? 'en',
  currency: json['currency'] as String? ?? 'USD',
  responseRate: (json['response_rate'] as num?)?.toDouble() ?? 0,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  deletedAt: json['deleted_at'] == null
      ? null
      : DateTime.parse(json['deleted_at'] as String),
);

Map<String, dynamic> _$UserModelToJson(_UserModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'phone': instance.phone,
      'nickname': instance.nickname,
      'profile_image': instance.profileImage,
      'is_lender': instance.isLender,
      'identity_verified': instance.identityVerified,
      'lender_grade': instance.lenderGrade,
      'fav_groups': instance.favGroups,
      'country': instance.country,
      'region': instance.region,
      'locale': instance.locale,
      'currency': instance.currency,
      'response_rate': instance.responseRate,
      'created_at': instance.createdAt?.toIso8601String(),
      'deleted_at': instance.deletedAt?.toIso8601String(),
    };
