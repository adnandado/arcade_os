import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:arcade_os/config/config.dart';
import 'package:arcade_os/models/game.dart';
import 'package:arcade_os/services/game_service.dart';
import 'package:arcade_os/widgets/game_tile.dart';
import 'package:arcade_os/widgets/info-section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:watcher/watcher.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  List<Game> recentlyPlayed = [];
  List<Game> popularGames = [];
  List<Game> recentlyAdded = [];
  List<Game> alphabeticallySortedGames = [];
  List<Game> allGames = [];
  List<String> hiddenGameNames = [];

  DirectoryWatcher? _watcher;
  final ScrollController _verticalScrollController = ScrollController();
  final List<ScrollController> _horizontalScrollControllers = [
    ScrollController(),
    ScrollController(),
    ScrollController(),
    ScrollController(),
    ScrollController(),
  ];

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
    'assets/images/bg8.png',
    'assets/images/bg9.png',
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
  bool _isFiltering = false;
  bool _areGamesHidden = false;

  // Space hold variables
  Timer? _spaceHoldTimer;
  bool _isSpaceHeld = false;
  Duration _spaceHoldDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _backgroundZoomController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 20),
    )..repeat(reverse: true);

    _backgroundZoomAnimation = Tween<double>(begin: 1.1, end: 1.0).animate(
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
    _spaceHoldTimer?.cancel();
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

      game.playCount = dbGame.playCount;
      game.dateAdded = dbGame.dateAdded;
      game.lastPlayed = dbGame.lastPlayed;
    }

    setState(() {
      allGames = games;
      recentlyPlayed = List.from(games)
        ..sort((a, b) => (b.lastPlayed ?? "").compareTo(a.lastPlayed ?? ""));
      popularGames = List.from(games)
        ..sort((a, b) => (b.playCount).compareTo(a.playCount));
      recentlyAdded = List.from(games)
        ..sort((a, b) => (b.dateAdded).compareTo(a.dateAdded));
      alphabeticallySortedGames = List.from(games)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    });
    filterGames();
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (_isLoading) return;

    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.space) {
      print("Space key pressed");
      if (!_isSpaceHeld) {
        _isSpaceHeld = true;
        _spaceHoldTimer = Timer(_spaceHoldDuration, () async {
          if (_isSpaceHeld) {
            _areGamesHidden = !_areGamesHidden;

            if (_areGamesHidden) {
              List<String> gamesWithTxt = await Game.getGamesWithTxtFiles(
                Config.gamesDirectory,
              );
              setState(() {
                hiddenGameNames = gamesWithTxt;
                filterGames();
              });
            } else {
              setState(() {
                hiddenGameNames = [];
                filterGames();
              });
            }

            await _playSwitchSound();
          }
        });
      }
    } else if (event is RawKeyUpEvent &&
        event.logicalKey == LogicalKeyboardKey.space) {
      print("Space key released");
      _isSpaceHeld = false;
      _spaceHoldTimer?.cancel();
      _spaceHoldTimer = null;
    }

    // Handle navigation keys
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
        if (selectedRowIndex < 4) {
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
        if (selectedGameIndex < _getMaxIndexForRow(selectedRowIndex)) {
          setState(() {
            selectedGameIndex++;
          });
          scrollToSelection();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (selectedRowIndex < 4) {
          _startGame(
            _getGameListByRowIndex(selectedRowIndex)[selectedGameIndex],
          );
        } else if (selectedRowIndex == 4) {
          if (selectedGameIndex == 0) {
            _showInfoDialog(
              context,
              'About Garaža Makerspace',
              'Ovo su detaljne informacije za Info 1.',
              'assets/images/info1.png',
              '''
Ovdje se može opisati detaljno što sve igra sadrži.
Više informacija, specifične mehanike i drugo.
Ovaj tekst je dug i bit će prikazan u scrollable dijalogu.
''',
            );
          } else if (selectedGameIndex == 1) {
            _showInfoDialog(
              context,
              'About Garaža Makerspace',
              'Ovo su detaljne informacije za Info 1.',
              'assets/images/laptop.png',
              '''
Makerspace Garage is a non-profit, non-governmental innovation organization with a community of makers passionate about positive social and environmental impact. Garaža is a community-based space where creative entrepreneurs, artists, makers, teachers, and students come together to learn and work. 
We want to help students, children & young people, creative souls, entrepreneurs, and everyone else, to get their start and realize their ideas.​

Our mission at Garage is to provide students, industry, SMEs/entrepreneurs, artists, and makers with a safe, well-equipped, and knowledgeable environment in which they can explore how traditional, contemporary, and modern processes of making can support new designs or advanced existing, with imagination, creativity, and ingenuity.
​
No matter what your background is, what your resources are, or whatever your maker journey is, Garage Makerspace is here to help. At Garage Makerspace, you can
- Learn and create through hands-on skills and personalized experiences through workshops and other events we organize
- Use the makerspace, our resources, and our expertise to come up with innovative solutions
- Be part of our community of makers and together bring a positive impact to the society
- Build critical thinking and problem-solving skills
- Develop a wide range of 21st-century skills
''',
            );
          } else if (selectedGameIndex == 2) {
            _showInfoDialog(
              context,
              'About Arcade OS',
              'Ovo su detaljne informacije za Info 1.',
              'assets/images/info1.png',
              '''
Ovdje se može opisati detaljno što sve igra sadrži.
Više informacija, specifične mehanike i drugo.
Ovaj tekst je dug i bit će prikazan u scrollable dijalogu.
''',
            );
          }
        }
      }
    }
  }

  void filterGames() {
    if (_isFiltering) return;
    _isFiltering = true;

    setState(() {
      recentlyPlayed =
          allGames.where((g) => !hiddenGameNames.contains(g.name)).toList()
            ..sort(
              (a, b) => (b.lastPlayed ?? "").compareTo(a.lastPlayed ?? ""),
            );

      popularGames =
          allGames.where((g) => !hiddenGameNames.contains(g.name)).toList()
            ..sort((a, b) => b.playCount.compareTo(a.playCount));

      recentlyAdded =
          allGames.where((g) => !hiddenGameNames.contains(g.name)).toList()
            ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));

      alphabeticallySortedGames =
          allGames.where((g) => !hiddenGameNames.contains(g.name)).toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
    });

    _isFiltering = false;
  }

  int _getMaxIndexForRow(int rowIndex) {
    if (rowIndex < 4) {
      return _getGameListByRowIndex(rowIndex).length - 1;
    } else {
      return 2;
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
      case 3:
        return alphabeticallySortedGames;
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
      } else if (command.endsWith('.bin')) {
        String duckStationPath = Config.duckStationPath;
        await Process.start('cmd', [
          '/c',
          'start',
          '',
          duckStationPath,
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
    if (!_verticalScrollController.hasClients || !mounted) return;

    final double rowHeight = 350 + 60;
    final double infoSectionHeight = 375;
    final double footerHeight = 60;

    double offsetY;
    if (selectedRowIndex < 4) {
      offsetY = selectedRowIndex * rowHeight;
    } else {
      final availableHeight = MediaQuery.of(context).size.height;
      offsetY =
          (selectedRowIndex * rowHeight) -
          (availableHeight - infoSectionHeight - footerHeight - 16 - 40);

      offsetY = offsetY.clamp(
        0.0,
        _verticalScrollController.position.maxScrollExtent,
      );
    }

    if (_verticalScrollController.position.maxScrollExtent >= offsetY) {
      _verticalScrollController.animateTo(
        offsetY,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    final controllerIndex = selectedRowIndex < 4 ? selectedRowIndex : 4;
    final controller = _horizontalScrollControllers[controllerIndex];

    if (controller.hasClients && mounted) {
      final double itemWidth = selectedRowIndex < 4 ? 200 + 16 : 300 + 16;
      final double offsetX = min(
        selectedGameIndex * itemWidth,
        controller.position.maxScrollExtent,
      );

      if (controller.position.maxScrollExtent >= offsetX) {
        controller.animateTo(
          offsetX,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
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

  Widget _buildInfoSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth * 0.50).clamp(300.0, 650.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "Garaža Makerspace",
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
          height: 250,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              InfoSection(
                imagePath: 'assets/images/info1.png',
                title: 'Arcade OS',
                content: 'Ovo su detaljne informacije za Info 1.',
                detailedText: '''
Ovdje se može opisati detaljno što sve igra sadrži.
Više informacija, specifične mehanike i drugo.
Ovaj tekst je dug i bit će prikazan u scrollable dijalogu.
''',
                width: itemWidth,
                isSelected: selectedRowIndex == 4 && selectedGameIndex == 0,
                onTap: () {
                  _showInfoDialog(
                    context,
                    'About Ar',
                    'Ovo su detaljne informacije za Info 1.',
                    'assets/images/info1.png',
                    '''
Ovdje se može opisati detaljno što sve igra sadrži.
Više informacija, specifične mehanike i drugo.
Ovaj tekst je dug i bit će prikazan u scrollable dijalogu.
''',
                  );
                },
              ),
              InfoSection(
                imagePath: 'assets/images/info2.png',
                title: 'Garaža Makerspace',
                content: 'Ovo su detaljne informacije za Info 1.',
                detailedText: '''
Ovdje se može opisati detaljno što sve igra sadrži.
Više informacija, specifične mehanike i drugo.
Ovaj tekst je dug i bit će prikazan u scrollable dijalogu.
''',
                width: itemWidth,
                isSelected: selectedRowIndex == 4 && selectedGameIndex == 1,
                onTap: () {
                  _showInfoDialog(
                    context,
                    'Info 1',
                    'Ovo su detaljne informacije za Info 1.',
                    'assets/images/info1.png',
                    '''
Ovdje se može opisati detaljno što sve igra sadrži.
Više informacija, specifične mehanike i drugo.
Ovaj tekst je dug i bit će prikazan u scrollable dijalogu.
''',
                  );
                },
              ),
              InfoSection(
                imagePath: 'assets/images/info1.png',
                title: 'About Arcade OS',
                content: 'Ovo su detaljne informacije za Info 1.',
                detailedText: '''
Ovdje se može opisati detaljno što sve igra sadrži.
Više informacija, specifične mehanike i drugo.
Ovaj tekst je dug i bit će prikazan u scrollable dijalogu.
''',
                width: itemWidth,
                isSelected: selectedRowIndex == 4 && selectedGameIndex == 2,
                onTap: () {
                  _showInfoDialog(
                    context,
                    'Info 1',
                    'Ovo su detaljne informacije za Info 1.',
                    'assets/images/info1.png',
                    '''
Ovdje se može opisati detaljno što sve igra sadrži.
Više informacija, specifične mehanike i drugo.
Ovaj tekst je dug i bit će prikazan u scrollable dijalogu.
''',
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showInfoDialog(
    BuildContext context,
    String title,
    String content,
    String imagePath,
    String detailedText,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        final focusNode = FocusNode();
        final focusScopeNode = FocusScopeNode();
        final scrollController = ScrollController();

        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          child: FocusScope(
            node: focusScopeNode,
            child: RawKeyboardListener(
              autofocus: true,
              focusNode: focusNode,
              onKey: (RawKeyEvent event) {
                if (event is RawKeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.enter) {
                    Navigator.of(context).pop();
                  } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    scrollController.animateTo(
                      scrollController.offset + 50,
                      duration: Duration(milliseconds: 150),
                      curve: Curves.easeInOut,
                    );
                  } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    scrollController.animateTo(
                      scrollController.offset - 50,
                      duration: Duration(milliseconds: 150),
                      curve: Curves.easeInOut,
                    );
                  }
                }
              },
              child: Container(
                width: 900,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color.fromARGB(255, 220, 183, 0),
                    width: 3.0,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.3,
                        child: Image.asset(imagePath, fit: BoxFit.cover),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12.0,
                              horizontal: 16,
                            ),
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: const Color.fromARGB(255, 220, 183, 0),
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.8),
                                    blurRadius: 4,
                                    offset: Offset(2, 2),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: Scrollbar(
                                thumbVisibility: true,
                                controller: scrollController,
                                child: SingleChildScrollView(
                                  controller: scrollController,
                                  physics: BouncingScrollPhysics(),
                                  child: Text(
                                    detailedText,
                                    style: TextStyle(
                                      color: Color.fromARGB(222, 255, 255, 255),
                                      fontSize: 20,
                                      height: 1.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.justify,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
                        alignment: Alignment.center,
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
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
                                _buildGameRow(
                                  "A-Z",
                                  alphabeticallySortedGames,
                                  3,
                                ),
                                _buildInfoSection(),
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
                                padding: const EdgeInsets.only(left: 50.0),
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
          if (hiddenGameNames.isNotEmpty)
            Positioned(
              bottom: 20,
              right: 20,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "Hidden: ${hiddenGameNames.length} games",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
