// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'review_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReviewModel {

 String get id;@JsonKey(name: 'reservation_id') String get reservationId;@JsonKey(name: 'reviewer_id') String get reviewerId;@JsonKey(name: 'reviewee_id') String get revieweeId; int get rating; String? get content;@JsonKey(name: 'review_type') String get reviewType;@JsonKey(name: 'created_at') DateTime? get createdAt;
/// Create a copy of ReviewModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReviewModelCopyWith<ReviewModel> get copyWith => _$ReviewModelCopyWithImpl<ReviewModel>(this as ReviewModel, _$identity);

  /// Serializes this ReviewModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReviewModel&&(identical(other.id, id) || other.id == id)&&(identical(other.reservationId, reservationId) || other.reservationId == reservationId)&&(identical(other.reviewerId, reviewerId) || other.reviewerId == reviewerId)&&(identical(other.revieweeId, revieweeId) || other.revieweeId == revieweeId)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.content, content) || other.content == content)&&(identical(other.reviewType, reviewType) || other.reviewType == reviewType)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,reservationId,reviewerId,revieweeId,rating,content,reviewType,createdAt);

@override
String toString() {
  return 'ReviewModel(id: $id, reservationId: $reservationId, reviewerId: $reviewerId, revieweeId: $revieweeId, rating: $rating, content: $content, reviewType: $reviewType, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $ReviewModelCopyWith<$Res>  {
  factory $ReviewModelCopyWith(ReviewModel value, $Res Function(ReviewModel) _then) = _$ReviewModelCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'reservation_id') String reservationId,@JsonKey(name: 'reviewer_id') String reviewerId,@JsonKey(name: 'reviewee_id') String revieweeId, int rating, String? content,@JsonKey(name: 'review_type') String reviewType,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class _$ReviewModelCopyWithImpl<$Res>
    implements $ReviewModelCopyWith<$Res> {
  _$ReviewModelCopyWithImpl(this._self, this._then);

  final ReviewModel _self;
  final $Res Function(ReviewModel) _then;

/// Create a copy of ReviewModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? reservationId = null,Object? reviewerId = null,Object? revieweeId = null,Object? rating = null,Object? content = freezed,Object? reviewType = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,reservationId: null == reservationId ? _self.reservationId : reservationId // ignore: cast_nullable_to_non_nullable
as String,reviewerId: null == reviewerId ? _self.reviewerId : reviewerId // ignore: cast_nullable_to_non_nullable
as String,revieweeId: null == revieweeId ? _self.revieweeId : revieweeId // ignore: cast_nullable_to_non_nullable
as String,rating: null == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as int,content: freezed == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String?,reviewType: null == reviewType ? _self.reviewType : reviewType // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ReviewModel].
extension ReviewModelPatterns on ReviewModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReviewModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReviewModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReviewModel value)  $default,){
final _that = this;
switch (_that) {
case _ReviewModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReviewModel value)?  $default,){
final _that = this;
switch (_that) {
case _ReviewModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'reservation_id')  String reservationId, @JsonKey(name: 'reviewer_id')  String reviewerId, @JsonKey(name: 'reviewee_id')  String revieweeId,  int rating,  String? content, @JsonKey(name: 'review_type')  String reviewType, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReviewModel() when $default != null:
return $default(_that.id,_that.reservationId,_that.reviewerId,_that.revieweeId,_that.rating,_that.content,_that.reviewType,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'reservation_id')  String reservationId, @JsonKey(name: 'reviewer_id')  String reviewerId, @JsonKey(name: 'reviewee_id')  String revieweeId,  int rating,  String? content, @JsonKey(name: 'review_type')  String reviewType, @JsonKey(name: 'created_at')  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _ReviewModel():
return $default(_that.id,_that.reservationId,_that.reviewerId,_that.revieweeId,_that.rating,_that.content,_that.reviewType,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'reservation_id')  String reservationId, @JsonKey(name: 'reviewer_id')  String reviewerId, @JsonKey(name: 'reviewee_id')  String revieweeId,  int rating,  String? content, @JsonKey(name: 'review_type')  String reviewType, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _ReviewModel() when $default != null:
return $default(_that.id,_that.reservationId,_that.reviewerId,_that.revieweeId,_that.rating,_that.content,_that.reviewType,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReviewModel implements ReviewModel {
  const _ReviewModel({required this.id, @JsonKey(name: 'reservation_id') required this.reservationId, @JsonKey(name: 'reviewer_id') required this.reviewerId, @JsonKey(name: 'reviewee_id') required this.revieweeId, required this.rating, this.content, @JsonKey(name: 'review_type') required this.reviewType, @JsonKey(name: 'created_at') this.createdAt});
  factory _ReviewModel.fromJson(Map<String, dynamic> json) => _$ReviewModelFromJson(json);

@override final  String id;
@override@JsonKey(name: 'reservation_id') final  String reservationId;
@override@JsonKey(name: 'reviewer_id') final  String reviewerId;
@override@JsonKey(name: 'reviewee_id') final  String revieweeId;
@override final  int rating;
@override final  String? content;
@override@JsonKey(name: 'review_type') final  String reviewType;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;

/// Create a copy of ReviewModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReviewModelCopyWith<_ReviewModel> get copyWith => __$ReviewModelCopyWithImpl<_ReviewModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReviewModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReviewModel&&(identical(other.id, id) || other.id == id)&&(identical(other.reservationId, reservationId) || other.reservationId == reservationId)&&(identical(other.reviewerId, reviewerId) || other.reviewerId == reviewerId)&&(identical(other.revieweeId, revieweeId) || other.revieweeId == revieweeId)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.content, content) || other.content == content)&&(identical(other.reviewType, reviewType) || other.reviewType == reviewType)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,reservationId,reviewerId,revieweeId,rating,content,reviewType,createdAt);

@override
String toString() {
  return 'ReviewModel(id: $id, reservationId: $reservationId, reviewerId: $reviewerId, revieweeId: $revieweeId, rating: $rating, content: $content, reviewType: $reviewType, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$ReviewModelCopyWith<$Res> implements $ReviewModelCopyWith<$Res> {
  factory _$ReviewModelCopyWith(_ReviewModel value, $Res Function(_ReviewModel) _then) = __$ReviewModelCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'reservation_id') String reservationId,@JsonKey(name: 'reviewer_id') String reviewerId,@JsonKey(name: 'reviewee_id') String revieweeId, int rating, String? content,@JsonKey(name: 'review_type') String reviewType,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class __$ReviewModelCopyWithImpl<$Res>
    implements _$ReviewModelCopyWith<$Res> {
  __$ReviewModelCopyWithImpl(this._self, this._then);

  final _ReviewModel _self;
  final $Res Function(_ReviewModel) _then;

/// Create a copy of ReviewModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? reservationId = null,Object? reviewerId = null,Object? revieweeId = null,Object? rating = null,Object? content = freezed,Object? reviewType = null,Object? createdAt = freezed,}) {
  return _then(_ReviewModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,reservationId: null == reservationId ? _self.reservationId : reservationId // ignore: cast_nullable_to_non_nullable
as String,reviewerId: null == reviewerId ? _self.reviewerId : reviewerId // ignore: cast_nullable_to_non_nullable
as String,revieweeId: null == revieweeId ? _self.revieweeId : revieweeId // ignore: cast_nullable_to_non_nullable
as String,rating: null == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as int,content: freezed == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String?,reviewType: null == reviewType ? _self.reviewType : reviewType // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
