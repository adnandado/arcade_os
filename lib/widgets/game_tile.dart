import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:arcade_os/models/game.dart';
import 'package:arcade_os/services/game_service.dart';

class GameTile extends StatelessWidget {
  final Game game;
  final VoidCallback? onGamePlayed;
  final bool isSelected; // Dodano za označavanje selektovane igre

  const GameTile({
    super.key,
    required this.game,
    this.onGamePlayed,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400, // Set height
      width: 200, // Set width
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
          color:
              isSelected
                  ? const Color.fromARGB(255, 233, 183, 2)
                  : Colors.transparent,
          elevation: 0, // Oboji selektovanu igru
          margin: const EdgeInsets.all(8.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.file(
                  File(game.coverImagePath),
                  height: 300,
                  width: 200,
                  fit: BoxFit.cover,
                ),
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerLeft, // Align text to the left
                  child: Text(
                    game.name,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white, // Ensure text color is white
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
