import 'package:flutter/material.dart';
import '../core/app_design.dart';
import '../core/models/patient.dart';
import '../screens/patient_detail_screen.dart';

class PatientStatusCard extends StatelessWidget {
  final Patient patient;
  final VoidCallback? onLongPress;
  const PatientStatusCard({super.key, required this.patient, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(patient.status);
    final statusBg = _getStatusBg(patient.status);
    final statusLabel = _getStatusLabel(patient.status);
    final statusIcon = _getStatusIcon(patient.status);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PatientDetailScreen(patient: patient),
        )),
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: statusBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: statusColor.withOpacity(0.4), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatar(),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          patient.phoneNumber,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildStatusPill(statusLabel, statusColor, statusIcon),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _infoRow('Issue', patient.healthIssue.isNotEmpty ? patient.healthIssue : 'Not specified'),
              const SizedBox(height: 6),
              Text(
                patient.notes.isNotEmpty ? patient.notes : 'Condition monitoring required. Patient to report any changes.',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF475569),
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              _infoRow('Last Update', _formatLastUpdate(patient.lastVisitDate)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: PatientAvatar(name: patient.name, size: 64, fontSize: 22),
      ),
    );
  }

  Widget _buildStatusPill(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
        children: [
          TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w800)),
          TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF475569))),
        ],
      ),
    );
  }

  String _formatLastUpdate(DateTime date) {
    final diff = DateTime.now().difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '$diff Days Ago';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'recovering': return const Color(0xFF22C55E); // Success Green
      case 'no_improvement': return const Color(0xFFEF4444); // Danger Red
      default: return const Color(0xFFF59E0B); // Warning Yellow
    }
  }

  Color _getStatusBg(String status) {
    switch (status) {
      case 'recovering': return const Color(0xFFF0FDF4);
      case 'no_improvement': return const Color(0xFFFEF2F2);
      default: return const Color(0xFFFFFBEB);
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'recovering': return 'Recovered (Green)';
      case 'no_improvement': return 'No Improvement (Red)';
      default: return 'Partial Improvement (Yellow)';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'recovering': return Icons.check_circle;
      case 'no_improvement': return Icons.error;
      default: return Icons.change_history;
    }
  }
}
