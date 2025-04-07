import 'package:flutter/material.dart';
import 'package:arcade_os/services/game_service.dart';
import 'package:arcade_os/models/game.dart';
import 'dart:io';
import 'package:arcade_os/widgets/game_tile.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

// TO DO
// Add live updating for sorting
// Game Pad Support
// UI Upgrade
// Make cover photos the play button

class _HomePageState extends State<HomePage> {
  List<Game> recentlyPlayed = [];
  List<Game> popularGames = [];
  List<Game> recentlyAdded = [];

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    List<Game> games = await Game.getGamesFromDirectory(
      'C:\\Users\\Omen\\Desktop\\games',
    );

    List<Game> gamesFromDB = await GameService.loadGamesFromDB();

    for (var game in games) {
      var dbGame = gamesFromDB.firstWhere(
        (dbGame) => dbGame.name == game.name,
        orElse:
            () => Game(
              name: game.name,
              executablePath: game.executablePath,
              coverImagePath: game.coverImagePath,
              playCount: 0,
              dateAdded: DateTime.now().toIso8601String(),
              lastPlayed: null,
            ),
      );

      if (dbGame != null) {
        setState(() {
          game.playCount = dbGame.playCount;
          game.dateAdded = dbGame.dateAdded;
          game.lastPlayed = dbGame.lastPlayed;
        });
      }
    }

    setState(() {
      recentlyPlayed = List.from(games)
        ..sort((a, b) => (b.lastPlayed ?? "").compareTo(a.lastPlayed ?? ""));

      popularGames = List.from(games)
        ..sort((a, b) => (b.playCount).compareTo(a.playCount));

      recentlyAdded = List.from(games)
        ..sort((a, b) => (b.dateAdded).compareTo(a.dateAdded));
    });
  }

  Widget _buildGameRow(String title, List<Game> games) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        Container(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: games.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: GameTile(game: games[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Garaža OS"), backgroundColor: Colors.black87),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.4),
              BlendMode.darken,
            ),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGameRow("Most Recently Played", recentlyPlayed),
              _buildGameRow("Popular Games", popularGames),
              _buildGameRow("Recently Added", recentlyAdded),
            ],
          ),
        ),
      ),
    );
  }
}
