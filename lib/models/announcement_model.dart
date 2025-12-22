class AnnouncementModel {
  final int announcementId;
  final int authorId;
  final DateTime date;
  final String time;
  final String title;
  final String description;
  final int categoryId;

  AnnouncementModel({
    required this.announcementId,
    required this.authorId,
    required this.date,
    required this.time,
    required this.title,
    required this.description,
    required this.categoryId,
  });

  factory AnnouncementModel.fromMap(Map<String, dynamic> map) {
    return AnnouncementModel(
      announcementId: map['ann_id'] as int,  // ✅ Changed from 'announcement_id' to 'ann_id'
      authorId: map['auth_id'] as int,       // ✅ This was already correct
      date: DateTime.parse(map['date'] as String),
      time: map['time'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      categoryId: map['category_id'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ann_id': announcementId,
      'auth_id': authorId,
      'date': date.toIso8601String(),
      'time': time,
      'title': title,
      'description': description,
      'category_id': categoryId,
    };
  }

  // Helper to get DateTime combining date and time
  DateTime get fullDateTime {
    final timeParts = time.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
      timeParts.length > 2 ? int.parse(timeParts[2]) : 0,
    );
  }
}