import 'package:flutter/material.dart';

/// App-wide design tokens matching the reference design
class AppColors {
  // Brand
  static const primary = Color(0xFF1A56DB); // Blue
  static const primaryLight = Color(0xFFE1EFFF);
  static const green = Color(0xFF16A34A);
  static const greenLight = Color(0xFFDCFCE7);
  static const greenBg = Color(0xFF22C55E);
  static const yellow = Color(0xFFCA8A04);
  static const yellowLight = Color(0xFFFEF9C3);
  static const yellowBorder = Color(0xFFFDE047);
  static const red = Color(0xFFDC2626);
  static const redLight = Color(0xFFFEE2E2);
  static const redBg = Color(0xFFEF4444);

  // Neutral
  static const bg = Color(0xFFF8FAFC);
  static const white = Colors.white;
  static const border = Color(0xFFE2E8F0);
  static const borderLight = Color(0xFFF1F5F9);
  static const textDark = Color(0xFF1E293B);
  static const textMid = Color(0xFF475569);
  static const textLight = Color(0xFF64748B);
  static const textHint = Color(0xFF94A3B8);
  static const divider = Color(0xFFE2E8F0);

  // Call screens
  static const callDarkBg = Color(0xFF1B2838);
  static const callGreenBg = Color(0xFF218C5E);
}

class AppTextStyles {
  static const screenTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );
  static const sectionTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );
  static const cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );
  static const cardSubtitle = TextStyle(
    fontSize: 13,
    color: AppColors.textLight,
  );
  static const label = TextStyle(
    fontSize: 12,
    color: AppColors.textLight,
    fontWeight: FontWeight.w500,
  );
  static const value = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
  );
  static const body = TextStyle(
    fontSize: 14,
    color: AppColors.textMid,
    height: 1.5,
  );
  static const hint = TextStyle(fontSize: 14, color: AppColors.textHint);
  static const chip = TextStyle(fontSize: 11, fontWeight: FontWeight.w600);
}

// ─── Status helpers ────────────────────────────────────────────────────────────

Color statusColor(String status) {
  switch (status) {
    case 'recovering':
      return AppColors.green;
    case 'no_improvement':
      return AppColors.red;
    default:
      return AppColors.yellow;
  }
}

Color statusBgColor(String status) {
  switch (status) {
    case 'recovering':
      return AppColors.greenLight;
    case 'no_improvement':
      return AppColors.redLight;
    default:
      return AppColors.yellowLight;
  }
}

String statusLabel(String status) {
  switch (status) {
    case 'recovering':
      return 'Recovered (Green)';
    case 'no_improvement':
      return 'No Improvement (Red)';
    default:
      return 'Partial Improvement (Yellow)';
  }
}

/// Pill widget used throughout the app
class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            statusLabel(status),
            style: AppTextStyles.chip.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Avatar widget
class PatientAvatar extends StatelessWidget {
  final String name;
  final double size;
  final double fontSize;
  const PatientAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF0EA5E9),
      const Color(0xFF8B5CF6),
      const Color(0xFF6366F1),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
    ];
    final idx = name.isNotEmpty ? name.codeUnitAt(0) % colors.length : 0;
    final initials = _initials(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors[idx],
        borderRadius: BorderRadius.circular(size * 0.35),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _initials(String n) {
    final p = n.trim().split(' ');
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return n.isNotEmpty ? n[0].toUpperCase() : '?';
  }
}
