import 'package:flutter/material.dart';
import 'package:project/views/messaging_page.dart';
import 'package:project/views/notifications_page.dart'; // ✅ Add this import

class BottomNavbar extends StatelessWidget {
  final int currentIndex;
  final int userId;

  const BottomNavbar({
    super.key,
    required this.currentIndex,
    required this.userId,
  });

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;

      case 1: // ✅ CHAT
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatsListPage(currentUserId: userId),
          ),
        );
        break;

      case 2: // ✅ NOTIFICATIONS
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NotificationsPage(userId: userId), // ✅ Navigate to notifications page
          ),
        );
        break;

      case 3:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

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
                  onTap: () => _onItemTapped(context, 0),
                ),
                _NavItem(
                  icon: Icons.chat,
                  label: "Chat",
                  selected: currentIndex == 1,
                  onTap: () => _onItemTapped(context, 1),
                ),
                const SizedBox(width: 55),
                _NavItem(
                  icon: Icons.notifications,
                  label: "Notifications",
                  selected: currentIndex == 2,
                  onTap: () => _onItemTapped(context, 2),
                ),
                _NavItem(
                  icon: Icons.person,
                  label: "Profile",
                  selected: currentIndex == 3,
                  onTap: () => _onItemTapped(context, 3),
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
                  onPressed: () {},
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

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
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