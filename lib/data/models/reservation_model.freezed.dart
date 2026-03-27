// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reservation_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReservationModel {

 String get id;@JsonKey(name: 'item_id') String get itemId;@JsonKey(name: 'borrower_id') String get borrowerId;@JsonKey(name: 'lender_id') String get lenderId;@JsonKey(name: 'rental_date') DateTime get rentalDate;@JsonKey(name: 'return_date') DateTime get returnDate;@JsonKey(name: 'rental_fee') int get rentalFee; int get deposit;@JsonKey(name: 'total_paid') int get totalPaid; String get currency; String get status;@JsonKey(name: 'pickup_confirmed_at') DateTime? get pickupConfirmedAt;@JsonKey(name: 'return_confirmed_at') DateTime? get returnConfirmedAt;@JsonKey(name: 'return_photo') String? get returnPhoto;@JsonKey(name: 'payment_provider') String? get paymentProvider;@JsonKey(name: 'payment_id') String? get paymentId;@JsonKey(name: 'created_at') DateTime? get createdAt;
/// Create a copy of ReservationModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReservationModelCopyWith<ReservationModel> get copyWith => _$ReservationModelCopyWithImpl<ReservationModel>(this as ReservationModel, _$identity);

  /// Serializes this ReservationModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReservationModel&&(identical(other.id, id) || other.id == id)&&(identical(other.itemId, itemId) || other.itemId == itemId)&&(identical(other.borrowerId, borrowerId) || other.borrowerId == borrowerId)&&(identical(other.lenderId, lenderId) || other.lenderId == lenderId)&&(identical(other.rentalDate, rentalDate) || other.rentalDate == rentalDate)&&(identical(other.returnDate, returnDate) || other.returnDate == returnDate)&&(identical(other.rentalFee, rentalFee) || other.rentalFee == rentalFee)&&(identical(other.deposit, deposit) || other.deposit == deposit)&&(identical(other.totalPaid, totalPaid) || other.totalPaid == totalPaid)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.status, status) || other.status == status)&&(identical(other.pickupConfirmedAt, pickupConfirmedAt) || other.pickupConfirmedAt == pickupConfirmedAt)&&(identical(other.returnConfirmedAt, returnConfirmedAt) || other.returnConfirmedAt == returnConfirmedAt)&&(identical(other.returnPhoto, returnPhoto) || other.returnPhoto == returnPhoto)&&(identical(other.paymentProvider, paymentProvider) || other.paymentProvider == paymentProvider)&&(identical(other.paymentId, paymentId) || other.paymentId == paymentId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,itemId,borrowerId,lenderId,rentalDate,returnDate,rentalFee,deposit,totalPaid,currency,status,pickupConfirmedAt,returnConfirmedAt,returnPhoto,paymentProvider,paymentId,createdAt);

@override
String toString() {
  return 'ReservationModel(id: $id, itemId: $itemId, borrowerId: $borrowerId, lenderId: $lenderId, rentalDate: $rentalDate, returnDate: $returnDate, rentalFee: $rentalFee, deposit: $deposit, totalPaid: $totalPaid, currency: $currency, status: $status, pickupConfirmedAt: $pickupConfirmedAt, returnConfirmedAt: $returnConfirmedAt, returnPhoto: $returnPhoto, paymentProvider: $paymentProvider, paymentId: $paymentId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $ReservationModelCopyWith<$Res>  {
  factory $ReservationModelCopyWith(ReservationModel value, $Res Function(ReservationModel) _then) = _$ReservationModelCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'item_id') String itemId,@JsonKey(name: 'borrower_id') String borrowerId,@JsonKey(name: 'lender_id') String lenderId,@JsonKey(name: 'rental_date') DateTime rentalDate,@JsonKey(name: 'return_date') DateTime returnDate,@JsonKey(name: 'rental_fee') int rentalFee, int deposit,@JsonKey(name: 'total_paid') int totalPaid, String currency, String status,@JsonKey(name: 'pickup_confirmed_at') DateTime? pickupConfirmedAt,@JsonKey(name: 'return_confirmed_at') DateTime? returnConfirmedAt,@JsonKey(name: 'return_photo') String? returnPhoto,@JsonKey(name: 'payment_provider') String? paymentProvider,@JsonKey(name: 'payment_id') String? paymentId,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class _$ReservationModelCopyWithImpl<$Res>
    implements $ReservationModelCopyWith<$Res> {
  _$ReservationModelCopyWithImpl(this._self, this._then);

  final ReservationModel _self;
  final $Res Function(ReservationModel) _then;

/// Create a copy of ReservationModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? itemId = null,Object? borrowerId = null,Object? lenderId = null,Object? rentalDate = null,Object? returnDate = null,Object? rentalFee = null,Object? deposit = null,Object? totalPaid = null,Object? currency = null,Object? status = null,Object? pickupConfirmedAt = freezed,Object? returnConfirmedAt = freezed,Object? returnPhoto = freezed,Object? paymentProvider = freezed,Object? paymentId = freezed,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,itemId: null == itemId ? _self.itemId : itemId // ignore: cast_nullable_to_non_nullable
as String,borrowerId: null == borrowerId ? _self.borrowerId : borrowerId // ignore: cast_nullable_to_non_nullable
as String,lenderId: null == lenderId ? _self.lenderId : lenderId // ignore: cast_nullable_to_non_nullable
as String,rentalDate: null == rentalDate ? _self.rentalDate : rentalDate // ignore: cast_nullable_to_non_nullable
as DateTime,returnDate: null == returnDate ? _self.returnDate : returnDate // ignore: cast_nullable_to_non_nullable
as DateTime,rentalFee: null == rentalFee ? _self.rentalFee : rentalFee // ignore: cast_nullable_to_non_nullable
as int,deposit: null == deposit ? _self.deposit : deposit // ignore: cast_nullable_to_non_nullable
as int,totalPaid: null == totalPaid ? _self.totalPaid : totalPaid // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,pickupConfirmedAt: freezed == pickupConfirmedAt ? _self.pickupConfirmedAt : pickupConfirmedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,returnConfirmedAt: freezed == returnConfirmedAt ? _self.returnConfirmedAt : returnConfirmedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,returnPhoto: freezed == returnPhoto ? _self.returnPhoto : returnPhoto // ignore: cast_nullable_to_non_nullable
as String?,paymentProvider: freezed == paymentProvider ? _self.paymentProvider : paymentProvider // ignore: cast_nullable_to_non_nullable
as String?,paymentId: freezed == paymentId ? _self.paymentId : paymentId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ReservationModel].
extension ReservationModelPatterns on ReservationModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReservationModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReservationModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReservationModel value)  $default,){
final _that = this;
switch (_that) {
case _ReservationModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReservationModel value)?  $default,){
final _that = this;
switch (_that) {
case _ReservationModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'item_id')  String itemId, @JsonKey(name: 'borrower_id')  String borrowerId, @JsonKey(name: 'lender_id')  String lenderId, @JsonKey(name: 'rental_date')  DateTime rentalDate, @JsonKey(name: 'return_date')  DateTime returnDate, @JsonKey(name: 'rental_fee')  int rentalFee,  int deposit, @JsonKey(name: 'total_paid')  int totalPaid,  String currency,  String status, @JsonKey(name: 'pickup_confirmed_at')  DateTime? pickupConfirmedAt, @JsonKey(name: 'return_confirmed_at')  DateTime? returnConfirmedAt, @JsonKey(name: 'return_photo')  String? returnPhoto, @JsonKey(name: 'payment_provider')  String? paymentProvider, @JsonKey(name: 'payment_id')  String? paymentId, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReservationModel() when $default != null:
return $default(_that.id,_that.itemId,_that.borrowerId,_that.lenderId,_that.rentalDate,_that.returnDate,_that.rentalFee,_that.deposit,_that.totalPaid,_that.currency,_that.status,_that.pickupConfirmedAt,_that.returnConfirmedAt,_that.returnPhoto,_that.paymentProvider,_that.paymentId,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'item_id')  String itemId, @JsonKey(name: 'borrower_id')  String borrowerId, @JsonKey(name: 'lender_id')  String lenderId, @JsonKey(name: 'rental_date')  DateTime rentalDate, @JsonKey(name: 'return_date')  DateTime returnDate, @JsonKey(name: 'rental_fee')  int rentalFee,  int deposit, @JsonKey(name: 'total_paid')  int totalPaid,  String currency,  String status, @JsonKey(name: 'pickup_confirmed_at')  DateTime? pickupConfirmedAt, @JsonKey(name: 'return_confirmed_at')  DateTime? returnConfirmedAt, @JsonKey(name: 'return_photo')  String? returnPhoto, @JsonKey(name: 'payment_provider')  String? paymentProvider, @JsonKey(name: 'payment_id')  String? paymentId, @JsonKey(name: 'created_at')  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _ReservationModel():
return $default(_that.id,_that.itemId,_that.borrowerId,_that.lenderId,_that.rentalDate,_that.returnDate,_that.rentalFee,_that.deposit,_that.totalPaid,_that.currency,_that.status,_that.pickupConfirmedAt,_that.returnConfirmedAt,_that.returnPhoto,_that.paymentProvider,_that.paymentId,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'item_id')  String itemId, @JsonKey(name: 'borrower_id')  String borrowerId, @JsonKey(name: 'lender_id')  String lenderId, @JsonKey(name: 'rental_date')  DateTime rentalDate, @JsonKey(name: 'return_date')  DateTime returnDate, @JsonKey(name: 'rental_fee')  int rentalFee,  int deposit, @JsonKey(name: 'total_paid')  int totalPaid,  String currency,  String status, @JsonKey(name: 'pickup_confirmed_at')  DateTime? pickupConfirmedAt, @JsonKey(name: 'return_confirmed_at')  DateTime? returnConfirmedAt, @JsonKey(name: 'return_photo')  String? returnPhoto, @JsonKey(name: 'payment_provider')  String? paymentProvider, @JsonKey(name: 'payment_id')  String? paymentId, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _ReservationModel() when $default != null:
return $default(_that.id,_that.itemId,_that.borrowerId,_that.lenderId,_that.rentalDate,_that.returnDate,_that.rentalFee,_that.deposit,_that.totalPaid,_that.currency,_that.status,_that.pickupConfirmedAt,_that.returnConfirmedAt,_that.returnPhoto,_that.paymentProvider,_that.paymentId,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReservationModel implements ReservationModel {
  const _ReservationModel({required this.id, @JsonKey(name: 'item_id') required this.itemId, @JsonKey(name: 'borrower_id') required this.borrowerId, @JsonKey(name: 'lender_id') required this.lenderId, @JsonKey(name: 'rental_date') required this.rentalDate, @JsonKey(name: 'return_date') required this.returnDate, @JsonKey(name: 'rental_fee') required this.rentalFee, required this.deposit, @JsonKey(name: 'total_paid') required this.totalPaid, required this.currency, this.status = 'pending', @JsonKey(name: 'pickup_confirmed_at') this.pickupConfirmedAt, @JsonKey(name: 'return_confirmed_at') this.returnConfirmedAt, @JsonKey(name: 'return_photo') this.returnPhoto, @JsonKey(name: 'payment_provider') this.paymentProvider, @JsonKey(name: 'payment_id') this.paymentId, @JsonKey(name: 'created_at') this.createdAt});
  factory _ReservationModel.fromJson(Map<String, dynamic> json) => _$ReservationModelFromJson(json);

@override final  String id;
@override@JsonKey(name: 'item_id') final  String itemId;
@override@JsonKey(name: 'borrower_id') final  String borrowerId;
@override@JsonKey(name: 'lender_id') final  String lenderId;
@override@JsonKey(name: 'rental_date') final  DateTime rentalDate;
@override@JsonKey(name: 'return_date') final  DateTime returnDate;
@override@JsonKey(name: 'rental_fee') final  int rentalFee;
@override final  int deposit;
@override@JsonKey(name: 'total_paid') final  int totalPaid;
@override final  String currency;
@override@JsonKey() final  String status;
@override@JsonKey(name: 'pickup_confirmed_at') final  DateTime? pickupConfirmedAt;
@override@JsonKey(name: 'return_confirmed_at') final  DateTime? returnConfirmedAt;
@override@JsonKey(name: 'return_photo') final  String? returnPhoto;
@override@JsonKey(name: 'payment_provider') final  String? paymentProvider;
@override@JsonKey(name: 'payment_id') final  String? paymentId;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;

/// Create a copy of ReservationModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReservationModelCopyWith<_ReservationModel> get copyWith => __$ReservationModelCopyWithImpl<_ReservationModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReservationModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReservationModel&&(identical(other.id, id) || other.id == id)&&(identical(other.itemId, itemId) || other.itemId == itemId)&&(identical(other.borrowerId, borrowerId) || other.borrowerId == borrowerId)&&(identical(other.lenderId, lenderId) || other.lenderId == lenderId)&&(identical(other.rentalDate, rentalDate) || other.rentalDate == rentalDate)&&(identical(other.returnDate, returnDate) || other.returnDate == returnDate)&&(identical(other.rentalFee, rentalFee) || other.rentalFee == rentalFee)&&(identical(other.deposit, deposit) || other.deposit == deposit)&&(identical(other.totalPaid, totalPaid) || other.totalPaid == totalPaid)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.status, status) || other.status == status)&&(identical(other.pickupConfirmedAt, pickupConfirmedAt) || other.pickupConfirmedAt == pickupConfirmedAt)&&(identical(other.returnConfirmedAt, returnConfirmedAt) || other.returnConfirmedAt == returnConfirmedAt)&&(identical(other.returnPhoto, returnPhoto) || other.returnPhoto == returnPhoto)&&(identical(other.paymentProvider, paymentProvider) || other.paymentProvider == paymentProvider)&&(identical(other.paymentId, paymentId) || other.paymentId == paymentId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,itemId,borrowerId,lenderId,rentalDate,returnDate,rentalFee,deposit,totalPaid,currency,status,pickupConfirmedAt,returnConfirmedAt,returnPhoto,paymentProvider,paymentId,createdAt);

@override
String toString() {
  return 'ReservationModel(id: $id, itemId: $itemId, borrowerId: $borrowerId, lenderId: $lenderId, rentalDate: $rentalDate, returnDate: $returnDate, rentalFee: $rentalFee, deposit: $deposit, totalPaid: $totalPaid, currency: $currency, status: $status, pickupConfirmedAt: $pickupConfirmedAt, returnConfirmedAt: $returnConfirmedAt, returnPhoto: $returnPhoto, paymentProvider: $paymentProvider, paymentId: $paymentId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$ReservationModelCopyWith<$Res> implements $ReservationModelCopyWith<$Res> {
  factory _$ReservationModelCopyWith(_ReservationModel value, $Res Function(_ReservationModel) _then) = __$ReservationModelCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'item_id') String itemId,@JsonKey(name: 'borrower_id') String borrowerId,@JsonKey(name: 'lender_id') String lenderId,@JsonKey(name: 'rental_date') DateTime rentalDate,@JsonKey(name: 'return_date') DateTime returnDate,@JsonKey(name: 'rental_fee') int rentalFee, int deposit,@JsonKey(name: 'total_paid') int totalPaid, String currency, String status,@JsonKey(name: 'pickup_confirmed_at') DateTime? pickupConfirmedAt,@JsonKey(name: 'return_confirmed_at') DateTime? returnConfirmedAt,@JsonKey(name: 'return_photo') String? returnPhoto,@JsonKey(name: 'payment_provider') String? paymentProvider,@JsonKey(name: 'payment_id') String? paymentId,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class __$ReservationModelCopyWithImpl<$Res>
    implements _$ReservationModelCopyWith<$Res> {
  __$ReservationModelCopyWithImpl(this._self, this._then);

  final _ReservationModel _self;
  final $Res Function(_ReservationModel) _then;

/// Create a copy of ReservationModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? itemId = null,Object? borrowerId = null,Object? lenderId = null,Object? rentalDate = null,Object? returnDate = null,Object? rentalFee = null,Object? deposit = null,Object? totalPaid = null,Object? currency = null,Object? status = null,Object? pickupConfirmedAt = freezed,Object? returnConfirmedAt = freezed,Object? returnPhoto = freezed,Object? paymentProvider = freezed,Object? paymentId = freezed,Object? createdAt = freezed,}) {
  return _then(_ReservationModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,itemId: null == itemId ? _self.itemId : itemId // ignore: cast_nullable_to_non_nullable
as String,borrowerId: null == borrowerId ? _self.borrowerId : borrowerId // ignore: cast_nullable_to_non_nullable
as String,lenderId: null == lenderId ? _self.lenderId : lenderId // ignore: cast_nullable_to_non_nullable
as String,rentalDate: null == rentalDate ? _self.rentalDate : rentalDate // ignore: cast_nullable_to_non_nullable
as DateTime,returnDate: null == returnDate ? _self.returnDate : returnDate // ignore: cast_nullable_to_non_nullable
as DateTime,rentalFee: null == rentalFee ? _self.rentalFee : rentalFee // ignore: cast_nullable_to_non_nullable
as int,deposit: null == deposit ? _self.deposit : deposit // ignore: cast_nullable_to_non_nullable
as int,totalPaid: null == totalPaid ? _self.totalPaid : totalPaid // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,pickupConfirmedAt: freezed == pickupConfirmedAt ? _self.pickupConfirmedAt : pickupConfirmedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,returnConfirmedAt: freezed == returnConfirmedAt ? _self.returnConfirmedAt : returnConfirmedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,returnPhoto: freezed == returnPhoto ? _self.returnPhoto : returnPhoto // ignore: cast_nullable_to_non_nullable
as String?,paymentProvider: freezed == paymentProvider ? _self.paymentProvider : paymentProvider // ignore: cast_nullable_to_non_nullable
as String?,paymentId: freezed == paymentId ? _self.paymentId : paymentId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
