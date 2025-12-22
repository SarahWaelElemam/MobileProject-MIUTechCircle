class UserProfile {
  final String id;
  final String username;
  final String avatarUrl;

  UserProfile({
    required this.id,
    required this.username,
    required this.avatarUrl,
  });

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
    id: m['user_id'] ?? '',
    username: m['name'] ?? 'Unknown',
    avatarUrl: m['profile_image'] ?? '',
  );
}
