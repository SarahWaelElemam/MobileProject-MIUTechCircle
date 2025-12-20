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
      announcementId: map['announcement_id'],
      authorId: map['auth_id'],
      date: DateTime.parse(map['date']),
      time: map['time'],
      title: map['title'],
      description: map['description'],
      categoryId: map['category_id'],
    );
  }
}
