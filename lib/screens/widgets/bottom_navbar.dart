import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/AddPostScreen.dart';
import 'package:flutter_application_1/screens/My_Profile.dart';

class BottomNavbar extends StatelessWidget {
  final int? currentUserId;
  final int currentIndex;

  const BottomNavbar({
    super.key,
    this.currentUserId,
    this.currentIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 85,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 75,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 6),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home,
                  label: "Home",
                  selected: currentIndex == 0,
                  onTap: () {
                    if (currentIndex != 0) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
                ),
                _NavItem(
                  icon: Icons.chat,
                  label: "Chat",
                  selected: currentIndex == 1,
                  onTap: () {
                    // TODO: Navigate to Chat screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chat feature coming soon!')),
                    );
                  },
                ),
                const SizedBox(width: 55),
                _NavItem(
                  icon: Icons.notifications,
                  label: "Notifications",
                  selected: currentIndex == 2,
                  onTap: () {
                    // TODO: Navigate to Notifications screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notifications feature coming soon!')),
                    );
                  },
                ),
                _NavItem(
                  icon: Icons.person,
                  label: "Profile",
                  selected: currentIndex == 3,
                  onTap: () {
                    if (currentUserId != null && currentIndex != 3) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MyProfile(userId: currentUserId!),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          
          // Floating Add Button
          Positioned(
            top: -20,
            left: 0,
            right: 25,
            child: Center(
              child: Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Colors.red, Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddPostScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add, color: Colors.white, size: 36),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Bottom Nav Item Widget
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 24,
            color: selected ? Colors.red : Colors.grey,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? Colors.red : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}