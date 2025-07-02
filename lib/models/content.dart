class Content {
  final String id;
  final String name;
  final String? streamUrl;
  final String? streamIcon;
  final String? description;
  final String contentType;

  Content({
    required this.id,
    required this.name,
    this.streamUrl,
    this.streamIcon,
    this.description,
    required this.contentType,
  });

  factory Content.fromJson(Map<String, dynamic> json, String contentType) {
    return Content(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      streamUrl: json['stream_url'],
      streamIcon: json['stream_icon'],
      description: json['description'],
      contentType: contentType,
    );
  }
} 