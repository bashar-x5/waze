import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_controller.dart';
import '../ui/home_screen.dart';

class DarbApp extends StatelessWidget {
  const DarbApp({super.key, required this.controller, this.renderMapTiles = true});
  final AppController controller;
  final bool renderMapTiles;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Darb | درب',
      locale: Locale(controller.arabic ? 'ar' : 'en'),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      themeMode: controller.dark ? ThemeMode.dark : ThemeMode.light,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: HomeScreen(controller: controller, renderMapTiles: renderMapTiles),
    ),
  );

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF087F6E), brightness: brightness,
      primary: dark ? const Color(0xFF64D7B9) : const Color(0xFF087F6E),
      surface: dark ? const Color(0xFF192724) : Colors.white,
    );
    return ThemeData(
      useMaterial3: true, brightness: brightness, colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF10201C) : const Color(0xFFF6F7F3),
      fontFamily: 'Segoe UI',
      textTheme: ThemeData(brightness: brightness).textTheme.apply(
        fontFamily: 'Segoe UI',
        bodyColor: dark ? const Color(0xFFE5EDE8) : const Color(0xFF183C33),
        displayColor: dark ? const Color(0xFFE5EDE8) : const Color(0xFF183C33),
      ),
      dividerColor: dark ? const Color(0xFF30453C) : const Color(0xFFE8EDE7),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: dark ? const Color(0xFF233831) : const Color(0xFFF1F4EE),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      ),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      )),
      cardTheme: CardThemeData(elevation: 0, margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
    );
  }
}
