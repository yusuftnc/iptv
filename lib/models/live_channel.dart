/// Canlı kanalda önceki/sonraki geçiş için düz liste öğesi.
class LiveChannel {
  final String id;
  final String name;
  final String streamUrl;
  final String? icon;
  final String historyId;

  const LiveChannel({
    required this.id,
    required this.name,
    this.streamUrl = '',
    this.icon,
    required this.historyId,
  });

  factory LiveChannel.xtream(Map<String, dynamic> json) {
    final id = json['stream_id']?.toString() ?? '';
    final icon = json['stream_icon']?.toString();
    return LiveChannel(
      id: id,
      name: json['name']?.toString() ?? '',
      icon: (icon == null || icon.isEmpty) ? null : icon,
      historyId: id,
    );
  }
}
