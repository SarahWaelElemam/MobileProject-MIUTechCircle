class Friendship {
  final String friendshipId;
  final String userId;
  final String friendId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Friendship({
    required this.friendshipId,
    required this.userId,
    required this.friendId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Friendship.fromJson(Map<String, dynamic> json) {
    return Friendship(
      friendshipId: json['friendship_id'].toString(),
      userId: json['user_id'].toString(),
      friendId: json['friend_id'].toString(),
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
