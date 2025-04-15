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

  static Future<List<String>> getGamesWithTxtFiles(String directoryPath) async {
    List<String> gamesWithTxt = [];

    final directory = Directory(directoryPath);
    final gameFolders = directory.listSync().whereType<Directory>();

    for (var folder in gameFolders) {
      final files = folder.listSync().whereType<File>();
      final hasTxt = files.any(
        (file) => file.path.toLowerCase().endsWith('.txt'),
      );

      if (hasTxt) {
        gamesWithTxt.add(basename(folder.path));
      }
    }

    return gamesWithTxt;
  }

  static Future<List<Game>> getGamesFromDirectory(String directoryPath) async {
    List<Game> games = [];
    final directory = Directory(directoryPath);
    final gameFolders = directory.listSync().whereType<Directory>();

    for (var gameFolder in gameFolders) {
      String gameName = basename(gameFolder.path);
      final files = gameFolder.listSync().whereType<File>().toList();

      String? executablePath;
      String? coverImagePath;
      bool isNesGame = false;

      for (var file in files) {
        String path = file.path.toLowerCase();
        if (path.endsWith('.txt')) {
          continue;
        }
        if (path.endsWith('.png') && coverImagePath == null) {
          coverImagePath = file.path;
        } else if (path.endsWith('.nes')) {
          isNesGame = true;
          if (executablePath == null) {
            executablePath = file.path;
          }
        } else if (!path.endsWith('.png') &&
            !path.endsWith('.nes') &&
            executablePath == null) {
          executablePath = file.path;
        }
      }

      if (executablePath != null && coverImagePath != null) {
        Game? gameFromDB = await _getGameDataFromDB(gameName);

        games.add(
          Game(
            name: gameName,
            executablePath: executablePath,
            coverImagePath: coverImagePath,
            playCount: gameFromDB?.playCount ?? 0,
            dateAdded:
                gameFromDB?.dateAdded ?? DateTime.now().toIso8601String(),
            lastPlayed: gameFromDB?.lastPlayed,
          ),
        );
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
