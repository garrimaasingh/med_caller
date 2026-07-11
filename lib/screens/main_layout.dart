import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_design.dart';
import '../core/providers/patient_provider.dart';
import 'dashboard_screen.dart';
import 'call_history_screen.dart';
import 'patient_list_screen.dart';
import 'ai_notes_screen.dart';
import 'profile_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});
  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PatientProvider>().fetchPatients();
    });
  }

  final List<Widget> _screens = [
    const DashboardScreen(),
    const CallHistoryScreen(),
    const PatientListScreen(),
    const AINotesScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: const Border(top: BorderSide(color: AppColors.border, width: 1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _navItem(0, Icons.home_outlined, Icons.home, 'Home'),
              _navItem(1, Icons.phone_outlined, Icons.phone, 'Calls'),
              _navItem(2, Icons.people_outline, Icons.people, 'Patients'),
              _navItem(3, Icons.auto_awesome_outlined, Icons.auto_awesome, 'AI Notes'),
              _navItem(4, Icons.menu, Icons.menu, 'More'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, IconData activeIcon, String label) {
    final selected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon,
              size: 24,
              color: selected ? AppColors.primary : AppColors.textHint),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primary : AppColors.textHint,
            )),
          ],
        ),
      ),
    );
  }
}
