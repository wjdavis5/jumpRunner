import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Asset Inventory & License Verification', () {
    test('Kenney license file exists and contains CC0 terms', () {
      final licenseFile = File('assets/LICENSE_KENNEY.txt');
      expect(licenseFile.existsSync(), isTrue, reason: 'assets/LICENSE_KENNEY.txt must exist on disk');

      final content = licenseFile.readAsStringSync();
      expect(content, contains('Creative Commons Zero'));
      expect(content, contains('CC0'));
    });

    test('All curated courier character sprites exist on disk', () {
      final requiredSprites = [
        'assets/images/courier/run_1.png',
        'assets/images/courier/run_2.png',
        'assets/images/courier/run_3.png',
        'assets/images/courier/run_4.png',
        'assets/images/courier/jump.png',
        'assets/images/courier/hurt.png',
      ];

      for (final path in requiredSprites) {
        expect(File(path).existsSync(), isTrue, reason: '$path must exist');
      }
    });

    test('All curated environment layers exist on disk', () {
      final requiredLayers = [
        'assets/images/environment/city_bg_layer1.png',
        'assets/images/environment/city_bg_layer2.png',
        'assets/images/environment/city_bg_layer3.png',
      ];

      for (final path in requiredLayers) {
        expect(File(path).existsSync(), isTrue, reason: '$path must exist');
      }
    });

    test('All street hazards exist on disk', () {
      final requiredHazards = [
        'assets/images/hazards/scooter.png',
        'assets/images/hazards/dog.png',
        'assets/images/hazards/van.png',
        'assets/images/hazards/hydrant.png',
      ];

      for (final path in requiredHazards) {
        expect(File(path).existsSync(), isTrue, reason: '$path must exist');
      }
    });

    test('All collectible pickups exist on disk', () {
      final requiredPickups = [
        'assets/images/pickups/coin.png',
        'assets/images/pickups/energy_drink.png',
        'assets/images/pickups/package_box.png',
      ];

      for (final path in requiredPickups) {
        expect(File(path).existsSync(), isTrue, reason: '$path must exist');
      }
    });

    test('All SFX audio and music files exist on disk', () {
      final requiredAudio = [
        'assets/audio/sfx/jump.ogg',
        'assets/audio/sfx/coin.ogg',
        'assets/audio/sfx/fumble.ogg',
        'assets/audio/sfx/milestone.ogg',
        'assets/audio/sfx/rain_ambience.ogg',
        'assets/audio/music/courier_groove.ogg',
      ];

      for (final path in requiredAudio) {
        expect(File(path).existsSync(), isTrue, reason: '$path must exist');
      }
    });
  });
}
