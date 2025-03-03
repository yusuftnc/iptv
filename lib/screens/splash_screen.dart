import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/iptv_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }
  
  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    final storageService = StorageService();
    final hasCredentials = await storageService.hasCredentials();
    
    if (hasCredentials) {
      // Kayıtlı giriş bilgileri var, otomatik giriş yap
      final credentials = await storageService.getCredentials();
      final iptvService = IptvService();
      
      await iptvService.initialize(
        host: credentials['host']!,
        port: credentials['port']!,
        username: credentials['username']!,
        password: credentials['password']!,
      );
      
      final loginSuccess = await iptvService.login();
      
      if (loginSuccess && mounted) {
        // Giriş başarılı, ana ekrana git
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else if (mounted) {
        // Giriş başarısız, login ekranına git
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } else if (mounted) {
      // Kayıtlı giriş bilgileri yok, login ekranına git
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.tv,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            const Text(
              'IPTV App',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ],
        ),
      ),
    );
  }
}
