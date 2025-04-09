import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class Config {
  static late String gamesDirectory;
  static late String fceuxPath;
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    gamesDirectory =
        prefs.getString('games_directory') ?? await _getDefaultDirectory();

    fceuxPath = prefs.getString('fceux_path') ?? await _getDefaultFceuxPath();
  }

  static Future<String> _getDefaultDirectory() async {
    if (Platform.isWindows) {
      String userProfile = Platform.environment['USERPROFILE'] ?? '';
      if (userProfile.isEmpty) {
        throw Exception(
          "User profile is empty. Could not determine the user directory.",
        );
      }
      return '$userProfile\\Desktop\\games';
    } else if (Platform.isMacOS || Platform.isLinux) {
      final directory = await getApplicationDocumentsDirectory();
      return '${directory.path}/games';
    } else {
      return 'default_path_for_other_platforms';
    }
  }

  static Future<String> _getDefaultFceuxPath() async {
    if (Platform.isWindows) {
      String userProfile = Platform.environment['USERPROFILE'] ?? '';
      if (userProfile.isEmpty) {
        throw Exception(
          "User profile is empty. Could not determine the user directory.",
        );
      }
      return '$userProfile\\Documents\\emulator\\fceux64.exe';
    } else {
      return 'default_path_for_other_platforms';
    }
  }

  static Future<void> setGamesDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('games_directory', path);
  }

  static Future<void> setFceuxPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fceux_path', path);
    fceuxPath = path;
  }
}
