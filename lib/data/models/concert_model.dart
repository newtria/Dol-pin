import 'package:freezed_annotation/freezed_annotation.dart';

part 'concert_model.freezed.dart';
part 'concert_model.g.dart';

@freezed
abstract class ConcertModel with _$ConcertModel {
  const factory ConcertModel({
    required String id,
    required String title,
    required String artist,
    required String venue,
    required String city,
    required String country,
    @JsonKey(name: 'concert_date') required DateTime concertDate,
    @JsonKey(name: 'poster_url') String? posterUrl,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _ConcertModel;

  factory ConcertModel.fromJson(Map<String, dynamic> json) =>
      _$ConcertModelFromJson(json);
}
