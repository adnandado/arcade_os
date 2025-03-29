import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:arcade_os/models/game.dart';
import 'package:arcade_os/services/game_service.dart';

class GameTile extends StatelessWidget {
  final Game game;

  const GameTile({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.file(
                File(game.coverImagePath),
                height: 150,
                fit: BoxFit.cover,
              ),
              const SizedBox(height: 8),
              Text(
                game.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  await GameService.updatePlayData(game.name);

                  String command = game.executablePath;

                  print('Running command: cmd /c start $command');

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
                },
                child: const Text('Play'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
