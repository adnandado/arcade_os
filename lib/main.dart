import 'package:arcade_os/models/game.dart';
import 'package:arcade_os/services/game_service.dart';
import 'package:flutter/material.dart';
import 'package:arcade_os/pages/home_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  databaseFactory = databaseFactoryFfi;

  List<Game> gamesFromDirectory = await GameService.loadGamesFromDirectory();

  await GameService.saveGamesToDatabase(gamesFromDirectory);

  runApp(ArcadeOSApp());
}

class ArcadeOSApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arcade OS',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomePage(),
    );
  }
}
