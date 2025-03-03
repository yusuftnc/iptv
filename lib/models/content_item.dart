class ContentItem {
  final String id;
  final String name;
  final String? streamType; // 'live', 'movie', 'series'
  final String? streamIcon;
  final String? streamUrl;
  final String? description;
  final String? category;

  ContentItem({
    required this.id,
    required this.name,
    this.streamType,
    this.streamIcon,
    this.streamUrl,
    this.description,
    this.category,
  });

  factory ContentItem.fromJson(Map<String, dynamic> json, String type) {
    return ContentItem(
      id: json['stream_id']?.toString() ?? json['series_id']?.toString() ?? '',
      name: json['name'] ?? '',
      streamType: type,
      streamIcon: type == 'series' 
          ? json['cover'] ?? '' 
          : json['stream_icon'] ?? '',
      streamUrl: json['stream_url'] ?? '',
      description: json['description'] ?? json['plot'] ?? '',
      category: json['category_id']?.toString() ?? '',
    );
  }
} 