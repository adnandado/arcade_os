import 'dart:convert';
import 'dart:io';
import 'package:arcade_os/widgets/game_text.dart';
import 'package:flutter/material.dart';
import 'package:arcade_os/models/game.dart';
import 'package:arcade_os/services/game_service.dart';

class GameTile extends StatelessWidget {
  final Game game;
  final VoidCallback? onGamePlayed;
  final bool isSelected;

  const GameTile({
    super.key,
    required this.game,
    this.onGamePlayed,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: isSelected ? 430 : 400,
      width: isSelected ? 250 : 225,
      child: GestureDetector(
        onTap: () async {
          onGamePlayed?.call();
          GameService.updatePlayData(game.name);
          String command = game.executablePath;
          Process.start('cmd', ['/c', 'start', '', command]).then((process) {
            process.stdout.transform(utf8.decoder).listen((data) {
              print('STDOUT: $data');
            });
            process.stderr.transform(utf8.decoder).listen((data) {
              print('STDERR: $data');
            });
          }).catchError((error) {
            print('Error starting game: $error');
          });
        },
        child: Card(
          color: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.all(8.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 300),
                  tween: Tween<double>(
                    begin: isSelected ? 300 : 275,
                    end: isSelected ? 350 : 325,
                  ),
                  builder: (context, double size, child) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      height: size,
                      width: size,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? const Color.fromARGB(186, 233, 183, 2)
                              : Colors.transparent,
                          width: isSelected ? 2 : 0,
                        ),
                        borderRadius: BorderRadius.circular(0),
                      ),
                      child: Stack(
                        children: [
                          Image.file(
                            File(game.coverImagePath),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                          if (isSelected)
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: -1.0, end: 2.0),
                              duration: const Duration(seconds: 2),
                              curve: Curves.easeInOut,
                              builder: (context, value, child) {
                                final double opacity = (value < 1.5)
                                    ? 1.0 - (value - 1.0).clamp(0.0, 0.5) * 2
                                    : 0.0;

                                return Opacity(
                                  opacity: opacity,
                                  child: ShaderMask(
                                    shaderCallback: (rect) {
                                      return LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white.withOpacity(0.3),
                                          Colors.transparent,
                                        ],
                                        stops: [value, value + 0.3],
                                      ).createShader(rect);
                                    },
                                    blendMode: BlendMode.srcATop,
                                    child: child,
                                  ),
                                );
                              },
                              child: Image.file(
                                File(game.coverImagePath),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 5),
                AnimatedOpacity(
                  opacity: isSelected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: isSelected
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: MarqueeText(
                            text: game.name,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            containerWidth: 200,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
