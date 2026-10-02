import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/courier_game.dart';

/// The orientations this app supports (landscape only).
const supportedOrientations = <DeviceOrientation>[
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

/// Locks the app to [supportedOrientations].
Future<void> lockOrientation() {
  return SystemChrome.setPreferredOrientations(supportedOrientations);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await lockOrientation();

  final game = CourierGame();
  runApp(
    MaterialApp(
      title: 'Courier Dash',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: GameWidget(game: game),
      ),
    ),
  );
}
