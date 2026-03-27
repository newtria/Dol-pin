// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'concert_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ConcertModel {

 String get id; String get title; String get artist; String get venue; String get city; String get country;@JsonKey(name: 'concert_date') DateTime get concertDate;@JsonKey(name: 'poster_url') String? get posterUrl;@JsonKey(name: 'created_at') DateTime? get createdAt;
/// Create a copy of ConcertModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConcertModelCopyWith<ConcertModel> get copyWith => _$ConcertModelCopyWithImpl<ConcertModel>(this as ConcertModel, _$identity);

  /// Serializes this ConcertModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConcertModel&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.artist, artist) || other.artist == artist)&&(identical(other.venue, venue) || other.venue == venue)&&(identical(other.city, city) || other.city == city)&&(identical(other.country, country) || other.country == country)&&(identical(other.concertDate, concertDate) || other.concertDate == concertDate)&&(identical(other.posterUrl, posterUrl) || other.posterUrl == posterUrl)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,artist,venue,city,country,concertDate,posterUrl,createdAt);

@override
String toString() {
  return 'ConcertModel(id: $id, title: $title, artist: $artist, venue: $venue, city: $city, country: $country, concertDate: $concertDate, posterUrl: $posterUrl, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $ConcertModelCopyWith<$Res>  {
  factory $ConcertModelCopyWith(ConcertModel value, $Res Function(ConcertModel) _then) = _$ConcertModelCopyWithImpl;
@useResult
$Res call({
 String id, String title, String artist, String venue, String city, String country,@JsonKey(name: 'concert_date') DateTime concertDate,@JsonKey(name: 'poster_url') String? posterUrl,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class _$ConcertModelCopyWithImpl<$Res>
    implements $ConcertModelCopyWith<$Res> {
  _$ConcertModelCopyWithImpl(this._self, this._then);

  final ConcertModel _self;
  final $Res Function(ConcertModel) _then;

/// Create a copy of ConcertModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? artist = null,Object? venue = null,Object? city = null,Object? country = null,Object? concertDate = null,Object? posterUrl = freezed,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,artist: null == artist ? _self.artist : artist // ignore: cast_nullable_to_non_nullable
as String,venue: null == venue ? _self.venue : venue // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,country: null == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String,concertDate: null == concertDate ? _self.concertDate : concertDate // ignore: cast_nullable_to_non_nullable
as DateTime,posterUrl: freezed == posterUrl ? _self.posterUrl : posterUrl // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ConcertModel].
extension ConcertModelPatterns on ConcertModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConcertModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConcertModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConcertModel value)  $default,){
final _that = this;
switch (_that) {
case _ConcertModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConcertModel value)?  $default,){
final _that = this;
switch (_that) {
case _ConcertModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String artist,  String venue,  String city,  String country, @JsonKey(name: 'concert_date')  DateTime concertDate, @JsonKey(name: 'poster_url')  String? posterUrl, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConcertModel() when $default != null:
return $default(_that.id,_that.title,_that.artist,_that.venue,_that.city,_that.country,_that.concertDate,_that.posterUrl,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String artist,  String venue,  String city,  String country, @JsonKey(name: 'concert_date')  DateTime concertDate, @JsonKey(name: 'poster_url')  String? posterUrl, @JsonKey(name: 'created_at')  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _ConcertModel():
return $default(_that.id,_that.title,_that.artist,_that.venue,_that.city,_that.country,_that.concertDate,_that.posterUrl,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String artist,  String venue,  String city,  String country, @JsonKey(name: 'concert_date')  DateTime concertDate, @JsonKey(name: 'poster_url')  String? posterUrl, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _ConcertModel() when $default != null:
return $default(_that.id,_that.title,_that.artist,_that.venue,_that.city,_that.country,_that.concertDate,_that.posterUrl,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ConcertModel implements ConcertModel {
  const _ConcertModel({required this.id, required this.title, required this.artist, required this.venue, required this.city, required this.country, @JsonKey(name: 'concert_date') required this.concertDate, @JsonKey(name: 'poster_url') this.posterUrl, @JsonKey(name: 'created_at') this.createdAt});
  factory _ConcertModel.fromJson(Map<String, dynamic> json) => _$ConcertModelFromJson(json);

@override final  String id;
@override final  String title;
@override final  String artist;
@override final  String venue;
@override final  String city;
@override final  String country;
@override@JsonKey(name: 'concert_date') final  DateTime concertDate;
@override@JsonKey(name: 'poster_url') final  String? posterUrl;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;

/// Create a copy of ConcertModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConcertModelCopyWith<_ConcertModel> get copyWith => __$ConcertModelCopyWithImpl<_ConcertModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ConcertModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConcertModel&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.artist, artist) || other.artist == artist)&&(identical(other.venue, venue) || other.venue == venue)&&(identical(other.city, city) || other.city == city)&&(identical(other.country, country) || other.country == country)&&(identical(other.concertDate, concertDate) || other.concertDate == concertDate)&&(identical(other.posterUrl, posterUrl) || other.posterUrl == posterUrl)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,artist,venue,city,country,concertDate,posterUrl,createdAt);

@override
String toString() {
  return 'ConcertModel(id: $id, title: $title, artist: $artist, venue: $venue, city: $city, country: $country, concertDate: $concertDate, posterUrl: $posterUrl, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$ConcertModelCopyWith<$Res> implements $ConcertModelCopyWith<$Res> {
  factory _$ConcertModelCopyWith(_ConcertModel value, $Res Function(_ConcertModel) _then) = __$ConcertModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String artist, String venue, String city, String country,@JsonKey(name: 'concert_date') DateTime concertDate,@JsonKey(name: 'poster_url') String? posterUrl,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class __$ConcertModelCopyWithImpl<$Res>
    implements _$ConcertModelCopyWith<$Res> {
  __$ConcertModelCopyWithImpl(this._self, this._then);

  final _ConcertModel _self;
  final $Res Function(_ConcertModel) _then;

/// Create a copy of ConcertModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? artist = null,Object? venue = null,Object? city = null,Object? country = null,Object? concertDate = null,Object? posterUrl = freezed,Object? createdAt = freezed,}) {
  return _then(_ConcertModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,artist: null == artist ? _self.artist : artist // ignore: cast_nullable_to_non_nullable
as String,venue: null == venue ? _self.venue : venue // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,country: null == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String,concertDate: null == concertDate ? _self.concertDate : concertDate // ignore: cast_nullable_to_non_nullable
as DateTime,posterUrl: freezed == posterUrl ? _self.posterUrl : posterUrl // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
