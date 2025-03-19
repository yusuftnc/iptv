import 'package:hive/hive.dart';

part 'watch_history.g.dart';

@HiveType(typeId: 1)
class WatchHistory extends HiveObject {
  @HiveField(0)
  late String contentId;
  
  @HiveField(1)
  late String name;
  
  @HiveField(2)
  late String streamType; // 'live', 'movie', 'series'
  
  @HiveField(3)
  String? streamIcon;
  
  @HiveField(4)
  DateTime watchDate = DateTime.now();
  
  @HiveField(5)
  int? position; // İzleme pozisyonu (saniye cinsinden)
  
  @HiveField(6)
  int? duration; // Toplam süre (saniye cinsinden)
  
  @HiveField(7)
  String? streamUrl;
  
  @HiveField(8)
  String? category;
  
  WatchHistory({
    required this.contentId,
    required this.name,
    required this.streamType,
    this.streamIcon,
    this.position,
    this.duration,
    this.streamUrl,
    this.category,
  });
} 