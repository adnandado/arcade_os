import 'dart:convert';
import 'dart:io';
import 'package:arcade_os/widgets/game_text.dart';
import 'package:flutter/material.dart';
import 'package:arcade_os/models/game.dart';
import 'package:arcade_os/services/game_service.dart';

class GameTile extends StatelessWidget {
  final Game game;
  final VoidCallback? onGamePlayed;
  final bool isSelected; // For indicating whether the game is selected

  const GameTile({
    super.key,
    required this.game,
    this.onGamePlayed,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: isSelected ? 450 : 400, // Adjust height based on selection
      width: isSelected ? 250 : 200, // Adjust width based on selection
      child: GestureDetector(
        onTap: () async {
          onGamePlayed?.call();
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
              })
              .catchError((error) {
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
                // AnimatedContainer to resize both the image and the card when selected
                AnimatedContainer(
                  duration: const Duration(
                    milliseconds: 300,
                  ), // Duration of resize animation
                  curve: Curves.easeInOut, // Smooth curve for resizing
                  height: isSelected ? 350 : 300, // Larger when selected
                  width: isSelected ? 250 : 200, // Larger when selected
                  decoration: BoxDecoration(
                    border: Border.all(
                      color:
                          isSelected
                              ? const Color.fromARGB(
                                255,
                                233,
                                183,
                                2,
                              ) // Yellow color for border
                              : Colors
                                  .transparent, // No border when not selected
                      width: isSelected ? 4 : 0, // Border width when selected
                    ),
                    borderRadius: BorderRadius.circular(
                      8,
                    ), // Optional: round corners for the border
                  ),
                  child: AnimatedOpacity(
                    duration: const Duration(
                      milliseconds: 200,
                    ), // Duration of opacity transition
                    opacity:
                        isSelected ? 1.0 : 0.7, // Fade effect when selected
                    child: Image.file(
                      File(game.coverImagePath),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                // Marquee text when selected
                AnimatedOpacity(
                  opacity: isSelected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child:
                      isSelected
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
