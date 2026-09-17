// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_message_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChatMessageModel {

 String get id;@JsonKey(name: 'reservation_id') String? get reservationId;@JsonKey(name: 'sender_id') String get senderId;@JsonKey(name: 'receiver_id') String get receiverId; String? get message;@JsonKey(name: 'translated_message') String? get translatedMessage;@JsonKey(name: 'source_lang') String? get sourceLang;@JsonKey(name: 'image_url') String? get imageUrl; Map<String, dynamic>? get location;@JsonKey(name: 'read_at') DateTime? get readAt;@JsonKey(name: 'created_at') DateTime? get createdAt;
/// Create a copy of ChatMessageModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatMessageModelCopyWith<ChatMessageModel> get copyWith => _$ChatMessageModelCopyWithImpl<ChatMessageModel>(this as ChatMessageModel, _$identity);

  /// Serializes this ChatMessageModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatMessageModel&&(identical(other.id, id) || other.id == id)&&(identical(other.reservationId, reservationId) || other.reservationId == reservationId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.receiverId, receiverId) || other.receiverId == receiverId)&&(identical(other.message, message) || other.message == message)&&(identical(other.translatedMessage, translatedMessage) || other.translatedMessage == translatedMessage)&&(identical(other.sourceLang, sourceLang) || other.sourceLang == sourceLang)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&const DeepCollectionEquality().equals(other.location, location)&&(identical(other.readAt, readAt) || other.readAt == readAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,reservationId,senderId,receiverId,message,translatedMessage,sourceLang,imageUrl,const DeepCollectionEquality().hash(location),readAt,createdAt);

@override
String toString() {
  return 'ChatMessageModel(id: $id, reservationId: $reservationId, senderId: $senderId, receiverId: $receiverId, message: $message, translatedMessage: $translatedMessage, sourceLang: $sourceLang, imageUrl: $imageUrl, location: $location, readAt: $readAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $ChatMessageModelCopyWith<$Res>  {
  factory $ChatMessageModelCopyWith(ChatMessageModel value, $Res Function(ChatMessageModel) _then) = _$ChatMessageModelCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'reservation_id') String? reservationId,@JsonKey(name: 'sender_id') String senderId,@JsonKey(name: 'receiver_id') String receiverId, String? message,@JsonKey(name: 'translated_message') String? translatedMessage,@JsonKey(name: 'source_lang') String? sourceLang,@JsonKey(name: 'image_url') String? imageUrl, Map<String, dynamic>? location,@JsonKey(name: 'read_at') DateTime? readAt,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class _$ChatMessageModelCopyWithImpl<$Res>
    implements $ChatMessageModelCopyWith<$Res> {
  _$ChatMessageModelCopyWithImpl(this._self, this._then);

  final ChatMessageModel _self;
  final $Res Function(ChatMessageModel) _then;

/// Create a copy of ChatMessageModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? reservationId = freezed,Object? senderId = null,Object? receiverId = null,Object? message = freezed,Object? translatedMessage = freezed,Object? sourceLang = freezed,Object? imageUrl = freezed,Object? location = freezed,Object? readAt = freezed,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,reservationId: freezed == reservationId ? _self.reservationId : reservationId // ignore: cast_nullable_to_non_nullable
as String?,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,receiverId: null == receiverId ? _self.receiverId : receiverId // ignore: cast_nullable_to_non_nullable
as String,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,translatedMessage: freezed == translatedMessage ? _self.translatedMessage : translatedMessage // ignore: cast_nullable_to_non_nullable
as String?,sourceLang: freezed == sourceLang ? _self.sourceLang : sourceLang // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ChatMessageModel].
extension ChatMessageModelPatterns on ChatMessageModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatMessageModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatMessageModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatMessageModel value)  $default,){
final _that = this;
switch (_that) {
case _ChatMessageModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatMessageModel value)?  $default,){
final _that = this;
switch (_that) {
case _ChatMessageModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'reservation_id')  String? reservationId, @JsonKey(name: 'sender_id')  String senderId, @JsonKey(name: 'receiver_id')  String receiverId,  String? message, @JsonKey(name: 'translated_message')  String? translatedMessage, @JsonKey(name: 'source_lang')  String? sourceLang, @JsonKey(name: 'image_url')  String? imageUrl,  Map<String, dynamic>? location, @JsonKey(name: 'read_at')  DateTime? readAt, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatMessageModel() when $default != null:
return $default(_that.id,_that.reservationId,_that.senderId,_that.receiverId,_that.message,_that.translatedMessage,_that.sourceLang,_that.imageUrl,_that.location,_that.readAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'reservation_id')  String? reservationId, @JsonKey(name: 'sender_id')  String senderId, @JsonKey(name: 'receiver_id')  String receiverId,  String? message, @JsonKey(name: 'translated_message')  String? translatedMessage, @JsonKey(name: 'source_lang')  String? sourceLang, @JsonKey(name: 'image_url')  String? imageUrl,  Map<String, dynamic>? location, @JsonKey(name: 'read_at')  DateTime? readAt, @JsonKey(name: 'created_at')  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _ChatMessageModel():
return $default(_that.id,_that.reservationId,_that.senderId,_that.receiverId,_that.message,_that.translatedMessage,_that.sourceLang,_that.imageUrl,_that.location,_that.readAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'reservation_id')  String? reservationId, @JsonKey(name: 'sender_id')  String senderId, @JsonKey(name: 'receiver_id')  String receiverId,  String? message, @JsonKey(name: 'translated_message')  String? translatedMessage, @JsonKey(name: 'source_lang')  String? sourceLang, @JsonKey(name: 'image_url')  String? imageUrl,  Map<String, dynamic>? location, @JsonKey(name: 'read_at')  DateTime? readAt, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _ChatMessageModel() when $default != null:
return $default(_that.id,_that.reservationId,_that.senderId,_that.receiverId,_that.message,_that.translatedMessage,_that.sourceLang,_that.imageUrl,_that.location,_that.readAt,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChatMessageModel implements ChatMessageModel {
  const _ChatMessageModel({required this.id, @JsonKey(name: 'reservation_id') this.reservationId, @JsonKey(name: 'sender_id') required this.senderId, @JsonKey(name: 'receiver_id') required this.receiverId, this.message, @JsonKey(name: 'translated_message') this.translatedMessage, @JsonKey(name: 'source_lang') this.sourceLang, @JsonKey(name: 'image_url') this.imageUrl, final  Map<String, dynamic>? location, @JsonKey(name: 'read_at') this.readAt, @JsonKey(name: 'created_at') this.createdAt}): _location = location;
  factory _ChatMessageModel.fromJson(Map<String, dynamic> json) => _$ChatMessageModelFromJson(json);

@override final  String id;
@override@JsonKey(name: 'reservation_id') final  String? reservationId;
@override@JsonKey(name: 'sender_id') final  String senderId;
@override@JsonKey(name: 'receiver_id') final  String receiverId;
@override final  String? message;
@override@JsonKey(name: 'translated_message') final  String? translatedMessage;
@override@JsonKey(name: 'source_lang') final  String? sourceLang;
@override@JsonKey(name: 'image_url') final  String? imageUrl;
 final  Map<String, dynamic>? _location;
@override Map<String, dynamic>? get location {
  final value = _location;
  if (value == null) return null;
  if (_location is EqualUnmodifiableMapView) return _location;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey(name: 'read_at') final  DateTime? readAt;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;

/// Create a copy of ChatMessageModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatMessageModelCopyWith<_ChatMessageModel> get copyWith => __$ChatMessageModelCopyWithImpl<_ChatMessageModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChatMessageModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatMessageModel&&(identical(other.id, id) || other.id == id)&&(identical(other.reservationId, reservationId) || other.reservationId == reservationId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.receiverId, receiverId) || other.receiverId == receiverId)&&(identical(other.message, message) || other.message == message)&&(identical(other.translatedMessage, translatedMessage) || other.translatedMessage == translatedMessage)&&(identical(other.sourceLang, sourceLang) || other.sourceLang == sourceLang)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&const DeepCollectionEquality().equals(other._location, _location)&&(identical(other.readAt, readAt) || other.readAt == readAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,reservationId,senderId,receiverId,message,translatedMessage,sourceLang,imageUrl,const DeepCollectionEquality().hash(_location),readAt,createdAt);

@override
String toString() {
  return 'ChatMessageModel(id: $id, reservationId: $reservationId, senderId: $senderId, receiverId: $receiverId, message: $message, translatedMessage: $translatedMessage, sourceLang: $sourceLang, imageUrl: $imageUrl, location: $location, readAt: $readAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$ChatMessageModelCopyWith<$Res> implements $ChatMessageModelCopyWith<$Res> {
  factory _$ChatMessageModelCopyWith(_ChatMessageModel value, $Res Function(_ChatMessageModel) _then) = __$ChatMessageModelCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'reservation_id') String? reservationId,@JsonKey(name: 'sender_id') String senderId,@JsonKey(name: 'receiver_id') String receiverId, String? message,@JsonKey(name: 'translated_message') String? translatedMessage,@JsonKey(name: 'source_lang') String? sourceLang,@JsonKey(name: 'image_url') String? imageUrl, Map<String, dynamic>? location,@JsonKey(name: 'read_at') DateTime? readAt,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class __$ChatMessageModelCopyWithImpl<$Res>
    implements _$ChatMessageModelCopyWith<$Res> {
  __$ChatMessageModelCopyWithImpl(this._self, this._then);

  final _ChatMessageModel _self;
  final $Res Function(_ChatMessageModel) _then;

/// Create a copy of ChatMessageModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? reservationId = freezed,Object? senderId = null,Object? receiverId = null,Object? message = freezed,Object? translatedMessage = freezed,Object? sourceLang = freezed,Object? imageUrl = freezed,Object? location = freezed,Object? readAt = freezed,Object? createdAt = freezed,}) {
  return _then(_ChatMessageModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,reservationId: freezed == reservationId ? _self.reservationId : reservationId // ignore: cast_nullable_to_non_nullable
as String?,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,receiverId: null == receiverId ? _self.receiverId : receiverId // ignore: cast_nullable_to_non_nullable
as String,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,translatedMessage: freezed == translatedMessage ? _self.translatedMessage : translatedMessage // ignore: cast_nullable_to_non_nullable
as String?,sourceLang: freezed == sourceLang ? _self.sourceLang : sourceLang // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,location: freezed == location ? _self._location : location // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
