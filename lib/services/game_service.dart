import 'dart:io';
import 'package:arcade_os/models/game_model.dart';

class GameService {
  static List<Game> loadGames() {
    return Game.getGamesFromDirectory('C:\\Users\\Omen\\arcade_os\\games');
  }
}
