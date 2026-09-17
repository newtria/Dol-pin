import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('iOS permission localization', () {
    test('ships InfoPlist.strings for every app locale', () {
      for (final locale in ['en', 'ko', 'ja', 'id']) {
        final file = File('ios/Runner/$locale.lproj/InfoPlist.strings');
        expect(
          file.existsSync(),
          isTrue,
          reason: '$locale localization missing',
        );
        final contents = file.readAsStringSync();
        expect(contents, contains('NSCameraUsageDescription'));
        expect(contents, contains('NSPhotoLibraryUsageDescription'));
        expect(contents, contains('NSLocationWhenInUseUsageDescription'));
        expect(contents, contains('NSBluetoothAlwaysUsageDescription'));
      }
    });

    test('adds localized InfoPlist.strings to the Xcode resources phase', () {
      final project = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();

      expect(project, contains('InfoPlist.strings in Resources'));
      expect(project, contains('ko.lproj/InfoPlist.strings'));
      expect(project, contains('ja.lproj/InfoPlist.strings'));
      expect(project, contains('id.lproj/InfoPlist.strings'));
    });
  });
}
