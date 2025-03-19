import 'package:hive/hive.dart';

part 'favorite_item.g.dart';

@HiveType(typeId: 0)
class FavoriteItem extends HiveObject {
  @HiveField(0)
  late String id;
  
  @HiveField(1)
  late String name;
  
  @HiveField(2)
  late String streamType; // 'live', 'movie', 'series'
  
  @HiveField(3)
  String? streamIcon;
  
  @HiveField(4)
  String? category;
  
  @HiveField(5)
  DateTime addedDate = DateTime.now();
  
  @HiveField(6)
  String? streamUrl;
  
  @HiveField(7)
  String? description;
  
  FavoriteItem({
    required this.id,
    required this.name,
    required this.streamType,
    this.streamIcon,
    this.category,
    this.streamUrl,
    this.description,
  });
} 