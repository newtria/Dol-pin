// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'concert_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ConcertModel _$ConcertModelFromJson(Map<String, dynamic> json) =>
    _ConcertModel(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      venue: json['venue'] as String,
      city: json['city'] as String,
      country: json['country'] as String,
      concertDate: DateTime.parse(json['concert_date'] as String),
      posterUrl: json['poster_url'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$ConcertModelToJson(_ConcertModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'artist': instance.artist,
      'venue': instance.venue,
      'city': instance.city,
      'country': instance.country,
      'concert_date': instance.concertDate.toIso8601String(),
      'poster_url': instance.posterUrl,
      'created_at': instance.createdAt?.toIso8601String(),
    };
