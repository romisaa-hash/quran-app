import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_state.dart';
import 'screens/home_shell.dart';
import 'services/notification_service.dart';
import 'utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppState.instance.load();
  try {
    await NotificationService.init();
  } catch (_) {}
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const RafiqApp());
}

class RafiqApp extends StatelessWidget {
  const RafiqApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kGreen,
        primary: kGreen,
        secondary: kGold,
        surface: kCream,
      ),
      scaffoldBackgroundColor: kCream,
    );
    return MaterialApp(
      title: 'رفيق المسلم',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: base.copyWith(
        textTheme: base.textTheme.apply(fontFamily: GoogleFonts.tajawal().fontFamily),
        appBarTheme: AppBarTheme(
          backgroundColor: kGreen,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          titleTextStyle: GoogleFonts.tajawal(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      home: const HomeShell(),
    );
  }
}
