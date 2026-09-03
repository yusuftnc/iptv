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

  /// Bölüm favorisinde dizi serisi API id'si; dizi favorisinde null.
  @HiveField(8)
  String? seriesId;

  FavoriteItem({
    required this.id,
    required this.name,
    required this.streamType,
    this.streamIcon,
    this.category,
    this.streamUrl,
    this.description,
    this.seriesId,
  });

  bool get isSeriesEpisodeFavorite {
    if (streamType != 'series') return false;
    if (seriesId != null &&
        seriesId!.isNotEmpty &&
        seriesId != id) {
      return true;
    }
    return RegExp(r'S\d+E\d+', caseSensitive: false).hasMatch(name);
  }
}
