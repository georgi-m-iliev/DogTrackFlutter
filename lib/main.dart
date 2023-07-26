import 'homepage.dart';
import 'package:flutter/material.dart';
import 'package:wakelock/wakelock.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Wakelock.enable();

    return MaterialApp(
      title: 'DogTrack',
      // locale: const Locale('bg'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('bg'),
      ],
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        snackBarTheme: const SnackBarThemeData(
          contentTextStyle: TextStyle(fontFamily: "montserrat", fontSize: 16.0),
          behavior: SnackBarBehavior.floating,
          width: 250.0,
        ),
      ),
      home: const Scaffold(
        body: HomePage()
      ),
    );
  }
}
