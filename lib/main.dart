import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'models/favorite_item.dart';
import 'models/watch_history.dart';
import 'models/user_settings.dart';

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
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IPTV App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
