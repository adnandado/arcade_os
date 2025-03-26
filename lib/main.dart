import 'package:flutter/material.dart';
import 'package:arcade_os/pages/home_page.dart';

void main() {
  runApp(ArcadeOSApp());
}

class ArcadeOSApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arcade OS',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomePage(),
    );
  }
}
