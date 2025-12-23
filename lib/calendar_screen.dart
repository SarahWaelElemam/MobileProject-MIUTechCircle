import 'package:flutter/material.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime selectedDate = DateTime(2020, 3, 15);
  DateTime currentMonth = DateTime(2020, 3, 1);
  int activeNavIndex = 2; // Calendar is active by default

  List<String> weekDays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  int getDaysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  int getFirstDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1).weekday;
  }

  void previousMonth() {
    setState(() {
      currentMonth = DateTime(currentMonth.year, currentMonth.month - 1, 1);
    });
  }

  void nextMonth() {
    setState(() {
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
    });
  }

  String getMonthYear(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 30),
                        _buildWeekDaysHeader(),
                        const SizedBox(height: 10),
                        _buildCalendarGrid(),
                        const SizedBox(height: 30),
                        _buildScheduleList(),
                        const SizedBox(height: 20),
                        _buildBottomNavigation(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Profile Button
        InkWell(
          onTap: () {
            _showSnackBar('Profile clicked');
          },
          borderRadius: BorderRadius.circular(25),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFE53935), Color(0xFFC62828)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
        Row(
          children: [
            // Add Button
            InkWell(
              onTap: () {
                _showSnackBar('Add event clicked');
                // You can add navigation to event creation screen here
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
                ),
                child: const Icon(
                  Icons.add,
                  color: Color(0xFFE53935),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Menu Button
            InkWell(
              onTap: () {
                _showSnackBar('Menu clicked');
                // You can add a menu drawer or popup here
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.menu,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeekDaysHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: weekDays.map((day) {
        return SizedBox(
          width: 40,
          child: Center(
            child: Text(
              day,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMonthNavigation() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Month/Year Title - Clickable to show date picker
          InkWell(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: currentMonth,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() {
                  currentMonth = DateTime(picked.year, picked.month, 1);
                });
              }
            },
            child: Text(
              getMonthYear(currentMonth),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF212121),
              ),
            ),
          ),
          Row(
            children: [
              // Previous Month Button
              InkWell(
                onTap: previousMonth,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.chevron_left,
                    size: 20,
                    color: Color(0xFF212121),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Next Month Button
              InkWell(
                onTap: nextMonth,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Color(0xFF212121),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    int daysInMonth = getDaysInMonth(currentMonth);
    int firstDayOfWeek = getFirstDayOfMonth(currentMonth) % 7;

    List<Widget> dayWidgets = [];

    // Add empty cells for days before the first day of the month
    for (int i = 0; i < firstDayOfWeek; i++) {
      dayWidgets.add(const SizedBox(width: 40, height: 40));
    }

    // Add day cells
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(currentMonth.year, currentMonth.month, day);
      final isSelected = date.day == selectedDate.day &&
          date.month == selectedDate.month &&
          date.year == selectedDate.year;

      dayWidgets.add(
        InkWell(
          onTap: () {
            setState(() {
              selectedDate = date;
            });
            _showSnackBar('Selected: ${date.day} ${getMonthYear(date)}');
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE53935) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? Colors.white
                      : (day == DateTime.now().day &&
                              currentMonth.month == DateTime.now().month &&
                              currentMonth.year == DateTime.now().year)
                          ? const Color(0xFFE53935)
                          : const Color(0xFF212121),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildMonthNavigation(),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 7,
          mainAxisSpacing: 10,
          crossAxisSpacing: 0,
          children: dayWidgets,
        ),
      ],
    );
  }

  Widget _buildScheduleList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildScheduleItem(
          'Today · Fri, 16 Mar',
          'Nothing Scheduled Yet',
          'Tap to find events for this day',
          true,
          DateTime(2020, 3, 15),
        ),
        const SizedBox(height: 20),
        _buildScheduleItem(
          'Tomorrow · Sat, 17 Mar',
          'Nothing Scheduled Yet',
          'Tap to find events for this day',
          false,
          DateTime(2020, 3, 16),
        ),
        const SizedBox(height: 20),
        _buildScheduleItem(
          'Sun, 18 Mar',
          'Nothing Scheduled Yet',
          'Tap to find events for this day',
          false,
          DateTime(2020, 3, 17),
        ),
      ],
    );
  }

  Widget _buildScheduleItem(
      String date, String title, String subtitle, bool isToday, DateTime itemDate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date Label - Clickable
        InkWell(
          onTap: () {
            setState(() {
              selectedDate = itemDate;
            });
            _showSnackBar('Selected date: $date');
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              date,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isToday ? const Color(0xFFE53935) : Colors.grey[500],
              ),
            ),
          ),
        ),
        // Schedule Card - Clickable
        InkWell(
          onTap: () {
            _showSnackBar('Schedule item clicked: $date');
            // You can navigate to event details or creation screen here
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(
                  color: const Color(0xFFE53935),
                  width: 4,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF212121),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildNavIcon(Icons.home_outlined, 0, 'Home'),
        _buildNavIcon(Icons.access_time_outlined, 1, 'Timeline'),
        _buildNavIcon(Icons.calendar_today, 2, 'Calendar'),
      ],
    );
  }

  Widget _buildNavIcon(IconData icon, int index, String label) {
    final bool isActive = activeNavIndex == index;
    
    return InkWell(
      onTap: () {
        setState(() {
          activeNavIndex = index;
        });
        _showSnackBar('$label clicked');
        // You can add navigation to different screens here
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFE53935) : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : Colors.grey[400],
          size: 26,
        ),
      ),
    );
  }
}