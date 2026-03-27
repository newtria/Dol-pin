// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rental_item_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RentalItemModel {

 String get id;@JsonKey(name: 'lender_id') String get lenderId;@JsonKey(name: 'concert_id') String? get concertId; String get category; String get title; String? get description; List<String> get photos;@JsonKey(name: 'daily_price') int get dailyPrice; String get currency; int get deposit;@JsonKey(name: 'condition_grade') String? get conditionGrade;@JsonKey(name: 'vlm_tag') String? get vlmTag;@JsonKey(name: 'bt_verified') bool get btVerified; String? get imei;@JsonKey(name: 'imei_verified') bool get imeiVerified;@JsonKey(name: 'pickup_method') String get pickupMethod;@JsonKey(name: 'pickup_location') Map<String, dynamic>? get pickupLocation;@JsonKey(name: 'available_from') DateTime? get availableFrom;@JsonKey(name: 'available_to') DateTime? get availableTo; String get status;@JsonKey(name: 'created_at') DateTime? get createdAt;
/// Create a copy of RentalItemModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RentalItemModelCopyWith<RentalItemModel> get copyWith => _$RentalItemModelCopyWithImpl<RentalItemModel>(this as RentalItemModel, _$identity);

  /// Serializes this RentalItemModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RentalItemModel&&(identical(other.id, id) || other.id == id)&&(identical(other.lenderId, lenderId) || other.lenderId == lenderId)&&(identical(other.concertId, concertId) || other.concertId == concertId)&&(identical(other.category, category) || other.category == category)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.photos, photos)&&(identical(other.dailyPrice, dailyPrice) || other.dailyPrice == dailyPrice)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.deposit, deposit) || other.deposit == deposit)&&(identical(other.conditionGrade, conditionGrade) || other.conditionGrade == conditionGrade)&&(identical(other.vlmTag, vlmTag) || other.vlmTag == vlmTag)&&(identical(other.btVerified, btVerified) || other.btVerified == btVerified)&&(identical(other.imei, imei) || other.imei == imei)&&(identical(other.imeiVerified, imeiVerified) || other.imeiVerified == imeiVerified)&&(identical(other.pickupMethod, pickupMethod) || other.pickupMethod == pickupMethod)&&const DeepCollectionEquality().equals(other.pickupLocation, pickupLocation)&&(identical(other.availableFrom, availableFrom) || other.availableFrom == availableFrom)&&(identical(other.availableTo, availableTo) || other.availableTo == availableTo)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,lenderId,concertId,category,title,description,const DeepCollectionEquality().hash(photos),dailyPrice,currency,deposit,conditionGrade,vlmTag,btVerified,imei,imeiVerified,pickupMethod,const DeepCollectionEquality().hash(pickupLocation),availableFrom,availableTo,status,createdAt]);

@override
String toString() {
  return 'RentalItemModel(id: $id, lenderId: $lenderId, concertId: $concertId, category: $category, title: $title, description: $description, photos: $photos, dailyPrice: $dailyPrice, currency: $currency, deposit: $deposit, conditionGrade: $conditionGrade, vlmTag: $vlmTag, btVerified: $btVerified, imei: $imei, imeiVerified: $imeiVerified, pickupMethod: $pickupMethod, pickupLocation: $pickupLocation, availableFrom: $availableFrom, availableTo: $availableTo, status: $status, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $RentalItemModelCopyWith<$Res>  {
  factory $RentalItemModelCopyWith(RentalItemModel value, $Res Function(RentalItemModel) _then) = _$RentalItemModelCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'lender_id') String lenderId,@JsonKey(name: 'concert_id') String? concertId, String category, String title, String? description, List<String> photos,@JsonKey(name: 'daily_price') int dailyPrice, String currency, int deposit,@JsonKey(name: 'condition_grade') String? conditionGrade,@JsonKey(name: 'vlm_tag') String? vlmTag,@JsonKey(name: 'bt_verified') bool btVerified, String? imei,@JsonKey(name: 'imei_verified') bool imeiVerified,@JsonKey(name: 'pickup_method') String pickupMethod,@JsonKey(name: 'pickup_location') Map<String, dynamic>? pickupLocation,@JsonKey(name: 'available_from') DateTime? availableFrom,@JsonKey(name: 'available_to') DateTime? availableTo, String status,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class _$RentalItemModelCopyWithImpl<$Res>
    implements $RentalItemModelCopyWith<$Res> {
  _$RentalItemModelCopyWithImpl(this._self, this._then);

  final RentalItemModel _self;
  final $Res Function(RentalItemModel) _then;

/// Create a copy of RentalItemModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? lenderId = null,Object? concertId = freezed,Object? category = null,Object? title = null,Object? description = freezed,Object? photos = null,Object? dailyPrice = null,Object? currency = null,Object? deposit = null,Object? conditionGrade = freezed,Object? vlmTag = freezed,Object? btVerified = null,Object? imei = freezed,Object? imeiVerified = null,Object? pickupMethod = null,Object? pickupLocation = freezed,Object? availableFrom = freezed,Object? availableTo = freezed,Object? status = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,lenderId: null == lenderId ? _self.lenderId : lenderId // ignore: cast_nullable_to_non_nullable
as String,concertId: freezed == concertId ? _self.concertId : concertId // ignore: cast_nullable_to_non_nullable
as String?,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,photos: null == photos ? _self.photos : photos // ignore: cast_nullable_to_non_nullable
as List<String>,dailyPrice: null == dailyPrice ? _self.dailyPrice : dailyPrice // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,deposit: null == deposit ? _self.deposit : deposit // ignore: cast_nullable_to_non_nullable
as int,conditionGrade: freezed == conditionGrade ? _self.conditionGrade : conditionGrade // ignore: cast_nullable_to_non_nullable
as String?,vlmTag: freezed == vlmTag ? _self.vlmTag : vlmTag // ignore: cast_nullable_to_non_nullable
as String?,btVerified: null == btVerified ? _self.btVerified : btVerified // ignore: cast_nullable_to_non_nullable
as bool,imei: freezed == imei ? _self.imei : imei // ignore: cast_nullable_to_non_nullable
as String?,imeiVerified: null == imeiVerified ? _self.imeiVerified : imeiVerified // ignore: cast_nullable_to_non_nullable
as bool,pickupMethod: null == pickupMethod ? _self.pickupMethod : pickupMethod // ignore: cast_nullable_to_non_nullable
as String,pickupLocation: freezed == pickupLocation ? _self.pickupLocation : pickupLocation // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,availableFrom: freezed == availableFrom ? _self.availableFrom : availableFrom // ignore: cast_nullable_to_non_nullable
as DateTime?,availableTo: freezed == availableTo ? _self.availableTo : availableTo // ignore: cast_nullable_to_non_nullable
as DateTime?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [RentalItemModel].
extension RentalItemModelPatterns on RentalItemModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RentalItemModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RentalItemModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RentalItemModel value)  $default,){
final _that = this;
switch (_that) {
case _RentalItemModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RentalItemModel value)?  $default,){
final _that = this;
switch (_that) {
case _RentalItemModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'lender_id')  String lenderId, @JsonKey(name: 'concert_id')  String? concertId,  String category,  String title,  String? description,  List<String> photos, @JsonKey(name: 'daily_price')  int dailyPrice,  String currency,  int deposit, @JsonKey(name: 'condition_grade')  String? conditionGrade, @JsonKey(name: 'vlm_tag')  String? vlmTag, @JsonKey(name: 'bt_verified')  bool btVerified,  String? imei, @JsonKey(name: 'imei_verified')  bool imeiVerified, @JsonKey(name: 'pickup_method')  String pickupMethod, @JsonKey(name: 'pickup_location')  Map<String, dynamic>? pickupLocation, @JsonKey(name: 'available_from')  DateTime? availableFrom, @JsonKey(name: 'available_to')  DateTime? availableTo,  String status, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RentalItemModel() when $default != null:
return $default(_that.id,_that.lenderId,_that.concertId,_that.category,_that.title,_that.description,_that.photos,_that.dailyPrice,_that.currency,_that.deposit,_that.conditionGrade,_that.vlmTag,_that.btVerified,_that.imei,_that.imeiVerified,_that.pickupMethod,_that.pickupLocation,_that.availableFrom,_that.availableTo,_that.status,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'lender_id')  String lenderId, @JsonKey(name: 'concert_id')  String? concertId,  String category,  String title,  String? description,  List<String> photos, @JsonKey(name: 'daily_price')  int dailyPrice,  String currency,  int deposit, @JsonKey(name: 'condition_grade')  String? conditionGrade, @JsonKey(name: 'vlm_tag')  String? vlmTag, @JsonKey(name: 'bt_verified')  bool btVerified,  String? imei, @JsonKey(name: 'imei_verified')  bool imeiVerified, @JsonKey(name: 'pickup_method')  String pickupMethod, @JsonKey(name: 'pickup_location')  Map<String, dynamic>? pickupLocation, @JsonKey(name: 'available_from')  DateTime? availableFrom, @JsonKey(name: 'available_to')  DateTime? availableTo,  String status, @JsonKey(name: 'created_at')  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _RentalItemModel():
return $default(_that.id,_that.lenderId,_that.concertId,_that.category,_that.title,_that.description,_that.photos,_that.dailyPrice,_that.currency,_that.deposit,_that.conditionGrade,_that.vlmTag,_that.btVerified,_that.imei,_that.imeiVerified,_that.pickupMethod,_that.pickupLocation,_that.availableFrom,_that.availableTo,_that.status,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'lender_id')  String lenderId, @JsonKey(name: 'concert_id')  String? concertId,  String category,  String title,  String? description,  List<String> photos, @JsonKey(name: 'daily_price')  int dailyPrice,  String currency,  int deposit, @JsonKey(name: 'condition_grade')  String? conditionGrade, @JsonKey(name: 'vlm_tag')  String? vlmTag, @JsonKey(name: 'bt_verified')  bool btVerified,  String? imei, @JsonKey(name: 'imei_verified')  bool imeiVerified, @JsonKey(name: 'pickup_method')  String pickupMethod, @JsonKey(name: 'pickup_location')  Map<String, dynamic>? pickupLocation, @JsonKey(name: 'available_from')  DateTime? availableFrom, @JsonKey(name: 'available_to')  DateTime? availableTo,  String status, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _RentalItemModel() when $default != null:
return $default(_that.id,_that.lenderId,_that.concertId,_that.category,_that.title,_that.description,_that.photos,_that.dailyPrice,_that.currency,_that.deposit,_that.conditionGrade,_that.vlmTag,_that.btVerified,_that.imei,_that.imeiVerified,_that.pickupMethod,_that.pickupLocation,_that.availableFrom,_that.availableTo,_that.status,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RentalItemModel implements RentalItemModel {
  const _RentalItemModel({required this.id, @JsonKey(name: 'lender_id') required this.lenderId, @JsonKey(name: 'concert_id') this.concertId, required this.category, required this.title, this.description, required final  List<String> photos, @JsonKey(name: 'daily_price') required this.dailyPrice, required this.currency, required this.deposit, @JsonKey(name: 'condition_grade') this.conditionGrade, @JsonKey(name: 'vlm_tag') this.vlmTag, @JsonKey(name: 'bt_verified') this.btVerified = false, this.imei, @JsonKey(name: 'imei_verified') this.imeiVerified = false, @JsonKey(name: 'pickup_method') required this.pickupMethod, @JsonKey(name: 'pickup_location') final  Map<String, dynamic>? pickupLocation, @JsonKey(name: 'available_from') this.availableFrom, @JsonKey(name: 'available_to') this.availableTo, this.status = 'active', @JsonKey(name: 'created_at') this.createdAt}): _photos = photos,_pickupLocation = pickupLocation;
  factory _RentalItemModel.fromJson(Map<String, dynamic> json) => _$RentalItemModelFromJson(json);

@override final  String id;
@override@JsonKey(name: 'lender_id') final  String lenderId;
@override@JsonKey(name: 'concert_id') final  String? concertId;
@override final  String category;
@override final  String title;
@override final  String? description;
 final  List<String> _photos;
@override List<String> get photos {
  if (_photos is EqualUnmodifiableListView) return _photos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_photos);
}

@override@JsonKey(name: 'daily_price') final  int dailyPrice;
@override final  String currency;
@override final  int deposit;
@override@JsonKey(name: 'condition_grade') final  String? conditionGrade;
@override@JsonKey(name: 'vlm_tag') final  String? vlmTag;
@override@JsonKey(name: 'bt_verified') final  bool btVerified;
@override final  String? imei;
@override@JsonKey(name: 'imei_verified') final  bool imeiVerified;
@override@JsonKey(name: 'pickup_method') final  String pickupMethod;
 final  Map<String, dynamic>? _pickupLocation;
@override@JsonKey(name: 'pickup_location') Map<String, dynamic>? get pickupLocation {
  final value = _pickupLocation;
  if (value == null) return null;
  if (_pickupLocation is EqualUnmodifiableMapView) return _pickupLocation;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey(name: 'available_from') final  DateTime? availableFrom;
@override@JsonKey(name: 'available_to') final  DateTime? availableTo;
@override@JsonKey() final  String status;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;

/// Create a copy of RentalItemModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RentalItemModelCopyWith<_RentalItemModel> get copyWith => __$RentalItemModelCopyWithImpl<_RentalItemModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RentalItemModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RentalItemModel&&(identical(other.id, id) || other.id == id)&&(identical(other.lenderId, lenderId) || other.lenderId == lenderId)&&(identical(other.concertId, concertId) || other.concertId == concertId)&&(identical(other.category, category) || other.category == category)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other._photos, _photos)&&(identical(other.dailyPrice, dailyPrice) || other.dailyPrice == dailyPrice)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.deposit, deposit) || other.deposit == deposit)&&(identical(other.conditionGrade, conditionGrade) || other.conditionGrade == conditionGrade)&&(identical(other.vlmTag, vlmTag) || other.vlmTag == vlmTag)&&(identical(other.btVerified, btVerified) || other.btVerified == btVerified)&&(identical(other.imei, imei) || other.imei == imei)&&(identical(other.imeiVerified, imeiVerified) || other.imeiVerified == imeiVerified)&&(identical(other.pickupMethod, pickupMethod) || other.pickupMethod == pickupMethod)&&const DeepCollectionEquality().equals(other._pickupLocation, _pickupLocation)&&(identical(other.availableFrom, availableFrom) || other.availableFrom == availableFrom)&&(identical(other.availableTo, availableTo) || other.availableTo == availableTo)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,lenderId,concertId,category,title,description,const DeepCollectionEquality().hash(_photos),dailyPrice,currency,deposit,conditionGrade,vlmTag,btVerified,imei,imeiVerified,pickupMethod,const DeepCollectionEquality().hash(_pickupLocation),availableFrom,availableTo,status,createdAt]);

@override
String toString() {
  return 'RentalItemModel(id: $id, lenderId: $lenderId, concertId: $concertId, category: $category, title: $title, description: $description, photos: $photos, dailyPrice: $dailyPrice, currency: $currency, deposit: $deposit, conditionGrade: $conditionGrade, vlmTag: $vlmTag, btVerified: $btVerified, imei: $imei, imeiVerified: $imeiVerified, pickupMethod: $pickupMethod, pickupLocation: $pickupLocation, availableFrom: $availableFrom, availableTo: $availableTo, status: $status, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$RentalItemModelCopyWith<$Res> implements $RentalItemModelCopyWith<$Res> {
  factory _$RentalItemModelCopyWith(_RentalItemModel value, $Res Function(_RentalItemModel) _then) = __$RentalItemModelCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'lender_id') String lenderId,@JsonKey(name: 'concert_id') String? concertId, String category, String title, String? description, List<String> photos,@JsonKey(name: 'daily_price') int dailyPrice, String currency, int deposit,@JsonKey(name: 'condition_grade') String? conditionGrade,@JsonKey(name: 'vlm_tag') String? vlmTag,@JsonKey(name: 'bt_verified') bool btVerified, String? imei,@JsonKey(name: 'imei_verified') bool imeiVerified,@JsonKey(name: 'pickup_method') String pickupMethod,@JsonKey(name: 'pickup_location') Map<String, dynamic>? pickupLocation,@JsonKey(name: 'available_from') DateTime? availableFrom,@JsonKey(name: 'available_to') DateTime? availableTo, String status,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class __$RentalItemModelCopyWithImpl<$Res>
    implements _$RentalItemModelCopyWith<$Res> {
  __$RentalItemModelCopyWithImpl(this._self, this._then);

  final _RentalItemModel _self;
  final $Res Function(_RentalItemModel) _then;

/// Create a copy of RentalItemModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? lenderId = null,Object? concertId = freezed,Object? category = null,Object? title = null,Object? description = freezed,Object? photos = null,Object? dailyPrice = null,Object? currency = null,Object? deposit = null,Object? conditionGrade = freezed,Object? vlmTag = freezed,Object? btVerified = null,Object? imei = freezed,Object? imeiVerified = null,Object? pickupMethod = null,Object? pickupLocation = freezed,Object? availableFrom = freezed,Object? availableTo = freezed,Object? status = null,Object? createdAt = freezed,}) {
  return _then(_RentalItemModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,lenderId: null == lenderId ? _self.lenderId : lenderId // ignore: cast_nullable_to_non_nullable
as String,concertId: freezed == concertId ? _self.concertId : concertId // ignore: cast_nullable_to_non_nullable
as String?,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,photos: null == photos ? _self._photos : photos // ignore: cast_nullable_to_non_nullable
as List<String>,dailyPrice: null == dailyPrice ? _self.dailyPrice : dailyPrice // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,deposit: null == deposit ? _self.deposit : deposit // ignore: cast_nullable_to_non_nullable
as int,conditionGrade: freezed == conditionGrade ? _self.conditionGrade : conditionGrade // ignore: cast_nullable_to_non_nullable
as String?,vlmTag: freezed == vlmTag ? _self.vlmTag : vlmTag // ignore: cast_nullable_to_non_nullable
as String?,btVerified: null == btVerified ? _self.btVerified : btVerified // ignore: cast_nullable_to_non_nullable
as bool,imei: freezed == imei ? _self.imei : imei // ignore: cast_nullable_to_non_nullable
as String?,imeiVerified: null == imeiVerified ? _self.imeiVerified : imeiVerified // ignore: cast_nullable_to_non_nullable
as bool,pickupMethod: null == pickupMethod ? _self.pickupMethod : pickupMethod // ignore: cast_nullable_to_non_nullable
as String,pickupLocation: freezed == pickupLocation ? _self._pickupLocation : pickupLocation // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,availableFrom: freezed == availableFrom ? _self.availableFrom : availableFrom // ignore: cast_nullable_to_non_nullable
as DateTime?,availableTo: freezed == availableTo ? _self.availableTo : availableTo // ignore: cast_nullable_to_non_nullable
as DateTime?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
