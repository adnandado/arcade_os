import 'package:arcade_os/config/config.dart';
import 'package:arcade_os/models/game.dart';
import 'package:arcade_os/services/game_service.dart';
import 'package:flutter/material.dart';
import 'package:arcade_os/pages/home_page.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  await Config.initialize();
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  databaseFactory = databaseFactoryFfi;
  List<Game> gamesFromDirectory = await GameService.loadGamesFromDirectory();
  //await windowManager.setFullScreen(true);
  await GameService.saveGamesToDatabase(gamesFromDirectory);
  runApp(ArcadeOSApp());
  setAppFullscreen();
}

void setAppFullscreen() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
}

class ArcadeOSApp extends StatelessWidget {
  const ArcadeOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arcade OS',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomePage(),
    );
  }
}
