import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';

Uint8List _bytes(String asset) => File('assets/audio/$asset').readAsBytesSync();

bool _sameFile(String a, String b) {
  final x = _bytes(a);
  final y = _bytes(b);
  if (x.length != y.length) return false;
  for (var i = 0; i < x.length; i++) {
    if (x[i] != y[i]) return false;
  }
  return true;
}

int _find(Uint8List haystack, List<int> needle, {int from = 0, bool last = false}) {
  var found = -1;
  for (var i = from; i <= haystack.length - needle.length; i++) {
    var match = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (match) {
      if (!last) return i;
      found = i;
    }
  }
  return found;
}

/// Length of an Ogg Vorbis file in seconds, read from its own headers: the
/// sample rate in the identification packet and the sample count stamped on
/// the last page.
double _seconds(String asset) {
  final data = _bytes(asset);
  final view = ByteData.sublistView(data);

  final ident = _find(data, [0x01, ...'vorbis'.codeUnits]);
  expect(ident, greaterThanOrEqualTo(0), reason: '$asset is not Ogg Vorbis');
  final sampleRate = view.getUint32(ident + 12, Endian.little);

  final lastPage = _find(data, 'OggS'.codeUnits, last: true);
  final samples = view.getUint64(lastPage + 6, Endian.little);
  return samples / sampleRate;
}

void main() {
  const everySound = [
    GameAudioController.sfxJump,
    GameAudioController.sfxCoin,
    GameAudioController.sfxFumble,
    GameAudioController.sfxMilestone,
    GameAudioController.sfxRainAmbience,
    GameAudioController.sfxThunder,
    GameAudioController.sfxBarkStunt,
    GameAudioController.sfxBarkNearMiss,
    GameAudioController.sfxBarkDamage,
    GameAudioController.sfxBarkGlide,
    GameAudioController.sfxCustomerThankYou,
    GameAudioController.sfxCustomerFiveStars,
    GameAudioController.musicBgm,
    GameAudioController.musicBgmNight,
    GameAudioController.musicBgmLayer,
    GameAudioController.musicBgmNightLayer,
  ];

  group('Every sound the game asks for exists', () {
    for (final sound in everySound) {
      test(sound, () {
        expect(File('assets/audio/$sound').existsSync(), isTrue);
        expect(_seconds(sound), greaterThan(0.05));
      });
    }
  });

  group('Sounds that loop are made to loop', () {
    test('rain is a real ambience bed, not a looped jingle', () {
      // It used to be a byte-for-byte copy of the half-second milestone
      // chime, repeating twice a second for as long as it rained.
      expect(
        _sameFile(GameAudioController.sfxRainAmbience, GameAudioController.sfxMilestone),
        isFalse,
      );
      expect(_seconds(GameAudioController.sfxRainAmbience), greaterThanOrEqualTo(5.0));
    });

    test('both music tracks are long enough to loop', () {
      expect(_seconds(GameAudioController.musicBgm), greaterThanOrEqualTo(5.0));
      expect(_seconds(GameAudioController.musicBgmNight), greaterThanOrEqualTo(5.0));
    });

    test('each streak layer holds exactly as many samples as its track', () {
      // Started together, layer and BGM repeat in lockstep and never drift.
      expect(
        _seconds(GameAudioController.musicBgmLayer),
        equals(_seconds(GameAudioController.musicBgm)),
      );
      expect(
        _seconds(GameAudioController.musicBgmNightLayer),
        equals(_seconds(GameAudioController.musicBgmNight)),
      );
    });

    test('each streak layer is its own sound, not a copy of its track', () {
      // A copied track would double the music it rides instead of layering it.
      expect(
        _sameFile(GameAudioController.musicBgmLayer, GameAudioController.musicBgm),
        isFalse,
      );
      expect(
        _sameFile(GameAudioController.musicBgmNightLayer, GameAudioController.musicBgmNight),
        isFalse,
      );
    });
  });

  group('Sounds with opposite meanings are different sounds', () {
    test('a near miss does not sound like taking a hit', () {
      // The near-miss cue was the same file as the fumble, so pulling off a
      // stunt sounded exactly like dropping a package.
      expect(
        _sameFile(GameAudioController.sfxBarkNearMiss, GameAudioController.sfxFumble),
        isFalse,
      );
      expect(
        _sameFile(GameAudioController.sfxBarkNearMiss, GameAudioController.sfxBarkDamage),
        isFalse,
      );
      // A cue, not a drone: well under a second.
      expect(_seconds(GameAudioController.sfxBarkNearMiss), lessThan(0.6));
    });

    test('thunder is its own sound and rolls for a while', () {
      for (final other in everySound) {
        if (other == GameAudioController.sfxThunder) continue;
        expect(_sameFile(GameAudioController.sfxThunder, other), isFalse, reason: other);
      }
      expect(_seconds(GameAudioController.sfxThunder), inInclusiveRange(1.5, 5.0));
    });
  });
}
