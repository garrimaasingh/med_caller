import 'package:flutter/material.dart';

class AIQuickSummaryCard extends StatelessWidget {
  final List<String> summaries;
  final EdgeInsetsGeometry padding;

  const AIQuickSummaryCard({
    super.key,
    required this.summaries,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: const [
              Icon(Icons.auto_awesome, size: 16, color: Color(0xFF218C5E)),
              SizedBox(width: 8),
              Text(
                'AI Quick Summary',
                style: TextStyle(
                  color: Color(0xFF218C5E),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...summaries.map((text) => _aiBullet(text)).toList(),
        ],
      ),
    );
  }

  Widget _aiBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Color(0xFF218C5E), fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
            ),
          ),
        ],
      ),
    );
  }
}
