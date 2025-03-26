import 'package:flutter/material.dart';
import 'package:arcade_os/services/game_service.dart';
import 'package:arcade_os/widgets/game_tile.dart';
import 'package:arcade_os/models/game_model.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    List<Game> games = GameService.loadGames();

    return Scaffold(
      appBar: AppBar(title: Text('Arcade OS')),
      body: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, // Prikaz igara u gridu sa 3 kolone
        ),
        itemCount: games.length,
        itemBuilder: (context, index) {
          return GameTile(game: games[index]);
        },
      ),
    );
  }
}
