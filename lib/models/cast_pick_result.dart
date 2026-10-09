import 'package:flutter_chrome_cast/entities.dart';

/// Cast sheet sonucu: Google Cast cihazı veya AirPlay.
sealed class CastPickResult {
  const CastPickResult();
}

class CastPickGoogleCast extends CastPickResult {
  final GoogleCastDevice device;
  const CastPickGoogleCast(this.device);
}

class CastPickAirPlay extends CastPickResult {
  const CastPickAirPlay();
}
