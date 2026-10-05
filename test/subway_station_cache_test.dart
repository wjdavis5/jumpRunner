import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/subway_station_component.dart';

Future<Uint8List> _pixels(void Function(ui.Canvas canvas) draw) async {
  final recorder = ui.PictureRecorder();
  draw(ui.Canvas(recorder));
  final image = await recorder.endRecording().toImage(1000, 260);
  final data = (await image.toByteData())!;
  image.dispose();
  return data.buffer.asUint8List();
}

void _renderFrame(SubwayStationComponent station) {
  final recorder = ui.PictureRecorder();
  station.render(ui.Canvas(recorder));
  recorder.endRecording().dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('The subway station is drawn from a recording', () {
    test('it is painted once per look, not once per frame', () {
      final station = SubwayStationComponent(position: Vector2.zero());
      // Ten seconds of frames: the tube lights toggle fourteen times.
      for (var i = 0; i < 600; i++) {
        station.update(1 / 60);
        _renderFrame(station);
      }
      // Lights steady and lights flickering: two paintings in all.
      expect(station.paintCount, equals(2));
    });

    test('the recording looks exactly like a fresh painting', () async {
      final station = SubwayStationComponent(position: Vector2.zero());
      for (final flicker in const [false, true]) {
        while (station.lightsFlicker != flicker) {
          station.update(0.1);
        }
        final recorded = await _pixels(station.render);
        final fresh = await _pixels(station.paintStation);
        expect(recorded, equals(fresh), reason: 'lights flicker: $flicker');
      }
    });

    test('the two looks differ, so the flicker still shows', () async {
      final station = SubwayStationComponent(position: Vector2.zero());
      final steady = await _pixels(station.render);
      while (!station.lightsFlicker) {
        station.update(0.1);
      }
      final flickering = await _pixels(station.render);
      expect(flickering, isNot(equals(steady)));
    });

    test('a resized station is painted again', () {
      final station = SubwayStationComponent(position: Vector2.zero());
      _renderFrame(station);
      expect(station.paintCount, equals(1));
      station.size = Vector2(1200.0, 260.0);
      _renderFrame(station);
      _renderFrame(station);
      expect(station.paintCount, equals(2));
    });

    test('a station taken off the street and put back still draws', () {
      final station = SubwayStationComponent(position: Vector2.zero());
      _renderFrame(station);
      station.onRemove();
      expect(() => _renderFrame(station), returnsNormally);
      expect(station.paintCount, equals(2));
    });
  });
}
