import 'dart:convert';

import 'package:arcade_os/config/config.dart';
import 'package:flutter/material.dart';
import 'package:arcade_os/services/game_service.dart';
import 'package:arcade_os/models/game.dart';
import 'dart:io';
import 'package:arcade_os/widgets/game_tile.dart';
import 'package:watcher/watcher.dart';
import 'package:flutter/services.dart'; 

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Game> recentlyPlayed = [];
  List<Game> popularGames = [];
  List<Game> recentlyAdded = [];
  DirectoryWatcher? _watcher;

  int selectedRowIndex = 0;
  int selectedGameIndex = 0;
  FocusNode _focusNode = FocusNode();
  @override
  void initState() {
    super.initState();
    _loadGames();
    _startWatchingFolder();
  }

  Future<void> _loadGames() async {
    List<Game> games = await Game.getGamesFromDirectory(
      Config.gamesDirectory,
    );

    List<Game> gamesFromDB = await GameService.loadGamesFromDB();

    for (var game in games) {
      var dbGame = gamesFromDB.firstWhere(
        (dbGame) => dbGame.name == game.name,
        orElse: () => Game(
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

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (selectedRowIndex > 0) {
          setState(() {
            selectedRowIndex--;
            selectedGameIndex = 0; 
          });
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (selectedRowIndex < 2) {
          setState(() {
            selectedRowIndex++;
            selectedGameIndex = 0; 
          });
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (selectedGameIndex > 0) {
          setState(() {
            selectedGameIndex--;
          });
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (selectedGameIndex < _getGameListByRowIndex(selectedRowIndex).length - 1) {
          setState(() {
            selectedGameIndex++;
          });
        }
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        _startGame(_getGameListByRowIndex(selectedRowIndex)[selectedGameIndex]);
      }
    }
  }

  List<Game> _getGameListByRowIndex(int index) {
    switch (index) {
      case 0: return recentlyPlayed;
      case 1: return popularGames;
      case 2: return recentlyAdded;
      default: return [];
    }
  }

  void _startGame(Game game) {
    GameService.updatePlayData(game.name);
    String command = game.executablePath;
    Process.start('cmd', ['/c', 'start', '', command])
        .then((process) {
          process.stdout.transform(utf8.decoder).listen((data) {
            print('STDOUT: $data');
          });
          process.stderr.transform(utf8.decoder).listen((data) {
            print('STDERR: $data');
          });
          print('Game started: ${game.name}');
        })
        .catchError((error) {
          print('Error starting game: $error');
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Garaža OS"), backgroundColor: Colors.black87),
      body: RawKeyboardListener(
        focusNode: _focusNode,
        onKey: _handleKeyEvent,
        child: Container(
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
                _buildGameRow("Most Recently Played", recentlyPlayed, 0),
                _buildGameRow("Popular Games", popularGames, 1),
                _buildGameRow("Recently Added", recentlyAdded, 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameRow(String title, List<Game> games, int rowIndex) {
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
              bool isSelected = rowIndex == selectedRowIndex && index == selectedGameIndex;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: GameTile(
                  game: games[index],
                  onGamePlayed: () {
                    _loadGames();
                  },
                  isSelected: isSelected, 
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _startWatchingFolder() {
    final path = Config.gamesDirectory;
    _watcher = DirectoryWatcher(path);
    _watcher!.events.listen((event) {
      print('Detected change in folder: ${event.type} ${event.path}');
      _loadGames();
    });
  }
}
