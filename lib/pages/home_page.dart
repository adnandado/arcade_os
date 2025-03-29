import 'package:flutter/material.dart';
import 'package:arcade_os/services/game_service.dart';
import 'package:arcade_os/models/game.dart'; // Import Game model
import 'package:arcade_os/widgets/game_tile.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Game>>(
      future:
          GameService.loadGamesFromDirectory(), // Pozivaj funkciju koja učitava igre iz direktorija
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No games found.'));
        } else {
          List<Game> games = snapshot.data!;
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
            ),
            itemCount: games.length,
            itemBuilder: (context, index) {
              return GameTile(game: games[index]);
            },
          );
        }
      },
    );
  }
}
