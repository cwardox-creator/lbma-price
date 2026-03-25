import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  runApp(const LbmaApp());
}

class LbmaApp extends StatelessWidget {
  const LbmaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LBMA Gold Price',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: LFC.bg2,
        colorScheme: const ColorScheme.dark(
          primary: LFC.red,
          secondary: LFC.gold,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
