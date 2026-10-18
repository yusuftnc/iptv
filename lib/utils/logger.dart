// basit seviye/tanımlı logger
import 'package:flutter/foundation.dart';

enum LogLevel { off, error, info, debug }

class Log {
  static final LogLevel level = _readLevel();

  static LogLevel _readLevel() {
    const val = String.fromEnvironment('LOG_LEVEL', defaultValue: 'info');
    switch (val) {
      case 'error':
        return LogLevel.error;
      case 'info':
        return LogLevel.info;
      case 'off':
        return LogLevel.off;
      default:
        return LogLevel.debug;
    }
  }

  static void d(String tag, String msg) {
    if (level.index >= LogLevel.debug.index && kDebugMode) {
      debugPrint('D/$tag • $msg');
    }
  }

  static void i(String tag, String msg) {
    if (level.index >= LogLevel.info.index && kDebugMode) {
      debugPrint('I/$tag • $msg');
    }
  }

  static void e(String tag, Object err, [StackTrace? st]) {
    if (level.index >= LogLevel.error.index && kDebugMode) {
      debugPrint('E/$tag • $err');
      if (st != null) debugPrint(st.toString());
    }
  }
}
