import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_design.dart';
import '../core/models/patient.dart';
import '../core/providers/patient_provider.dart';
import 'notification_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),
              _buildStatsGrid(context),
              const SizedBox(height: 20),
              _buildSectionTitle('Patient Status Overview'),
              const SizedBox(height: 12),
              _buildChartSection(context),
              const SizedBox(height: 20),
              _buildSectionTitle('Recent Activities'),
              const SizedBox(height: 12),
              _buildRecentActivities(context),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Dashboard', style: AppTextStyles.screenTitle),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  Text('This Week', style: TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w600)),
                  SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textLight),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _buildNotificationIcon(context),
          ]),
        ],
      ),
    );
  }

  Widget _buildNotificationIcon(BuildContext context) {
    return Consumer<PatientProvider>(
      builder: (context, pp, _) {
        final expiredCount = pp.allPatients.where((p) => p.consultationStatus == 'Expired').length;
        // For missed calls, we'd ideally have a provider, but for now we'll show just expired count
        // or a fixed badge if we want to simulate missed calls too.
        final totalNotifications = expiredCount; 

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationScreen()),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_outlined, color: AppColors.textDark, size: 28),
              if (totalNotifications > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$totalNotifications',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    return Consumer<PatientProvider>(
      builder: (context, pp, _) {
        final all = pp.allPatients;
        final total = all.length;
        final recovered = all.where((p) => p.status == 'recovering').length;
        final active = all.where((p) => p.status != 'recovering').length;
        final expiredConsultation = all.where((p) => p.consultationStatus == 'Expired').length;
        final followUpsDue = all.where((p) => p.consultationStatus == 'Expiring Soon' || p.consultationStatus == 'Expired').length;
        final callsThisWeek = all.where((p) => p.lastVisitDate.isAfter(DateTime.now().subtract(const Duration(days: 7)))).length;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.85,
            children: [
              _statCard(Icons.person_outline, AppColors.primary, 'Total Patients', '$total', AppColors.white, AppColors.textDark),
              _statCard(Icons.phone_outlined, AppColors.greenBg, 'Calls This Week', '$callsThisWeek', AppColors.white, AppColors.textDark),
              _statCard(Icons.calendar_today_outlined, const Color(0xFFF59E0B), 'Follow-ups Due', '$followUpsDue', const Color(0xFFFEF3C7), AppColors.textDark, borderColor: const Color(0xFFFDE68A)),
              _statCard(Icons.restore_outlined, AppColors.redBg, 'Consultations Expired', '$expiredConsultation', AppColors.redLight, AppColors.textDark, borderColor: const Color(0xFFFCA5A5)),
              _statCard(Icons.health_and_safety_outlined, AppColors.greenBg, 'Recovered Patients', '$recovered', AppColors.greenLight, AppColors.green, borderColor: const Color(0xFFBBF7D0)),
              _statCard(Icons.medical_services_outlined, AppColors.primary, 'Active Treatments', '$active', AppColors.white, AppColors.textDark),
            ],
          ),
        );
      },
    );
  }

  Widget _statCard(IconData icon, Color iconColor, String label, String value, Color bg, Color valueColor, {Color? borderColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? AppColors.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textLight, height: 1.2)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(title, style: AppTextStyles.sectionTitle),
    );
  }

  Widget _buildChartSection(BuildContext context) {
    return Consumer<PatientProvider>(
      builder: (context, pp, _) {
        final all = pp.allPatients;
        final total = all.length > 0 ? all.length : 1;
        final noImprovement = all.where((p) => p.status == 'no_improvement').length;
        final improving = all.where((p) => p.status == 'improving').length;
        final recovered = all.where((p) => p.status == 'recovering').length;
        final noImpPct = (noImprovement / total * 100).round();
        final impPct = (improving / total * 100).round();
        final recPct = (recovered / total * 100).round();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Row(
            children: [
                SizedBox(
                  width: 100, height: 100,
                  child: CustomPaint(
                    painter: _PieChartPainter(
                      noImprovement.toDouble(),
                      improving.toDouble(),
                      recovered.toDouble(),
                    ),
                  ),
                ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendItem(AppColors.red, 'No Improvement (Red)', '$noImprovement ($noImpPct%)'),
                    const SizedBox(height: 10),
                    _legendItem(AppColors.yellow, 'Partial Improvement (Yellow)', '$improving ($impPct%)'),
                    const SizedBox(height: 10),
                    _legendItem(AppColors.green, 'Recovered (Green)', '$recovered ($recPct%)'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _legendItem(Color color, String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        Text(value, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
      ]),
    ]);
  }

  Widget _buildRecentActivities(BuildContext context) {
    return Consumer<PatientProvider>(
      builder: (context, pp, _) {
        final sorted = List<Patient>.from(pp.allPatients)
          ..sort((a, b) => b.lastVisitDate.compareTo(a.lastVisitDate));
        final recent = sorted.take(3).toList();
        if (recent.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: const Text('No recent activity', style: AppTextStyles.cardSubtitle),
            ),
          );
        }
        return Column(
          children: recent.map((p) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Row(
                children: [
                  PatientAvatar(name: p.name, size: 40, fontSize: 14),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                      const SizedBox(height: 2),
                      const Text('Call received & record updated', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                    ]),
                  ),
                  Text(p.lastVisitDisplay, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                ],
              ),
            ),
          )).toList(),
        );
      },
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final double noImp;
  final double imp;
  final double rec;

  _PieChartPainter(this.noImp, this.imp, this.rec);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final total = noImp + imp + rec;

    if (total == 0) {
      final paint = Paint()..color = const Color(0xFFE2E8F0)..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, paint);
      final innerPaint = Paint()..color = AppColors.bg..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius - 16, innerPaint);
      return;
    }

    double startAngle = -3.14159 / 2;

    void drawSegment(double value, Color color) {
      if (value <= 0) return;
      final sweepAngle = (value / total) * 3.14159 * 2;
      final paint = Paint()..color = color..style = PaintingStyle.fill;
      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
      startAngle += sweepAngle;
    }

    drawSegment(noImp, AppColors.red);
    drawSegment(imp, AppColors.yellow);
    drawSegment(rec, AppColors.green);

    final innerPaint = Paint()..color = AppColors.bg..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 16, innerPaint);
  }

  @override
  bool shouldRepaint(_PieChartPainter oldDelegate) {
    return oldDelegate.noImp != noImp ||
           oldDelegate.imp != imp ||
           oldDelegate.rec != rec;
  }
}
