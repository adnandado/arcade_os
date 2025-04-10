import 'dart:async';
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
  //FIX SWITCH BETWEEN COVERS
  final List<AudioPlayer> _switchSoundPlayers = [];
  final AudioPlayer _perfectSoundPlayer = AudioPlayer();
  final List<String> _backgroundImages = [
    'assets/images/bg1.jpg',
    'assets/images/bg2.jpg',
    'assets/images/bg3.jpg',
    'assets/images/bg4.jpg',
    'assets/images/bg5.jpg',
    'assets/images/bg6.jpg',
    'assets/images/bg7.jpg',
  ];
  int _currentSwitchPlayerIndex = 0;
  String currentBackgroundImage = 'assets/images/bg1.jpg';
  String nextBackgroundImage = 'assets/images/bg2.png';

  int selectedRowIndex = 0;
  int selectedGameIndex = 0;
  int _backgroundIndex = 0;
  late Timer _backgroundTimer;
  FocusNode _focusNode = FocusNode();
  late AnimationController _zoomController;
  late Animation<double> _zoomAnimation;
  bool _isLoading = false;
  Game? _selectedGame;
  late AnimationController _loadingController;
  late Animation<double> _loadingAnimation;
  late AnimationController _bgSlideController;
  late Animation<double> _bgSlideAnimation;
  late AnimationController _bgFadeController;
  late Animation<double> _bgFadeAnimation;
  late AnimationController _backgroundZoomController;
  late Animation<double> _backgroundZoomAnimation;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _backgroundZoomController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 100),
    );

    _backgroundZoomAnimation = Tween<double>(begin: 1, end: 1.50).animate(
      CurvedAnimation(
        parent: _backgroundZoomController,
        curve: Curves.easeInOut,
      ),
    );
    _bgSlideController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    );

    _bgFadeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 100),
    );

    _bgSlideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _bgSlideController, curve: Curves.ease));

    _bgFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _bgFadeController, curve: Curves.easeIn));

    _startBackgroundChange();

    for (int i = 0; i < 3; i++) {
      _switchSoundPlayers.add(AudioPlayer());
    }

    _loadingController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3),
    )..repeat();

    _loadingAnimation = CurvedAnimation(
      parent: _loadingController,
      curve: Curves.linear,
    );

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
    _backgroundTimer.cancel();
    _bgSlideController.dispose();
    _bgFadeController.dispose();
    _backgroundZoomController.dispose();

    for (var player in _switchSoundPlayers) {
      player.dispose();
    }
    _perfectSoundPlayer.dispose();
    _zoomController.dispose();
    _loadingController.dispose();
    _focusNode.dispose();
    _verticalScrollController.dispose();
    for (var controller in _horizontalScrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _changeBackground(Timer timer) {
    if (!mounted) return;

    setState(() {
      _backgroundIndex = (_backgroundIndex + 1) % _backgroundImages.length;
      nextBackgroundImage = _backgroundImages[_backgroundIndex];
    });

    _bgSlideController.reset();
    _bgFadeController.reset();
    _bgSlideController.forward();
    _bgFadeController.forward();

    _backgroundZoomController.reset();
    _backgroundZoomController.forward();

    Future.delayed(Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          currentBackgroundImage = nextBackgroundImage;
        });
      }
    });
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
      await _perfectSoundPlayer.play(AssetSource('sounds/perfect.mp3'));
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
    if (_isLoading) return;
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
    setState(() {
      _isLoading = true;
      _selectedGame = game;
    });

    await _playPerfectSound();
    GameService.updatePlayData(game.name);

    await Future.delayed(Duration(seconds: 2));

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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _selectedGame = null;
        });
      }
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

  void _startBackgroundChange() {
    _backgroundTimer = Timer.periodic(Duration(seconds: 120), (timer) {
      _changeBackground(timer);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([
              _bgSlideController,
              _backgroundZoomController,
            ]),
            builder: (context, child) {
              return Stack(
                children: [
                  AnimatedBuilder(
                    animation: _backgroundZoomController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _backgroundZoomAnimation.value,
                        child: Container(
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage(currentBackgroundImage),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Next background sliding in
                  Positioned.fill(
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(1.0, 0.0),
                        end: Offset.zero,
                      ).animate(_bgSlideController),
                      child: FadeTransition(
                        opacity: _bgFadeAnimation,
                        child: Transform.scale(
                          scale: _backgroundZoomAnimation.value,
                          child: Container(
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage(nextBackgroundImage),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  Container(color: Colors.black.withOpacity(0.4)),
                ],
              );
            },
          ),

          RawKeyboardListener(
            focusNode: _focusNode,
            onKey: _handleKeyEvent,
            child: AnimatedBuilder(
              animation: _zoomController,
              builder: (context, child) {
                return Container(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 0.0,
                    ),
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
                                _buildGameRow(
                                  "Recently Added",
                                  recentlyAdded,
                                  2,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          alignment: Alignment.bottomCenter,
                          width: double.infinity,
                          padding: const EdgeInsets.only(
                            right: 8.0,
                            bottom: 8.0,
                          ),
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
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.8),
                                        blurRadius: 2,
                                        offset: Offset(1, 1),
                                      ),
                                    ],
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
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withOpacity(
                                              0.8,
                                            ),
                                            blurRadius: 2,
                                            offset: Offset(1, 1),
                                          ),
                                        ],
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

          if (_isLoading && _selectedGame != null)
            _buildLoadingOverlay(context),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                image: DecorationImage(
                  image:
                      _selectedGame!.coverImagePath.isNotEmpty
                          ? FileImage(File(_selectedGame!.coverImagePath))
                          : AssetImage('assets/images/background.png')
                              as ImageProvider,
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    spreadRadius: 5,
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
            ),
            SizedBox(height: 30),
            Text(
              '${_selectedGame!.name}...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.8),
                    blurRadius: 2,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            RotationTransition(
              turns: _loadingAnimation,
              child: Container(
                width: 25,
                height: 25,
                child: CircularProgressIndicator(
                  strokeWidth: 5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    const Color.fromARGB(255, 250, 252, 253),
                  ),
                ),
              ),
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
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(209, 255, 255, 255),
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.8),
                  blurRadius: 2,
                  offset: Offset(1, 1),
                ),
              ],
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
