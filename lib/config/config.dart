import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';



class Config {
  static late String gamesDirectory;

  // Inicijalizacija konfiguracije
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Ako putanja nije pohranjena, koristi korisnički direktorij
    gamesDirectory = prefs.getString('games_directory') ?? await _getDefaultDirectory();
  }

  // Privatna funkcija koja vraća zadanu putanju na temelju platforme
  static Future<String> _getDefaultDirectory() async {
    if (Platform.isWindows) {
      // Dohvati korisnički direktorij i sastavi putanju do "games" direktorija
      String userProfile = Platform.environment['USERPROFILE'] ?? '';
      if (userProfile.isEmpty) {
        throw Exception("User profile is empty. Could not determine the user directory.");
      }
      return '$userProfile\\Desktop\\games';
    } else if (Platform.isMacOS || Platform.isLinux) {
      final directory = await getApplicationDocumentsDirectory();
      return '${directory.path}/games';  // Prilagodi putanju za macOS/Linux
    } else {
      return 'default_path_for_other_platforms';
    }
  }

  // Funkcija za spremanje korisničke putanje u SharedPreferences
  static Future<void> setGamesDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('games_directory', path);
  }
}
