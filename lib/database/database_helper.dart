import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/game.dart'; // Import Game

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('games.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''  
      CREATE TABLE games (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        playCount INTEGER DEFAULT 0,
        dateAdded TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertGame(Game game) async {
    final db = await database;
    return await db.insert('games', game.toMap());
  }

  Future<List<Game>> getAllGames() async {
    final db = await database;
    final result = await db.query('games');
    return result.map((map) => Game.fromMap(map, '')).toList();
  }

  Future<int> updateGame(Game game) async {
    final db = await database;
    return await db.update(
      'games',
      game.toMap(),
      where: 'id = ?',
      whereArgs: [game.id],
    );
  }

  Future<int> deleteGame(int id) async {
    final db = await database;
    return await db.delete('games', where: 'id = ?', whereArgs: [id]);
  }
}
