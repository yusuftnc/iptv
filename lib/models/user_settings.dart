import 'package:hive/hive.dart';

part 'user_settings.g.dart';

@HiveType(typeId: 2)
class UserSettings extends HiveObject {
  @HiveField(0)
  bool darkMode = true;
  
  @HiveField(1)
  String language = 'tr';
  
  @HiveField(2)
  bool autoPlayNext = true;
  
  @HiveField(3)
  bool showSubtitles = false;
  
  @HiveField(4)
  int defaultVolume = 100;
  
  @HiveField(5)
  String videoQuality = 'auto'; // 'low', 'medium', 'high', 'auto'
  
  UserSettings({
    this.darkMode = true,
    this.language = 'tr',
    this.autoPlayNext = true,
    this.showSubtitles = false,
    this.defaultVolume = 100,
    this.videoQuality = 'auto',
  });
} 