import 'package:flutter/material.dart';
import '../models/saved_playlist.dart';
import '../services/app_settings.dart';
import '../services/cloud_sync_service.dart';
import '../services/iptv_service.dart';
import '../services/playlist_content.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  final SavedPlaylist? existing;

  const LoginScreen({super.key, this.existing});

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
  bool _canSubmit = false;
  String _errorMessage = '';

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _hostController.text = existing.host;
      _usernameController.text = existing.username;
      _passwordController.text = existing.password;
    }
    for (final controller in [
      _nameController,
      _hostController,
      _usernameController,
      _passwordController,
    ]) {
      controller.addListener(_refreshSubmit);
    }
    _refreshSubmit();
  }

  void _refreshSubmit() {
    final ready = _nameController.text.trim().isNotEmpty &&
        _hostController.text.trim().isNotEmpty &&
        _usernameController.text.trim().isNotEmpty &&
        _passwordController.text.trim().isNotEmpty;
    if (ready == _canSubmit) return;
    setState(() => _canSubmit = ready);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    dismissKeyboard();
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
            id: widget.existing?.id ??
                DateTime.now().microsecondsSinceEpoch.toString(),
            name: _nameController.text.trim(),
            kind: 'xtream',
            host: server,
            username: _usernameController.text,
            password: _passwordController.text,
          );
          if (_isEditing || _rememberMe) {
            await storageService.savePlaylist(playlist);
            await storageService.saveCredentials(
              host: server,
              port: '',
              username: _usernameController.text,
              password: _passwordController.text,
            );
          }

          if (_isEditing) {
            if (mounted) Navigator.pop(context, true);
            return;
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
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const HomeScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 100),
              ),
            );
          }
        } else {
          setState(() {
            _errorMessage = AppText.get('loginCheck');
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = '${AppText.get('connectionError')}: $e';
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

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppText.get('deletePlaylistTitle')),
        content: Text(existing.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppText.get('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppText.get('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await PlaylistContent.deleteLocalFile(existing);
    await StorageService().deletePlaylist(existing.id);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    AppSettingsScope.watch(context);
    final p = context.palette;
    // Sabit değerler
    const double padding = 16.0;
    const double iconSize = 80;
    const double verticalSpacing = 16.0;
    const double largeVerticalSpacing = 24.0;
    const double largeIconSpacing = 30.0;
    const double buttonFontSize = 16.0;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        title: Text(_isEditing ? AppText.get('editPlaylist') : 'Bağlantı'),
        backgroundColor: context.accent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            dismissKeyboard();
            Navigator.pop(context);
          },
        ),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: AppText.get('delete'),
              onPressed: _isLoading ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(padding, 36, padding, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.tv,
                size: iconSize,
                color: context.accent,
              ),
              const SizedBox(height: largeIconSpacing),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: AppText.get('playlistName'),
                  prefixIcon: Icon(Icons.bookmark_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  filled: true,
                  fillColor: p.field,
                  labelStyle: TextStyle(color: p.label),
                ),
                style: TextStyle(color: p.text),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return AppText.get('playlistNameRequired');
                  }
                  return null;
                },
              ),
              const SizedBox(height: verticalSpacing),
              TextFormField(
                controller: _hostController,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: AppText.get('server'),
                  hintText: 'http://sunucu:8080',
                  prefixIcon: Icon(Icons.dns),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  filled: true,
                  fillColor: p.field,
                  labelStyle: TextStyle(color: p.label),
                  hintStyle: TextStyle(color: p.muted),
                ),
                style: TextStyle(color: p.text),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return AppText.get('serverRequired');
                  }
                  return null;
                },
              ),
              const SizedBox(height: verticalSpacing),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: AppText.get('username'),
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  filled: true,
                  fillColor: p.field,
                  labelStyle: TextStyle(color: p.label),
                ),
                style: TextStyle(color: p.text),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return AppText.get('usernameRequired');
                  }
                  return null;
                },
              ),
              const SizedBox(height: verticalSpacing),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: AppText.get('password'),
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  filled: true,
                  fillColor: p.field,
                  labelStyle: TextStyle(color: p.label),
                ),
                style: TextStyle(color: p.text),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return AppText.get('passwordRequired');
                  }
                  return null;
                },
              ),
              if (!_isEditing) ...[
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
                          return context.accent;
                        },
                      ),
                    ),
                    Text(
                      AppText.get('remember'),
                      style: TextStyle(color: p.text),
                    ),
                  ],
                ),
              ],
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
              FilledButton(
                onPressed: _isLoading || !_canSubmit ? null : _login,
                style: context.primaryButtonStyle,
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        AppText.get(_isEditing ? 'save' : 'login'),
                        style: const TextStyle(fontSize: buttonFontSize),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
