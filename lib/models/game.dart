import 'dart:io';
import 'package:path/path.dart';

class Game {
  final int? id;
  final String name;
  final int playCount;
  final String dateAdded;
  final String executablePath;
  final String coverImagePath;

  // Konstruktor
  Game({
    this.id,
    required this.name,
    this.playCount = 0,
    required this.dateAdded,
    required this.executablePath,
    required this.coverImagePath,
  });

  // Funkcija za pretvaranje u mapu (za spremanje u bazu)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'playCount': playCount,
      'dateAdded': dateAdded,
    };
  }

  // Funkcija za učitavanje igre iz mape (npr. kada čitamo iz baze)
  static Game fromMap(Map<String, dynamic> map, String directoryPath) {
    String executablePath = join(directoryPath, map['name'] + '.exe');
    String coverImagePath = join(directoryPath, map['name'] + '.png');

    return Game(
      id: map['id'],
      name: map['name'],
      playCount: map['playCount'],
      dateAdded: map['dateAdded'],
      executablePath: executablePath,
      coverImagePath: coverImagePath,
    );
  }

  // Funkcija za učitavanje igara iz direktorija
  static List<Game> getGamesFromDirectory(String directoryPath) {
    List<Game> games = [];
    final directory = Directory(directoryPath);

    final gameFolders = directory.listSync().whereType<Directory>();
    for (var gameFolder in gameFolders) {
      String gameName = basename(gameFolder.path);
      String executablePath = join(gameFolder.path, '$gameName.exe');
      String coverImagePath = join(gameFolder.path, '$gameName.png');

      // Provjeri je li igra stvarno prisutna u folderu (ima li .exe i .png)
      if (File(executablePath).existsSync() &&
          File(coverImagePath).existsSync()) {
        games.add(
          Game(
            name: gameName,
            executablePath: executablePath,
            coverImagePath: coverImagePath,
            playCount: 0, // Početni broj odigranih puta
            dateAdded: DateTime.now().toIso8601String(),
          ),
        );
      }
    }
    return games;
  }
}
