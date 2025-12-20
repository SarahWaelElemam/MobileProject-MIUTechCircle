import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/announcement_model.dart';

final supabase = Supabase.instance.client;

class AnnouncementService {
  static Future<List<AnnouncementModel>> fetchAnnouncements() async {
    final data = await supabase
        .from('announcement')
        .select()
        .order('date', ascending: true);

    return (data as List)
        .map((e) => AnnouncementModel.fromMap(e))
        .toList();
  }
}
