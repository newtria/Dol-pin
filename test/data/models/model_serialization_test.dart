import 'package:flutter_test/flutter_test.dart';
import 'package:dolpin/data/models/concert_model.dart';
import 'package:dolpin/data/models/rental_item_model.dart';
import 'package:dolpin/data/models/user_model.dart';

void main() {
  group('ConcertModel', () {
    test('fromJson roundtrip', () {
      final json = {
        'id': '123',
        'title': 'BTS World Tour',
        'artist': 'BTS',
        'venue': 'Seoul Olympic Stadium',
        'city': 'Seoul',
        'country': 'KR',
        'concert_date': '2025-06-15T19:00:00.000Z',
        'poster_url': 'https://example.com/poster.jpg',
      };
      final model = ConcertModel.fromJson(json);
      expect(model.id, '123');
      expect(model.artist, 'BTS');
      expect(model.concertDate.year, 2025);

      final backToJson = model.toJson();
      expect(backToJson['artist'], 'BTS');
      expect(backToJson['concert_date'], '2025-06-15T19:00:00.000Z');
    });
  });

  group('RentalItemModel', () {
    test('fromJson with all fields', () {
      final json = {
        'id': 'item1',
        'lender_id': 'user1',
        'category': 'lightstick',
        'title': 'BTS Lightstick',
        'photos': ['url1', 'url2'],
        'daily_price': 5000,
        'currency': 'KRW',
        'deposit': 50000,
        'pickup_method': 'direct',
        'bt_verified': true,
        'status': 'active',
      };
      final model = RentalItemModel.fromJson(json);
      expect(model.lenderId, 'user1');
      expect(model.btVerified, isTrue);
      expect(model.dailyPrice, 5000);
    });

    test('fromJson with defaults', () {
      final json = {
        'id': 'item2',
        'lender_id': 'user2',
        'category': 'phone',
        'title': 'iPhone 15',
        'photos': <String>[],
        'daily_price': 20000,
        'currency': 'KRW',
        'deposit': 200000,
        'pickup_method': 'delivery',
      };
      final model = RentalItemModel.fromJson(json);
      expect(model.btVerified, isFalse);
      expect(model.status, 'active');
    });
  });

  group('UserModel', () {
    test('fromJson with all fields', () {
      final json = {
        'id': 'user1',
        'phone': '+821012345678',
        'nickname': 'army_fan',
        'profile_image': 'https://example.com/avatar.jpg',
        'is_lender': true,
        'identity_verified': true,
        'lender_grade': 'power',
        'fav_groups': ['BTS', 'BLACKPINK'],
        'country': 'KR',
        'region': 'Seoul',
        'locale': 'ko',
        'currency': 'KRW',
        'response_rate': 95.5,
        'created_at': '2025-01-01T00:00:00.000Z',
      };
      final model = UserModel.fromJson(json);
      expect(model.id, 'user1');
      expect(model.phone, '+821012345678');
      expect(model.nickname, 'army_fan');
      expect(model.profileImage, 'https://example.com/avatar.jpg');
      expect(model.isLender, isTrue);
      expect(model.identityVerified, isTrue);
      expect(model.lenderGrade, 'power');
      expect(model.favGroups, ['BTS', 'BLACKPINK']);
      expect(model.country, 'KR');
      expect(model.region, 'Seoul');
      expect(model.locale, 'ko');
      expect(model.currency, 'KRW');
      expect(model.responseRate, 95.5);
      expect(model.createdAt?.year, 2025);
    });

    test('fromJson with defaults', () {
      final json = {
        'id': 'user2',
        'phone': '+6281234567890',
        'nickname': 'blink_id',
        'country': 'ID',
      };
      final model = UserModel.fromJson(json);
      expect(model.isLender, isFalse);
      expect(model.identityVerified, isFalse);
      expect(model.lenderGrade, 'newbie');
      expect(model.favGroups, isEmpty);
      expect(model.locale, 'en');
      expect(model.currency, 'USD');
      expect(model.responseRate, 0);
      expect(model.profileImage, isNull);
      expect(model.deletedAt, isNull);
    });

    test('toJson roundtrip preserves data', () {
      final json = {
        'id': 'user3',
        'phone': '+819012345678',
        'nickname': 'once_jp',
        'is_lender': true,
        'fav_groups': ['TWICE'],
        'country': 'JP',
        'locale': 'ja',
        'currency': 'JPY',
        'response_rate': 88.0,
      };
      final model = UserModel.fromJson(json);
      final backToJson = model.toJson();
      expect(backToJson['phone'], '+819012345678');
      expect(backToJson['is_lender'], isTrue);
      expect(backToJson['fav_groups'], ['TWICE']);
      expect(backToJson['country'], 'JP');
      expect(backToJson['locale'], 'ja');
      expect(backToJson['currency'], 'JPY');
      expect(backToJson['response_rate'], 88.0);
    });
  });
}
