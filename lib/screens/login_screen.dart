import 'package:flutter/material.dart';
import '../services/iptv_service.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final storageService = StorageService();
    final credentials = await storageService.getCredentials();
    
    setState(() {
      _hostController.text = credentials['host'] ?? '';
      _portController.text = credentials['port'] ?? '';
      _usernameController.text = credentials['username'] ?? '';
      _passwordController.text = credentials['password'] ?? '';
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        final iptvService = IptvService();
        await iptvService.initialize(
          host: _hostController.text,
          port: _portController.text,
          username: _usernameController.text,
          password: _passwordController.text,
        );

        final success = await iptvService.login();

        if (success) {
          // Giriş başarılı, bilgileri kaydet
          if (_rememberMe) {
            final storageService = StorageService();
            await storageService.saveCredentials(
              host: _hostController.text,
              port: _portController.text,
              username: _usernameController.text,
              password: _passwordController.text,
            );
          }

          if (mounted) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 100),
              ),
            );
          }
        } else {
          setState(() {
            _errorMessage = 'Giriş başarısız. Lütfen bilgilerinizi kontrol edin.';
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Bağlantı hatası: ${e.toString()}';
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sabit değerler
    const double padding = 16.0;
    const double iconSize = 80;
    const double verticalSpacing = 16.0;
    const double largeVerticalSpacing = 24.0;
    const double largeIconSpacing = 30.0;
    const double buttonVerticalPadding = 16.0;
    const double buttonFontSize = 16.0;
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('IPTV Giriş'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(padding),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.tv,
                  size: iconSize,
                  color: Colors.blue,
                ),
                const SizedBox(height: largeIconSpacing),
                TextFormField(
                  controller: _hostController,
                  decoration: const InputDecoration(
                    labelText: 'Sunucu Adresi',
                    prefixIcon: Icon(Icons.dns),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white10,
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Lütfen sunucu adresini girin';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: verticalSpacing),
                TextFormField(
                  controller: _portController,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    prefixIcon: Icon(Icons.settings_ethernet),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white10,
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Lütfen port numarasını girin';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: verticalSpacing),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Kullanıcı Adı',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white10,
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Lütfen kullanıcı adını girin';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: verticalSpacing),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Şifre',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white10,
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  style: const TextStyle(color: Colors.white),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Lütfen şifrenizi girin';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: verticalSpacing),
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (value) {
                        setState(() {
                          _rememberMe = value ?? true;
                        });
                      },
                      checkColor: Colors.white,
                      fillColor: MaterialStateProperty.resolveWith<Color>(
                        (Set<MaterialState> states) {
                          if (states.contains(MaterialState.disabled)) {
                            return Colors.grey.withOpacity(.32);
                          }
                          return Colors.blue;
                        },
                      ),
                    ),
                    const Text(
                      'Beni Hatırla',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: largeVerticalSpacing),
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: verticalSpacing),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: buttonVerticalPadding),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : const Text(
                          'Giriş Yap',
                          style: TextStyle(fontSize: buttonFontSize),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
