enum MediaType { image, video }

class Story {
  final String id;
  final String userId;
  final String mediaUrl;
  final DateTime createdAt;
  final DateTime expiresAt;
  final Set<String> seenBy;

  Story({
    required this.id,
    required this.userId,
    required this.mediaUrl,
    required this.createdAt,
    required this.expiresAt,
    required this.seenBy,
  });

  MediaType get mediaType {
    final ext = mediaUrl.split('.').last.toLowerCase();
    if ([
      'mp4',
      'mov',
      'avi',
      'wmv',
      'm4v',
      'mpg',
      'mpeg',
      'webm',
    ].contains(ext)) {
      return MediaType.video;
    }
    return MediaType.image;
  }

  Story copyWith({Set<String>? seenBy}) => Story(
    id: id,
    userId: userId,
    mediaUrl: mediaUrl,
    createdAt: createdAt,
    expiresAt: expiresAt,
    seenBy: seenBy ?? this.seenBy,
  );
}
