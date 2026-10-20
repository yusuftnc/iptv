import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/splash_screen.dart';
import 'models/favorite_item.dart';
import 'models/watch_history.dart';
import 'models/user_settings.dart';
import 'services/app_settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive'ı başlat
  await Hive.initFlutter();

  // Model adaptörlerini kaydet
  Hive.registerAdapter(FavoriteItemAdapter());
  Hive.registerAdapter(WatchHistoryAdapter());
  Hive.registerAdapter(UserSettingsAdapter());

  // Kutuları aç
  await Hive.openBox<FavoriteItem>('favorites');
  await Hive.openBox<WatchHistory>('watchHistory');
  await Hive.openBox<UserSettings>('settings');

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await AppSettings.instance.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final dark = AppSettings.instance.darkMode;
        return MaterialApp(
          title: 'SUTU Player',
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue.shade700,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(
              foregroundColor: Colors.white,
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: Colors.black,
            appBarTheme: const AppBarTheme(
              foregroundColor: Colors.white,
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            useMaterial3: true,
          ),
          locale: Locale(AppSettings.instance.language),
          builder: (context, child) {
            return AppSettingsScope(
              settings: AppSettings.instance,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const SplashScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
