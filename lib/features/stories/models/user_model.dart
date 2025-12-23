class UserProfile {
  final int id;
  final String username;
  final String avatarUrl;

  UserProfile({
    required this.id,
    required this.username,
    required this.avatarUrl,
  });

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
    id: m['user_id'] is int
        ? m['user_id']
        : int.tryParse(m['user_id'].toString()) ?? 0,
    username: m['name'] ?? 'Unknown',
    avatarUrl: m['profile_image'] ?? '',
  );
}