class ContentItem {
  final String id;
  final String name;
  final String? streamType; // 'live', 'movie', 'series'
  final String? streamIcon;
  final String? streamUrl;
  final String? description;
  final String? category;
  final int? position;
  final int? duration;

  ContentItem({
    required this.id,
    required this.name,
    this.streamType,
    this.streamIcon,
    this.streamUrl,
    this.description,
    this.category,
    this.position,
    this.duration,
  });

  factory ContentItem.fromJson(Map<String, dynamic> json, [String? type]) {
    final contentType = type ?? json['stream_type']?.toString();
    final id = contentType == 'series' 
        ? json['series_id']?.toString() ?? json['stream_id']?.toString() ?? ''
        : json['stream_id']?.toString() ?? '';
        
    return ContentItem(
      id: id,
      name: json['name']?.toString() ?? '',
      streamType: contentType,
      streamIcon: contentType == 'series' 
          ? json['cover'] ?? '' 
          : json['stream_icon'] ?? '',
      streamUrl: json['stream_url']?.toString(),
      description: json['description'] ?? json['plot'] ?? '',
      category: json['category_id']?.toString() ?? '',
      position: json['position'] != null ? int.tryParse(json['position'].toString()) : null,
      duration: json['duration'] != null ? int.tryParse(json['duration'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'stream_url': streamUrl,
      'stream_type': streamType,
      'position': position,
      'duration': duration,
    };
  }
} 