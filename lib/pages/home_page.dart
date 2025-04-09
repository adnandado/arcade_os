import 'dart:convert';
import 'dart:io';

import 'package:arcade_os/config/config.dart';
import 'package:flutter/material.dart';
import 'package:arcade_os/services/game_service.dart';
import 'package:arcade_os/models/game.dart';
import 'package:arcade_os/widgets/game_tile.dart';
import 'package:watcher/watcher.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

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

  final List<AudioPlayer> _switchSoundPlayers = [];
  final AudioPlayer _perfectSoundPlayer = AudioPlayer();
  int _currentSwitchPlayerIndex = 0;

  int selectedRowIndex = 0;
  int selectedGameIndex = 0;
  FocusNode _focusNode = FocusNode();
  late AnimationController _zoomController;
  late Animation<double> _zoomAnimation;

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < 3; i++) {
      _switchSoundPlayers.add(AudioPlayer());
    }

    _loadGames();
    _startWatchingFolder();

    _zoomController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    )..repeat(reverse: true);

    _zoomAnimation = Tween<double>(begin: 1.0, end: 3.0).animate(
      CurvedAnimation(parent: _zoomController, curve: Curves.bounceInOut),
    );
  }

  @override
  void dispose() {
    for (var player in _switchSoundPlayers) {
      player.dispose();
    }
    _perfectSoundPlayer.dispose();
    _zoomController.dispose();
    _focusNode.dispose();
    _verticalScrollController.dispose();
    for (var controller in _horizontalScrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _playSwitchSound() async {
    try {
      final player = _switchSoundPlayers[_currentSwitchPlayerIndex];
      await player.stop();
      await player.play(AssetSource('sounds/switch.mp3'));
      _currentSwitchPlayerIndex =
          (_currentSwitchPlayerIndex + 1) % _switchSoundPlayers.length;
    } catch (e) {
      debugPrint('Error playing switch sound: $e');
    }
  }

  Future<void> _playRowSound() async {
    try {
      final player = _switchSoundPlayers[_currentSwitchPlayerIndex];
      await player.stop();
      await player.play(AssetSource('sounds/row-switch.mp3'));
      _currentSwitchPlayerIndex =
          (_currentSwitchPlayerIndex + 1) % _switchSoundPlayers.length;
    } catch (e) {
      debugPrint('Error playing switch sound: $e');
    }
  }

  Future<void> _playPerfectSound() async {
    try {
      await _perfectSoundPlayer.stop();
      await _perfectSoundPlayer.play(AssetSource('sounds/row-switch.mp3'));
    } catch (e) {
      debugPrint('Error playing perfect sound: $e');
    }
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

      setState(() {
        game.playCount = dbGame.playCount;
        game.dateAdded = dbGame.dateAdded;
        game.lastPlayed = dbGame.lastPlayed;
      });
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
        _playRowSound();
        if (selectedRowIndex > 0) {
          setState(() {
            selectedRowIndex--;
            selectedGameIndex = 0;
          });
          scrollToSelection();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (selectedRowIndex < 2) {
          _playRowSound();

          setState(() {
            selectedRowIndex++;
            selectedGameIndex = 0;
          });
          scrollToSelection();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _playSwitchSound();
        if (selectedGameIndex > 0) {
          setState(() {
            selectedGameIndex--;
          });
          scrollToSelection();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _playSwitchSound();
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

  Future<void> _startGame(Game game) async {
    await _playPerfectSound();

    GameService.updatePlayData(game.name);
    String command = game.executablePath;

    try {
      if (command.endsWith('.nes')) {
        await Process.start('cmd', [
          '/c',
          'start',
          '',
          Config.fceuxPath,
          command,
        ]);
      } else {
        await Process.start('cmd', ['/c', 'start', '', command]);
      }

      print('Game started: ${game.name}');
    } catch (error) {
      print('Error starting game: $error');
    }
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
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 20.0,
                ), // Padding added
                child: Column(
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Image.asset(
                            'assets/images/logo1.png',
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
                                final currentTime =
                                    snapshot.data ?? DateTime.now();
                                final formattedTime =
                                    "${currentTime.hour.toString().padLeft(2, '0')}:" +
                                    "${currentTime.minute.toString().padLeft(2, '0')}:" +
                                    "${currentTime.second.toString().padLeft(2, '0')}";
                                return Text(
                                  formattedTime,
                                  style: const TextStyle(
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
              ),
            );
          },
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
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        Container(
          height: 400,
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
                  onGamePlayed: _loadGames,
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
