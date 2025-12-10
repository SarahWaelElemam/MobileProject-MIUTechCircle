import 'package:flutter/material.dart';

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({Key? key}) : super(key: key);

  @override
  State<NotificationPreferencesPage> createState() => _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState extends State<NotificationPreferencesPage> {
  bool _allNotifications = true;
  bool _opportunities = true;
  bool _messages = true;
  bool _connections = true;
  bool _posts = false;
  bool _events = true;
  bool _projects = true;
  bool _emailDigest = true;
  bool _pushNotifications = true;
  bool _smsNotifications = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notification Preferences',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Stay updated with opportunities and connections',
                    style: TextStyle(color: Colors.grey[800], fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          _buildSectionTitle('General'),
          _buildSwitchTile(
            'All Notifications',
            'Enable or disable all notifications',
            Icons.notifications_active,
            _allNotifications,
            (value) => setState(() {
              _allNotifications = value;
              if (!value) {
                _opportunities = false;
                _messages = false;
                _connections = false;
                _posts = false;
                _events = false;
                _projects = false;
              }
            }),
          ),
          const SizedBox(height: 16),
          
          _buildSectionTitle('Activity Notifications'),
          _buildSwitchTile(
            'New Opportunities',
            'Internships, jobs, and competitions',
            Icons.work_outline,
            _opportunities,
            (value) => setState(() => _opportunities = value),
          ),
          _buildSwitchTile(
            'Messages',
            'Direct messages from connections',
            Icons.chat_bubble_outline,
            _messages,
            (value) => setState(() => _messages = value),
          ),
          _buildSwitchTile(
            'Connection Requests',
            'New connection requests',
            Icons.people_outline,
            _connections,
            (value) => setState(() => _connections = value),
          ),
          _buildSwitchTile(
            'Post Updates',
            'Likes, comments, and shares',
            Icons.thumb_up_outlined,
            _posts,
            (value) => setState(() => _posts = value),
          ),
          _buildSwitchTile(
            'Events',
            'Event invitations and reminders',
            Icons.event_outlined,
            _events,
            (value) => setState(() => _events = value),
          ),
          _buildSwitchTile(
            'Project Collaborations',
            'Project invites and updates',
            Icons.assignment_outlined,
            _projects,
            (value) => setState(() => _projects = value),
          ),
          const SizedBox(height: 16),
          
          _buildSectionTitle('Notification Channels'),
          _buildSwitchTile(
            'Push Notifications',
            'Receive notifications on your device',
            Icons.phone_iphone,
            _pushNotifications,
            (value) => setState(() => _pushNotifications = value),
          ),
          _buildSwitchTile(
            'Email Digest',
            'Daily summary of activities',
            Icons.email_outlined,
            _emailDigest,
            (value) => setState(() => _emailDigest = value),
          ),
          _buildSwitchTile(
            'SMS Notifications',
            'Important updates via SMS',
            Icons.sms_outlined,
            _smsNotifications,
            (value) => setState(() => _smsNotifications = value),
          ),
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Preferences saved!')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Save Preferences',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.red,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, IconData icon, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        secondary: Icon(icon, color: Colors.red),
        value: value,
        activeColor: Colors.red,
        onChanged: onChanged,
      ),
    );
  }
}