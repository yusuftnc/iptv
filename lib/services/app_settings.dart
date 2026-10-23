import 'package:flutter/material.dart';

import 'database_service.dart';

extension AppAccent on BuildContext {
  /// Aydınlık modda mavi bir ton koyu; karanlık modda mevcut mavi.
  Color get accent => Theme.of(this).brightness == Brightness.dark
      ? Colors.blue
      : Colors.blue.shade700;

  ButtonStyle get primaryButtonStyle {
    final p = palette;
    return FilledButton.styleFrom(
      backgroundColor: accent,
      foregroundColor: Colors.white,
      disabledBackgroundColor: p.disabledButton,
      disabledForegroundColor: p.disabledButtonText,
      padding: const EdgeInsets.symmetric(vertical: 16),
    );
  }

  AppPalette get palette => AppPalette.of(this);
}

class AppPalette {
  final Color background;
  final Color text;
  final Color muted;
  final Color card;
  final Color field;
  final Color label;
  final Color placeholder;
  final Color disabledButton;
  final Color disabledButtonText;

  const AppPalette({
    required this.background,
    required this.text,
    required this.muted,
    required this.card,
    required this.field,
    required this.label,
    required this.placeholder,
    required this.disabledButton,
    required this.disabledButtonText,
  });

  static AppPalette of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return const AppPalette(
        background: Colors.black,
        text: Colors.white,
        muted: Colors.white70,
        card: Color(0xFF1C1C1E),
        field: Colors.white10,
        label: Colors.white70,
        placeholder: Color(0xFF2C2C2E),
        disabledButton: Colors.white12,
        disabledButtonText: Colors.white38,
      );
    }
    return const AppPalette(
      background: Colors.white,
      text: Color(0xFF1C1C1E),
      muted: Colors.black54,
      card: Color(0xFFF2F2F7),
      field: Color(0xFFF2F2F7),
      label: Colors.black54,
      placeholder: Color(0xFFE5E5EA),
      disabledButton: Color(0xFFE5E5EA),
      disabledButtonText: Color(0xFF8E8E93),
    );
  }
}

class AppSettingsScope extends InheritedNotifier<AppSettings> {
  const AppSettingsScope({
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings watch(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    return scope?.notifier ?? AppSettings.instance;
  }
}

class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  bool darkMode = true;
  String language = 'tr';

  Future<void> load() async {
    final settings = await DatabaseService().getUserSettings();
    darkMode = settings.darkMode;
    language = settings.language == 'en' ? 'en' : 'tr';
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    if (darkMode == value) return;
    darkMode = value;
    notifyListeners();
    await DatabaseService().updateSetting('darkMode', value);
  }

  Future<void> setLanguage(String value) async {
    final next = value == 'en' ? 'en' : 'tr';
    if (language == next) return;
    language = next;
    notifyListeners();
    await DatabaseService().updateSetting('language', next);
  }
}

class AppText {
  static String get(String key) {
    final pack = AppSettings.instance.language == 'en' ? _en : _tr;
    return pack[key] ?? _tr[key] ?? key;
  }

  static const _tr = {
    'sourceTitle': 'Kaynak seç',
    'saved': 'Kayıtlı',
    'singleStream': 'TEK YAYIN',
    'delete': 'Sil',
    'deletePlaylistTitle': 'Playlist silinsin mi?',
    'cancel': 'Vazgeç',
    'loginFailed': 'Giriş başarısız. Playlist kaydı duruyor.',
    'listFailed': 'Liste alınamadı.',
    'fileFailed': 'Dosya açılamadı.',
    'invalidList': 'Geçersiz liste.',
    'playlistName': 'Playlist adı',
    'playlistNameRequired': 'Lütfen playlist adını girin',
    'server': 'Sunucu Adresi',
    'serverRequired': 'Lütfen sunucu adresini girin',
    'username': 'Kullanıcı Adı',
    'usernameRequired': 'Lütfen kullanıcı adını girin',
    'password': 'Şifre',
    'passwordRequired': 'Lütfen şifrenizi girin',
    'remember': 'Beni Hatırla',
    'login': 'Giriş Yap',
    'connectionError': 'Bağlantı hatası',
    'loginCheck': 'Giriş başarısız. Lütfen bilgilerinizi kontrol edin.',
    'streamAddress': 'Yayın adresi',
    'streamAddressInvalid': 'Geçerli bir yayın adresi gir.',
    'play': 'Oynat',
    'file': 'Dosya',
    'address': 'Adres',
    'pickFile': 'Dosya seç',
    'listAddress': 'Liste adresi',
    'listAddressInvalid': 'Geçerli bir liste adresi gir.',
    'nameNeeded': 'Bu bir kanal listesi. Kaydetmek için playlist adı gir.',
    'add': 'Ekle',
    'open': 'Aç',
  };

  static const _en = {
    'sourceTitle': 'Choose source',
    'saved': 'Saved',
    'singleStream': 'SINGLE STREAM',
    'delete': 'Delete',
    'deletePlaylistTitle': 'Delete this playlist?',
    'cancel': 'Cancel',
    'loginFailed': 'Sign-in failed. The playlist is still saved.',
    'listFailed': 'Could not load the list.',
    'fileFailed': 'Could not open the file.',
    'invalidList': 'Invalid list.',
    'playlistName': 'Playlist name',
    'playlistNameRequired': 'Enter a playlist name',
    'server': 'Server address',
    'serverRequired': 'Enter the server address',
    'username': 'Username',
    'usernameRequired': 'Enter the username',
    'password': 'Password',
    'passwordRequired': 'Enter the password',
    'remember': 'Remember me',
    'login': 'Sign in',
    'connectionError': 'Connection error',
    'loginCheck': 'Sign-in failed. Check your details.',
    'streamAddress': 'Stream address',
    'streamAddressInvalid': 'Enter a valid stream address.',
    'play': 'Play',
    'file': 'File',
    'address': 'URL',
    'pickFile': 'Choose file',
    'listAddress': 'List address',
    'listAddressInvalid': 'Enter a valid list address.',
    'nameNeeded': 'This is a channel list. Enter a playlist name to save it.',
    'add': 'Add',
    'open': 'Open',
  };
}
