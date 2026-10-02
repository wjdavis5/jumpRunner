import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAudioBackend implements AudioPlayerInterface {
  final List<String> playedSfx = [];
  String? activeBgm;
  bool isBgmPlaying = false;

  @override
  Future<void> playSfx(String file, {double volume = 1.0}) async {
    playedSfx.add(file);
  }

  @override
  Future<void> startBgm(String file, {double volume = 0.7}) async {
    activeBgm = file;
    isBgmPlaying = true;
  }

  @override
  Future<void> stopBgm() async {
    isBgmPlaying = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameAudioController (U6)', () {
    late MockAudioBackend mockBackend;
    late LocalStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = LocalStorageService();
      await storage.init();
      mockBackend = MockAudioBackend();
    });

    test('Sound effect invocations play correct asset paths', () async {
      final audio = GameAudioController(
        backend: mockBackend,
        storageService: storage,
      );

      await audio.playJump();
      expect(mockBackend.playedSfx.last, equals('sfx/jump.ogg'));

      await audio.playCoin();
      expect(mockBackend.playedSfx.last, equals('sfx/coin.ogg'));

      await audio.playFumble();
      expect(mockBackend.playedSfx.last, equals('sfx/fumble.ogg'));

      await audio.playMilestone();
      expect(mockBackend.playedSfx.last, equals('sfx/milestone.ogg'));

      expect(mockBackend.playedSfx.length, equals(4));
    });

    test('Mute toggle suppresses SFX playback and persists to storage', () async {
      final audio = GameAudioController(
        backend: mockBackend,
        storageService: storage,
      );

      expect(audio.isMuted, isFalse);
      expect(storage.isSoundMuted, isFalse);

      // Toggle mute ON
      await audio.toggleMute();
      expect(audio.isMuted, isTrue);
      expect(storage.isSoundMuted, isTrue);

      // Attempt plays while muted
      mockBackend.playedSfx.clear();
      await audio.playJump();
      await audio.playCoin();
      expect(mockBackend.playedSfx, isEmpty, reason: 'Muted audio controller must not trigger SFX');

      // Toggle mute OFF
      await audio.toggleMute();
      expect(audio.isMuted, isFalse);
      expect(storage.isSoundMuted, isFalse);

      await audio.playJump();
      expect(mockBackend.playedSfx, contains('sfx/jump.ogg'));
    });

    test('Background music loop starts and loops courier_groove track', () async {
      final audio = GameAudioController(
        backend: mockBackend,
        storageService: storage,
      );

      await audio.startMusic();
      expect(mockBackend.isBgmPlaying, isTrue);
      expect(mockBackend.activeBgm, equals('music/courier_groove.ogg'));

      await audio.stopMusic();
      expect(mockBackend.isBgmPlaying, isFalse);
    });

    test('Starting music while muted is suppressed', () async {
      final audio = GameAudioController(
        backend: mockBackend,
        storageService: storage,
      );

      await audio.toggleMute();
      await audio.startMusic();
      expect(mockBackend.isBgmPlaying, isFalse);
    });
  });
}
