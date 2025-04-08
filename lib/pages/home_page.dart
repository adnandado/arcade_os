import 'dart:convert';
import 'dart:io';

import 'package:arcade_os/config/config.dart';
import 'package:flutter/material.dart';
import 'package:arcade_os/services/game_service.dart';
import 'package:arcade_os/models/game.dart';
import 'package:arcade_os/widgets/game_tile.dart';
import 'package:watcher/watcher.dart';
import 'package:flutter/services.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  List<Game> recentlyPlayed = [];
  List<Game> popularGames = [];
  List<Game> recentlyAdded = [];
  DirectoryWatcher? _watcher;
  final ScrollController _verticalScrollController = ScrollController();
  final List<ScrollController> _horizontalScrollControllers = [
    ScrollController(),
    ScrollController(),
    ScrollController(),
  ];

  int selectedRowIndex = 0;
  int selectedGameIndex = 0;
  FocusNode _focusNode = FocusNode();
  late AnimationController _zoomController;
  late Animation<double> _zoomAnimation;
  late Animation<double> _moveAnimation;

  @override
  void initState() {
    super.initState();
    _loadGames();
    _startWatchingFolder();

    // Animation for zoom
    _zoomController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat(reverse: true);

    // Zoom animation from 1.0 to 3.0
    _zoomAnimation = Tween<double>(begin: 1.0, end: 3.0).animate(
      CurvedAnimation(parent: _zoomController, curve: Curves.easeInOut),
    );

    // Move animation for background (bottom to top)
    _moveAnimation = Tween<double>(begin: 1.0, end: -1.0).animate(
      CurvedAnimation(parent: _zoomController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _zoomController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadGames() async {
    List<Game> games = await Game.getGamesFromDirectory(Config.gamesDirectory);
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

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (selectedRowIndex > 0) {
          setState(() {
            selectedRowIndex--;
            selectedGameIndex = 0;
          });
          scrollToSelection();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (selectedRowIndex < 2) {
          setState(() {
            selectedRowIndex++;
            selectedGameIndex = 0;
          });
          scrollToSelection();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (selectedGameIndex > 0) {
          setState(() {
            selectedGameIndex--;
          });
          scrollToSelection();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (selectedGameIndex <
            _getGameListByRowIndex(selectedRowIndex).length - 1) {
          setState(() {
            selectedGameIndex++;
          });
          scrollToSelection();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        _startGame(_getGameListByRowIndex(selectedRowIndex)[selectedGameIndex]);
      }
    }
  }

  List<Game> _getGameListByRowIndex(int index) {
    switch (index) {
      case 0:
        return recentlyPlayed;
      case 1:
        return popularGames;
      case 2:
        return recentlyAdded;
      default:
        return [];
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

  void scrollToSelection() {
    final double rowHeight = 350 + 60;
    final double offsetY = selectedRowIndex * rowHeight;
    _verticalScrollController.animateTo(
      offsetY,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    final double tileWidth = 200 + 16;
    final double offsetX = selectedGameIndex * tileWidth;

    final controller = _horizontalScrollControllers[selectedRowIndex];
    controller.animateTo(
      offsetX,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RawKeyboardListener(
        focusNode: _focusNode,
        onKey: _handleKeyEvent,
        child: Stack(
          children: [
            // Pozadina
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _zoomController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/background.png'),
                        fit: BoxFit.cover,
                        scale: _zoomAnimation.value,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.4),
                          BlendMode.darken,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Sadržaj aplikacije
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: _verticalScrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGameRow(
                          "Most Recently Played",
                          recentlyPlayed,
                          0,
                        ),
                        _buildGameRow("Popular Games", popularGames, 1),
                        _buildGameRow("Recently Added", recentlyAdded, 2),
                      ],
                    ),
                  ),
                ),
                Container(
                  alignment: Alignment.bottomCenter,
                  width: double.infinity,
                  padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 25.0),
                        child: Text(
                          "v1.0.0",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Image.asset(
                        'assets/images/logo1.png', // Zamijeni sa svojim putem do slike
                        height: 45,
                        width: 45,
                      ),
                      const SizedBox(width: 15),
                      Padding(
                        padding: const EdgeInsets.only(right: 25.0),
                        child: StreamBuilder<DateTime>(
                          stream: Stream.periodic(
                            const Duration(seconds: 1),
                            (_) => DateTime.now(),
                          ),
                          builder: (context, snapshot) {
                            final currentTime = snapshot.data ?? DateTime.now();
                            final formattedTime =
                                "${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}:${currentTime.second.toString().padLeft(2, '0')}";
                            return Text(
                              formattedTime,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
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
          height: 370,
          child: ListView.builder(
            controller: _horizontalScrollControllers[rowIndex],
            scrollDirection: Axis.horizontal,
            itemCount: games.length,
            itemBuilder: (context, index) {
              bool isSelected =
                  rowIndex == selectedRowIndex && index == selectedGameIndex;
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
}
