import 'package:arcade_os/database/database_helper.dart';
import 'package:arcade_os/models/game.dart';
import 'package:sqflite/sqflite.dart';

class GameService {
  static Future<List<Game>> loadGamesFromDirectory() async {
    return Game.getGamesFromDirectory('C:\\Users\\Omen\\Desktop\\games');
  }

  static Future<void> saveGamesToDatabase(List<Game> games) async {
    final db = await DatabaseHelper.instance.database;
    for (var game in games) {
      var existingGame = await db.query(
        'games',
        where: 'name = ?',
        whereArgs: [game.name],
      );

      if (existingGame.isEmpty) {
        final databaseGame = Game(
          id: game.id,
          name: game.name,
          playCount: game.playCount,
          dateAdded: game.dateAdded,
          executablePath: game.executablePath,
          coverImagePath: game.coverImagePath,
        );

        await db.insert(
          'games',
          databaseGame.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  static Future<List<Game>> loadGamesFromDB() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query('games');

    return List.generate(maps.length, (i) {
      return Game.fromMap(maps[i], "path_to_games");
    });
  }

  static Future<void> updatePlayData(String gameName) async {
    final db = await DatabaseHelper.instance.database;

    String currentTime = DateTime.now().toIso8601String();

    await db.rawUpdate(
      'UPDATE games SET playCount = playCount + 1, lastPlayed = ? WHERE name = ?',
      [currentTime, gameName],
    );
  }
}
