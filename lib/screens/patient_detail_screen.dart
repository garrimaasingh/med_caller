import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_design.dart';
import '../core/models/patient.dart';
import '../core/providers/patient_provider.dart';
import 'add_edit_patient_screen.dart';
import 'patient_timeline_screen.dart';
import '../widgets/ai_patient_summary_sheet.dart';
import 'ai_live_call_screen.dart';

class PatientDetailScreen extends StatelessWidget {
  final Patient patient;
  const PatientDetailScreen({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    // Watch the patient from the provider to react to updates (like saved AI summaries)
    final pProvider = context.watch<PatientProvider>();
    final p = pProvider.allPatients.firstWhere((element) => element.id == patient.id, orElse: () => patient);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAppBar(context, p),
              _buildProfileCard(p),
              const SizedBox(height: 12),
              _buildStatusCard(p),
              if (p.aiSummary != null && p.aiSummary!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildAISummaryCard(context, p),
              ],
              const SizedBox(height: 12),
              _buildGridMenu(context, p),
              const SizedBox(height: 12),
              _buildDetailRows(p),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── App bar ──────────────────────────────────────────────────────────────────
  Widget _buildAppBar(BuildContext context, Patient p) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AddEditPatientScreen(patient: p),
            )),
            child: const Icon(Icons.edit_outlined, color: AppColors.textDark),
          ),
        ],
      ),
    );
  }

  // ── Profile card ─────────────────────────────────────────────────────────────
  Widget _buildProfileCard(Patient p) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        children: [
          PatientAvatar(name: p.name, size: 72, fontSize: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                const SizedBox(height: 4),
                Text(p.phoneNumber, style: const TextStyle(fontSize: 14, color: AppColors.textMid, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Text(
                  'Age: ${p.age > 0 ? p.age : "—"} Years  |  ${p.gender}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Status card ──────────────────────────────────────────────────────────────
  Widget _buildStatusCard(Patient p) {
    final color = statusColor(p.status);
    final bg = statusBgColor(p.status);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(p.statusLabel, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            p.healthIssue.isNotEmpty ? p.healthIssue : 'No issue recorded',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textDark),
          ),
          const SizedBox(height: 4),
          Text(
            p.notes.isNotEmpty ? p.notes : 'Condition improving. Continue medication.',
            style: const TextStyle(fontSize: 13, color: AppColors.textMid, height: 1.4),
            maxLines: 2, overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAISummaryCard(BuildContext context, Patient p) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt, color: Colors.amber, size: 18),
                  SizedBox(width: 8),
                  Text('Quick Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                ],
              ),
              GestureDetector(
                onTap: () => _confirmDeleteSummary(context, p),
                child: Icon(Icons.delete_outline, color: AppColors.red.withOpacity(0.5), size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(p.aiSummary!, style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.5)),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Text('AI Assessment', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Status', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                    const SizedBox(height: 4),
                    StatusPill(status: p.status),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Improvement', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                    const SizedBox(height: 4),
                    const Text('Available in AI Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSummary(BuildContext context, Patient p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete AI Summary?'),
        content: const Text('This will remove the generated summary from this patient\'s profile.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final updated = p.copyWith(aiSummary: '');
              await context.read<PatientProvider>().updatePatient(updated);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  // ── Grid menu ────────────────────────────────────────────────────────────────
  Widget _buildGridMenu(BuildContext context, Patient p) {
    final items = [
      _GridItem(Icons.timeline, 'Timeline', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PatientTimelineScreen(patient: p, initialTab: 'Timeline')))),
      _GridItem(Icons.receipt_long, 'Prescriptions', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PatientTimelineScreen(patient: p, initialTab: 'Prescriptions')))),
      _GridItem(Icons.bar_chart, 'Reports', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PatientTimelineScreen(patient: p, initialTab: 'Reports')))),
      _GridItem(Icons.auto_awesome, 'AI Summary', () => AIPatientSummarySheet.show(context, p)),
      _GridItem(Icons.call_outlined, 'AI Notes', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AILiveCallScreen(patient: p)))),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.1,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _buildGridTile(items[i]),
      ),
    );
  }

  Widget _buildGridTile(_GridItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: AppColors.primary, size: 26),
            const SizedBox(height: 8),
            Text(item.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMid), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ── Detail rows ──────────────────────────────────────────────────────────────
  Widget _buildDetailRows(Patient p) {
    final consultStatus = p.consultationStatus;
    Color consultColor = consultStatus == 'Expired' ? AppColors.red : (consultStatus == 'Expiring Soon' ? AppColors.yellow : AppColors.textDark);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          _detailRow('Last Visit', p.lastVisitDisplay),
          _divider(),
          _detailRow('Last Update', _daysSinceLastVisit(p)),
          _divider(),
          _detailRow('Next Follow-up', p.sinceWhen.isNotEmpty ? p.sinceWhen : '—'),
          _divider(),
          _detailRow('Consultation Valid Till', p.consultationValidTillDisplay, valueColor: consultColor),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.label),
          Text(value, style: AppTextStyles.value.copyWith(color: valueColor ?? AppColors.textDark)),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(color: AppColors.borderLight, height: 1);

  String _daysSinceLastVisit(Patient p) {
    final diff = DateTime.now().difference(p.lastVisitDate).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '$diff Days Ago';
  }
}

class _GridItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  _GridItem(this.icon, this.label, this.onTap);
}
