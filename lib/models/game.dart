import 'dart:io';
import 'package:arcade_os/database/database_helper.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class Game {
  int? id;
  String name;
  int playCount;
  String dateAdded;
  String? lastPlayed;
  String executablePath;
  String coverImagePath;

  Game({
    this.id,
    required this.name,
    this.playCount = 0,
    required this.dateAdded,
    this.lastPlayed,
    required this.executablePath,
    required this.coverImagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'playCount': playCount,
      'dateAdded': dateAdded,
      'lastPlayed': lastPlayed,
    };
  }

  static Game fromMap(Map<String, dynamic> map, String directoryPath) {
    String executablePath = join(directoryPath, map['name'] + '.exe');
    String coverImagePath = join(directoryPath, map['name'] + '.png');

    return Game(
      id: map['id'],
      name: map['name'],
      playCount: map['playCount'],
      dateAdded: map['dateAdded'],
      lastPlayed: map['lastPlayed'],
      executablePath: executablePath,
      coverImagePath: coverImagePath,
    );
  }

  static Future<List<Game>> getGamesFromDirectory(String directoryPath) async {
    List<Game> games = [];
    final directory = Directory(directoryPath);
    final gameFolders = directory.listSync().whereType<Directory>();

    for (var gameFolder in gameFolders) {
      String gameName = basename(gameFolder.path);
      String executablePath = join(gameFolder.path, '$gameName.exe');
      String coverImagePath = join(gameFolder.path, '$gameName.png');

      if (File(executablePath).existsSync() &&
          File(coverImagePath).existsSync()) {
        Game? gameFromDB = await _getGameDataFromDB(gameName);

        if (gameFromDB != null) {
          games.add(
            Game(
              name: gameName,
              executablePath: executablePath,
              coverImagePath: coverImagePath,
              playCount: gameFromDB.playCount,
              dateAdded: gameFromDB.dateAdded,
              lastPlayed: gameFromDB.lastPlayed,
            ),
          );
        } else {
          games.add(
            Game(
              name: gameName,
              executablePath: executablePath,
              coverImagePath: coverImagePath,
              playCount: 0,
              dateAdded: DateTime.now().toIso8601String(),
              lastPlayed: null,
            ),
          );
        }
      }
    }
    return games;
  }

  static Future<Game?> _getGameDataFromDB(String gameName) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'games',
      where: 'name = ?',
      whereArgs: [gameName],
    );

    if (result.isNotEmpty) {
      return Game.fromMap(result.first, '');
    }
    return null;
  }
}
