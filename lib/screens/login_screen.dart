import 'package:flutter/material.dart';
import '../models/saved_playlist.dart';
import '../services/cloud_sync_service.dart';
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
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = true;
  String _errorMessage = '';

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
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
        final server = IptvService.normalizeServerBaseUrl(_hostController.text, '');
        final iptvService = IptvService();
        await iptvService.initialize(
          host: server,
          port: '',
          username: _usernameController.text,
          password: _passwordController.text,
        );

        final success = await iptvService.login();

        if (success) {
          final storageService = StorageService();
          final playlist = SavedPlaylist(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: _nameController.text.trim(),
            kind: 'xtream',
            host: server,
            username: _usernameController.text,
            password: _passwordController.text,
          );
          if (_rememberMe) {
            await storageService.savePlaylist(playlist);
            await storageService.saveCredentials(
              host: server,
              port: '',
              username: _usernameController.text,
              password: _passwordController.text,
            );
          }

          await CloudSyncService.instance.start(
            host: server,
            port: '',
            username: _usernameController.text,
            password: _passwordController.text,
          );

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
        title: const Text('Bağlantı'),
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
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Playlist adı',
                    prefixIcon: Icon(Icons.bookmark_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    filled: true,
                    fillColor: Colors.white10,
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen playlist adını girin';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: verticalSpacing),
                TextFormField(
                  controller: _hostController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Sunucu Adresi',
                    hintText: 'http://sunucu:8080',
                    prefixIcon: Icon(Icons.dns),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    filled: true,
                    fillColor: Colors.white10,
                    labelStyle: TextStyle(color: Colors.white70),
                    hintStyle: TextStyle(color: Colors.white38),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen sunucu adresini girin';
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
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
