import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/screens/My_Profile.dart';

class TopNavbar extends StatefulWidget implements PreferredSizeWidget {
  final int userId;
  final bool showDrawer;

  const TopNavbar({
    super.key,
    required this.userId,
    this.showDrawer = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<TopNavbar> createState() => _TopNavbarState();
}

class _TopNavbarState extends State<TopNavbar> {
  String? profileImageUrl;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserImage();
  }

  Future<void> _loadUserImage() async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('users')
          .select('profile_image')
          .eq('user_id', widget.userId)
          .single();

      setState(() {
        profileImageUrl = response['profile_image'];
        isLoading = false;
      });

      print("TopNavbar loaded image: $profileImageUrl");
    } catch (e) {
      print("Error loading profile image in navbar: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      automaticallyImplyLeading: false,
      
      title: Row(
        children: const [
          Image(
            image: AssetImage('assets/miu_logo1.png'),
            width: 180,
            height: 180,
          ),
          SizedBox(width: 10),
        ],
      ),

      actions: [
        // Search Icon with grey circle
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

        // Profile Avatar
        if (widget.showDrawer)
          Builder(
            builder: (context) => GestureDetector(
              onTap: () {
                Scaffold.of(context).openEndDrawer();
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: (profileImageUrl != null && profileImageUrl!.isNotEmpty)
                    ? NetworkImage(profileImageUrl!)
                    : null,
                child: (profileImageUrl == null || profileImageUrl!.isEmpty)
                    ? const Icon(Icons.person, color: Colors.black)
                    : null,
              ),
            ),
          )
        else
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MyProfile(userId: widget.userId),
                ),
              );
            },
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: (profileImageUrl != null && profileImageUrl!.isNotEmpty)
                  ? NetworkImage(profileImageUrl!)
                  : null,
              child: (profileImageUrl == null || profileImageUrl!.isEmpty)
                  ? const Icon(Icons.person, color: Colors.black)
                  : null,
            ),
          ),

        const SizedBox(width: 15),
      ],
    );
  }
}