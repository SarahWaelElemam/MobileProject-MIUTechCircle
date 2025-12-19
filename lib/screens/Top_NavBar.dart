import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
class TopNavbar extends StatelessWidget implements PreferredSizeWidget {
  final int userId;

  const TopNavbar({Key? key, required this.userId}) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      title: Row(
        children: const [
          Icon(Icons.hub, color: Color(0xFFE63946), size: 32),
          SizedBox(width: 10),
          Text(
            'MIU TechCircle',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.search,
            color: Color.fromARGB(221, 96, 96, 96),
            size: 20,
          ),
        ),
        const SizedBox(width: 15),
        Builder(
          builder: (context) => GestureDetector(
            onTap: () => Scaffold.of(context).openEndDrawer(),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey.shade200,
              child: const Icon(Icons.person, color: Colors.black),
            ),
          ),
        ),
        const SizedBox(width: 15),
      ],
    );
  }
}