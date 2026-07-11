import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:call_log/call_log.dart';
import '../core/app_design.dart';
import '../core/providers/patient_provider.dart';
import '../core/models/patient.dart';
import 'patient_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<CallLogEntry> _missedCalls = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final entries = await CallLog.get();
      final patientNumbers = context.read<PatientProvider>().allPatients.map((p) => _normalize(p.phoneNumber)).toSet();
      
      setState(() {
        _missedCalls = entries.where((e) => 
          e.callType == CallType.missed && 
          e.number != null && 
          patientNumbers.contains(_normalize(e.number))
        ).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _normalize(String? phone) {
    if (phone == null) return '';
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Notifications', style: AppTextStyles.screenTitle),
      ),
      body: Consumer<PatientProvider>(
        builder: (context, provider, _) {
          final expiredPatients = provider.allPatients.where((p) => p.consultationStatus == 'Expired').toList();
          
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (expiredPatients.isEmpty && _missedCalls.isEmpty) {
            return _buildEmpty();
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (expiredPatients.isNotEmpty) ...[
                _buildHeader('Consultation Expired'),
                ...expiredPatients.map((p) => _buildExpiredTile(p)),
                const SizedBox(height: 24),
              ],
              if (_missedCalls.isNotEmpty) ...[
                _buildHeader('Missed Calls from Patients'),
                ..._missedCalls.map((e) => _buildMissedCallTile(e, provider.allPatients)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_off_outlined, size: 64, color: AppColors.textHint.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('No new notifications', style: TextStyle(color: AppColors.textLight, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMid)),
    );
  }

  Widget _buildExpiredTile(Patient p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.red.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.redLight, shape: BoxShape.circle),
          child: const Icon(Icons.timer_off_outlined, color: AppColors.red, size: 20),
        ),
        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: const Text('Consultation expired. Needs renewal.', style: TextStyle(fontSize: 12)),
        trailing: TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PatientDetailScreen(patient: p))),
          child: const Text('Review', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildMissedCallTile(CallLogEntry e, List<Patient> patients) {
    final patient = patients.cast<Patient?>().firstWhere(
      (p) => _normalize(p?.phoneNumber) == _normalize(e.number),
      orElse: () => null,
    );
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.yellow.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: Color(0xFFFEF3C7), shape: BoxShape.circle),
          child: const Icon(Icons.call_missed, color: Color(0xFFD97706), size: 20),
        ),
        title: Text(patient?.name ?? (e.name ?? e.number ?? 'Unknown'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('Missed call at ${_formatTime(e.timestamp ?? 0)}', style: const TextStyle(fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.call, color: AppColors.green, size: 20),
          onPressed: () {}, // Trigger call logic if needed
        ),
      ),
    );
  }

  String _formatTime(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
