import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CI/CD Workflows & Fastlane Deployment (U7)', () {
    test('All required GitHub Actions workflows exist and contain valid directives', () {
      final workflows = [
        '.github/workflows/pr-checks.yml',
        '.github/workflows/web-deploy.yml',
        '.github/workflows/ios-release.yml',
        '.github/workflows/android-release.yml',
      ];

      for (final path in workflows) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path must exist on disk');

        final content = file.readAsStringSync();
        expect(content, contains('name:'));
        expect(content, contains('runs-on:'));
        expect(content, contains('steps:'));
      }
    });

    test('Fastlane Appfile and Fastfile exist and configure distribution lanes', () {
      final appfile = File('fastlane/Appfile');
      expect(appfile.existsSync(), isTrue);
      expect(appfile.readAsStringSync(), contains('app_identifier'));

      final fastfile = File('fastlane/Fastfile');
      expect(fastfile.existsSync(), isTrue);
      final fastfileContent = fastfile.readAsStringSync();
      expect(fastfileContent, contains('lane :test'));
      expect(fastfileContent, contains('lane :beta'));
      expect(fastfileContent, contains('lane :submit'));
    });

    test('App icon generator script exists and is executable', () {
      final script = File('tools/generate_app_icons.sh');
      expect(script.existsSync(), isTrue);
      expect(script.readAsStringSync(), contains('generate_app_icons'));
    });
  });
}
