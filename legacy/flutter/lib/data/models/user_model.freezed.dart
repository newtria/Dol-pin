// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserModel {

 String get id; String get phone; String get nickname;@JsonKey(name: 'profile_image') String? get profileImage;@JsonKey(name: 'is_lender') bool get isLender;@JsonKey(name: 'identity_verified') bool get identityVerified;@JsonKey(name: 'lender_grade') String get lenderGrade;@JsonKey(name: 'fav_groups') List<String> get favGroups; String get country; String? get region; String get locale; String get currency;@JsonKey(name: 'response_rate') double get responseRate;@JsonKey(name: 'created_at') DateTime? get createdAt;@JsonKey(name: 'deleted_at') DateTime? get deletedAt;
/// Create a copy of UserModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserModelCopyWith<UserModel> get copyWith => _$UserModelCopyWithImpl<UserModel>(this as UserModel, _$identity);

  /// Serializes this UserModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserModel&&(identical(other.id, id) || other.id == id)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.profileImage, profileImage) || other.profileImage == profileImage)&&(identical(other.isLender, isLender) || other.isLender == isLender)&&(identical(other.identityVerified, identityVerified) || other.identityVerified == identityVerified)&&(identical(other.lenderGrade, lenderGrade) || other.lenderGrade == lenderGrade)&&const DeepCollectionEquality().equals(other.favGroups, favGroups)&&(identical(other.country, country) || other.country == country)&&(identical(other.region, region) || other.region == region)&&(identical(other.locale, locale) || other.locale == locale)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.responseRate, responseRate) || other.responseRate == responseRate)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,phone,nickname,profileImage,isLender,identityVerified,lenderGrade,const DeepCollectionEquality().hash(favGroups),country,region,locale,currency,responseRate,createdAt,deletedAt);

@override
String toString() {
  return 'UserModel(id: $id, phone: $phone, nickname: $nickname, profileImage: $profileImage, isLender: $isLender, identityVerified: $identityVerified, lenderGrade: $lenderGrade, favGroups: $favGroups, country: $country, region: $region, locale: $locale, currency: $currency, responseRate: $responseRate, createdAt: $createdAt, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $UserModelCopyWith<$Res>  {
  factory $UserModelCopyWith(UserModel value, $Res Function(UserModel) _then) = _$UserModelCopyWithImpl;
@useResult
$Res call({
 String id, String phone, String nickname,@JsonKey(name: 'profile_image') String? profileImage,@JsonKey(name: 'is_lender') bool isLender,@JsonKey(name: 'identity_verified') bool identityVerified,@JsonKey(name: 'lender_grade') String lenderGrade,@JsonKey(name: 'fav_groups') List<String> favGroups, String country, String? region, String locale, String currency,@JsonKey(name: 'response_rate') double responseRate,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'deleted_at') DateTime? deletedAt
});




}
/// @nodoc
class _$UserModelCopyWithImpl<$Res>
    implements $UserModelCopyWith<$Res> {
  _$UserModelCopyWithImpl(this._self, this._then);

  final UserModel _self;
  final $Res Function(UserModel) _then;

/// Create a copy of UserModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? phone = null,Object? nickname = null,Object? profileImage = freezed,Object? isLender = null,Object? identityVerified = null,Object? lenderGrade = null,Object? favGroups = null,Object? country = null,Object? region = freezed,Object? locale = null,Object? currency = null,Object? responseRate = null,Object? createdAt = freezed,Object? deletedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,nickname: null == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String,profileImage: freezed == profileImage ? _self.profileImage : profileImage // ignore: cast_nullable_to_non_nullable
as String?,isLender: null == isLender ? _self.isLender : isLender // ignore: cast_nullable_to_non_nullable
as bool,identityVerified: null == identityVerified ? _self.identityVerified : identityVerified // ignore: cast_nullable_to_non_nullable
as bool,lenderGrade: null == lenderGrade ? _self.lenderGrade : lenderGrade // ignore: cast_nullable_to_non_nullable
as String,favGroups: null == favGroups ? _self.favGroups : favGroups // ignore: cast_nullable_to_non_nullable
as List<String>,country: null == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String,region: freezed == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as String?,locale: null == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as String,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,responseRate: null == responseRate ? _self.responseRate : responseRate // ignore: cast_nullable_to_non_nullable
as double,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [UserModel].
extension UserModelPatterns on UserModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserModel value)  $default,){
final _that = this;
switch (_that) {
case _UserModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserModel value)?  $default,){
final _that = this;
switch (_that) {
case _UserModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String phone,  String nickname, @JsonKey(name: 'profile_image')  String? profileImage, @JsonKey(name: 'is_lender')  bool isLender, @JsonKey(name: 'identity_verified')  bool identityVerified, @JsonKey(name: 'lender_grade')  String lenderGrade, @JsonKey(name: 'fav_groups')  List<String> favGroups,  String country,  String? region,  String locale,  String currency, @JsonKey(name: 'response_rate')  double responseRate, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'deleted_at')  DateTime? deletedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserModel() when $default != null:
return $default(_that.id,_that.phone,_that.nickname,_that.profileImage,_that.isLender,_that.identityVerified,_that.lenderGrade,_that.favGroups,_that.country,_that.region,_that.locale,_that.currency,_that.responseRate,_that.createdAt,_that.deletedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String phone,  String nickname, @JsonKey(name: 'profile_image')  String? profileImage, @JsonKey(name: 'is_lender')  bool isLender, @JsonKey(name: 'identity_verified')  bool identityVerified, @JsonKey(name: 'lender_grade')  String lenderGrade, @JsonKey(name: 'fav_groups')  List<String> favGroups,  String country,  String? region,  String locale,  String currency, @JsonKey(name: 'response_rate')  double responseRate, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'deleted_at')  DateTime? deletedAt)  $default,) {final _that = this;
switch (_that) {
case _UserModel():
return $default(_that.id,_that.phone,_that.nickname,_that.profileImage,_that.isLender,_that.identityVerified,_that.lenderGrade,_that.favGroups,_that.country,_that.region,_that.locale,_that.currency,_that.responseRate,_that.createdAt,_that.deletedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String phone,  String nickname, @JsonKey(name: 'profile_image')  String? profileImage, @JsonKey(name: 'is_lender')  bool isLender, @JsonKey(name: 'identity_verified')  bool identityVerified, @JsonKey(name: 'lender_grade')  String lenderGrade, @JsonKey(name: 'fav_groups')  List<String> favGroups,  String country,  String? region,  String locale,  String currency, @JsonKey(name: 'response_rate')  double responseRate, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'deleted_at')  DateTime? deletedAt)?  $default,) {final _that = this;
switch (_that) {
case _UserModel() when $default != null:
return $default(_that.id,_that.phone,_that.nickname,_that.profileImage,_that.isLender,_that.identityVerified,_that.lenderGrade,_that.favGroups,_that.country,_that.region,_that.locale,_that.currency,_that.responseRate,_that.createdAt,_that.deletedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserModel implements UserModel {
  const _UserModel({required this.id, required this.phone, required this.nickname, @JsonKey(name: 'profile_image') this.profileImage, @JsonKey(name: 'is_lender') this.isLender = false, @JsonKey(name: 'identity_verified') this.identityVerified = false, @JsonKey(name: 'lender_grade') this.lenderGrade = 'newbie', @JsonKey(name: 'fav_groups') final  List<String> favGroups = const [], required this.country, this.region, this.locale = 'en', this.currency = 'USD', @JsonKey(name: 'response_rate') this.responseRate = 0, @JsonKey(name: 'created_at') this.createdAt, @JsonKey(name: 'deleted_at') this.deletedAt}): _favGroups = favGroups;
  factory _UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);

@override final  String id;
@override final  String phone;
@override final  String nickname;
@override@JsonKey(name: 'profile_image') final  String? profileImage;
@override@JsonKey(name: 'is_lender') final  bool isLender;
@override@JsonKey(name: 'identity_verified') final  bool identityVerified;
@override@JsonKey(name: 'lender_grade') final  String lenderGrade;
 final  List<String> _favGroups;
@override@JsonKey(name: 'fav_groups') List<String> get favGroups {
  if (_favGroups is EqualUnmodifiableListView) return _favGroups;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_favGroups);
}

@override final  String country;
@override final  String? region;
@override@JsonKey() final  String locale;
@override@JsonKey() final  String currency;
@override@JsonKey(name: 'response_rate') final  double responseRate;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;
@override@JsonKey(name: 'deleted_at') final  DateTime? deletedAt;

/// Create a copy of UserModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserModelCopyWith<_UserModel> get copyWith => __$UserModelCopyWithImpl<_UserModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserModel&&(identical(other.id, id) || other.id == id)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.profileImage, profileImage) || other.profileImage == profileImage)&&(identical(other.isLender, isLender) || other.isLender == isLender)&&(identical(other.identityVerified, identityVerified) || other.identityVerified == identityVerified)&&(identical(other.lenderGrade, lenderGrade) || other.lenderGrade == lenderGrade)&&const DeepCollectionEquality().equals(other._favGroups, _favGroups)&&(identical(other.country, country) || other.country == country)&&(identical(other.region, region) || other.region == region)&&(identical(other.locale, locale) || other.locale == locale)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.responseRate, responseRate) || other.responseRate == responseRate)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,phone,nickname,profileImage,isLender,identityVerified,lenderGrade,const DeepCollectionEquality().hash(_favGroups),country,region,locale,currency,responseRate,createdAt,deletedAt);

@override
String toString() {
  return 'UserModel(id: $id, phone: $phone, nickname: $nickname, profileImage: $profileImage, isLender: $isLender, identityVerified: $identityVerified, lenderGrade: $lenderGrade, favGroups: $favGroups, country: $country, region: $region, locale: $locale, currency: $currency, responseRate: $responseRate, createdAt: $createdAt, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class _$UserModelCopyWith<$Res> implements $UserModelCopyWith<$Res> {
  factory _$UserModelCopyWith(_UserModel value, $Res Function(_UserModel) _then) = __$UserModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String phone, String nickname,@JsonKey(name: 'profile_image') String? profileImage,@JsonKey(name: 'is_lender') bool isLender,@JsonKey(name: 'identity_verified') bool identityVerified,@JsonKey(name: 'lender_grade') String lenderGrade,@JsonKey(name: 'fav_groups') List<String> favGroups, String country, String? region, String locale, String currency,@JsonKey(name: 'response_rate') double responseRate,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'deleted_at') DateTime? deletedAt
});




}
/// @nodoc
class __$UserModelCopyWithImpl<$Res>
    implements _$UserModelCopyWith<$Res> {
  __$UserModelCopyWithImpl(this._self, this._then);

  final _UserModel _self;
  final $Res Function(_UserModel) _then;

/// Create a copy of UserModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? phone = null,Object? nickname = null,Object? profileImage = freezed,Object? isLender = null,Object? identityVerified = null,Object? lenderGrade = null,Object? favGroups = null,Object? country = null,Object? region = freezed,Object? locale = null,Object? currency = null,Object? responseRate = null,Object? createdAt = freezed,Object? deletedAt = freezed,}) {
  return _then(_UserModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,nickname: null == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String,profileImage: freezed == profileImage ? _self.profileImage : profileImage // ignore: cast_nullable_to_non_nullable
as String?,isLender: null == isLender ? _self.isLender : isLender // ignore: cast_nullable_to_non_nullable
as bool,identityVerified: null == identityVerified ? _self.identityVerified : identityVerified // ignore: cast_nullable_to_non_nullable
as bool,lenderGrade: null == lenderGrade ? _self.lenderGrade : lenderGrade // ignore: cast_nullable_to_non_nullable
as String,favGroups: null == favGroups ? _self._favGroups : favGroups // ignore: cast_nullable_to_non_nullable
as List<String>,country: null == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String,region: freezed == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as String?,locale: null == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as String,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,responseRate: null == responseRate ? _self.responseRate : responseRate // ignore: cast_nullable_to_non_nullable
as double,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
