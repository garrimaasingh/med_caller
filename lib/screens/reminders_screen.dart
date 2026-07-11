import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_design.dart';
import '../core/models/patient.dart';
import '../core/providers/patient_provider.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});
  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  String _tab = 'all'; // all | followup | fees | other

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildTabs(),
            const SizedBox(height: 8),
            Expanded(child: _buildReminderList()),
            _buildViewAll(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Reminders', style: AppTextStyles.screenTitle),
          const Icon(Icons.menu, color: AppColors.textDark),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        _tab_btn('all', 'All'),
        const SizedBox(width: 8),
        _tab_btn('followup', 'Follow-up'),
        const SizedBox(width: 8),
        _tab_btn('fees', 'Fees'),
        const SizedBox(width: 8),
        _tab_btn('other', 'Other'),
      ]),
    );
  }

  Widget _tab_btn(String value, String label) {
    final selected = _tab == value;
    return GestureDetector(
      onTap: () => setState(() => _tab = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textLight)),
      ),
    );
  }

  Widget _buildReminderList() {
    return Consumer<PatientProvider>(
      builder: (context, pp, _) {
        final reminders = _buildReminders(pp.allPatients);
        if (reminders.isEmpty) {
          return const Center(child: Text('No reminders', style: AppTextStyles.cardSubtitle));
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: reminders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _buildReminderCard(reminders[i]),
        );
      },
    );
  }

  List<_Reminder> _buildReminders(List<Patient> patients) {
    final reminders = <_Reminder>[];
    for (final p in patients) {
      final cs = p.consultationStatus;
      if (cs == 'Expired') {
        reminders.add(_Reminder(
          title: 'Consultation Expired',
          patientName: p.name,
          description: 'Consultation validity expired on ${p.consultationValidTillDisplay}',
          statusLabel: 'Today',
          statusColor: AppColors.redBg,
          icon: Icons.error_outline,
          daysLabel: 'Today',
        ));
      } else if (cs == 'Expiring Soon') {
        reminders.add(_Reminder(
          title: 'Follow-up Due Tomorrow',
          patientName: p.name,
          description: 'Consultation valid till ${p.consultationValidTillDisplay}',
          statusLabel: 'Tomorrow',
          statusColor: const Color(0xFFF59E0B),
          icon: Icons.warning_amber_rounded,
          daysLabel: 'Tomorrow',
        ));
      }
    }
    // Static fee reminder example
    reminders.add(const _Reminder(
      title: 'Fees Reminder',
      patientName: 'Neha Verma',
      description: 'Fees pending from last visit',
      statusLabel: '2 Days',
      statusColor: AppColors.primary,
      icon: Icons.account_balance_wallet_outlined,
      daysLabel: '2 Days',
    ));
    return reminders;
  }

  Widget _buildReminderCard(_Reminder r) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: r.statusColor, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: r.statusColor.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(r.icon, color: r.statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text(r.patientName, style: const TextStyle(fontSize: 13, color: AppColors.textMid)),
                const SizedBox(height: 4),
                Text(r.description, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: r.statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(r.daysLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: r.statusColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildViewAll() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('View All Reminders', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _Reminder {
  final String title;
  final String patientName;
  final String description;
  final String statusLabel;
  final Color statusColor;
  final IconData icon;
  final String daysLabel;
  const _Reminder({
    required this.title, required this.patientName, required this.description,
    required this.statusLabel, required this.statusColor, required this.icon, required this.daysLabel,
  });
}
