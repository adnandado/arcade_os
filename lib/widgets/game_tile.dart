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
      height: isSelected ? 450 : 400,
      width: isSelected ? 250 : 200,
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
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: isSelected ? 350 : 300,
                  width: isSelected ? 250 : 200,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color:
                          isSelected
                              ? const Color.fromARGB(255, 233, 183, 2)
                              : Colors.transparent,
                      width: isSelected ? 4 : 0,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isSelected ? 1.0 : 0.7,
                    child: Image.file(
                      File(game.coverImagePath),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
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
