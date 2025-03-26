import 'dart:io';
import 'package:path/path.dart';

class Game {
  final String name;
  final String executablePath;
  final String coverImagePath;

  Game({
    required this.name,
    required this.executablePath,
    required this.coverImagePath,
  });

  static List<Game> getGamesFromDirectory(String directoryPath) {
    List<Game> games = [];
    final directory = Directory(directoryPath);

    final gameFolders = directory.listSync().whereType<Directory>();
    for (var gameFolder in gameFolders) {
      print('Game folder: ${gameFolder.path}');

      String gameName = basename(gameFolder.path);
      print('Extracted game name: $gameName');

      String executablePath = join(gameFolder.path, '$gameName.exe');
      String coverImagePath = join(gameFolder.path, '${gameName}.png');

      print('Checking cover image path: $coverImagePath');

      if (!File(coverImagePath).existsSync()) {
        print('Cover image for game "$gameName" not found: $coverImagePath');
      } else {
        print('Cover image found for game "$gameName": $coverImagePath');
      }

      games.add(
        Game(
          name: gameName,
          executablePath: executablePath,
          coverImagePath: coverImagePath,
        ),
      );

      print('Ime igre: $gameName');
    }

    return games;
  }
}
