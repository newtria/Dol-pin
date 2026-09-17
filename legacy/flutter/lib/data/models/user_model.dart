import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
abstract class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    required String phone,
    required String nickname,
    @JsonKey(name: 'profile_image') String? profileImage,
    @JsonKey(name: 'is_lender') @Default(false) bool isLender,
    @JsonKey(name: 'identity_verified') @Default(false) bool identityVerified,
    @JsonKey(name: 'lender_grade') @Default('newbie') String lenderGrade,
    @JsonKey(name: 'fav_groups') @Default([]) List<String> favGroups,
    required String country,
    String? region,
    @Default('en') String locale,
    @Default('USD') String currency,
    @JsonKey(name: 'response_rate') @Default(0) double responseRate,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'deleted_at') DateTime? deletedAt,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
}
