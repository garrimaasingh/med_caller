import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_design.dart';
import '../core/models/patient.dart';
import '../core/services/ai_service.dart';
import '../core/providers/ai_settings.dart';
import '../core/providers/patient_provider.dart';

class AIPatientSummarySheet extends StatefulWidget {
  final Patient patient;
  const AIPatientSummarySheet({super.key, required this.patient});

  static Future<void> show(BuildContext context, Patient patient) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AIPatientSummarySheet(patient: patient),
    );
  }

  @override
  State<AIPatientSummarySheet> createState() => _AIPatientSummarySheetState();
}

class _AIPatientSummarySheetState extends State<AIPatientSummarySheet> {
  AISummaryResult? _result;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() { _loading = true; _error = null; });
    try {
      final settings = context.read<AiSettingsProvider>();
      final ai = AIService(settings);
      final p = widget.patient;
      final result = await ai.generatePatientSummary(
        patientName: p.name, healthIssue: p.healthIssue,
        symptoms: p.symptoms, medication: p.medication,
        notes: p.notes, sinceWhen: p.sinceWhen,
        age: p.age, gender: p.gender,
      );
      setState(() { _result = result; _loading = false; });
    } on AIException catch (e) {
      setState(() { _error = '${e.title}: ${e.details}'; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _save() async {
    if (_result == null) return;
    setState(() => _saving = true);
    try {
      final summaryText = _result!.quickSummary.join('\n');
      final updatedPatient = widget.patient.copyWith(aiSummary: summaryText);
      await context.read<PatientProvider>().updatePatient(updatedPatient);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Summary saved to profile')));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() { _error = 'Save failed: $e'; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75, minChildSize: 0.5, maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('AI Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                Text(widget.patient.name, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
              ])),
              _buildConnectionBadge(),
              if (!_loading)
                IconButton(icon: const Icon(Icons.refresh, color: AppColors.primary, size: 20), onPressed: _generate),
            ]),
          ),
          const Divider(height: 24, color: AppColors.borderLight),
          Expanded(child: _loading
              ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(color: AppColors.primary), SizedBox(height: 16),
                  Text('AI analyzing...', style: AppTextStyles.cardSubtitle),
                  SizedBox(height: 8),
                  Text('Using NVIDIA NIM API', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                ]))
              : _error != null
                  ? _buildError()
                  : _buildResult(_result!, ctrl)),
        ]),
      ),
    );
  }

  Widget _buildConnectionBadge() {
    final settings = context.watch<AiSettingsProvider>();
    final configured = settings.isConfigured;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: configured ? AppColors.greenLight : AppColors.redLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: configured ? AppColors.green : AppColors.red,
        )),
        const SizedBox(width: 4),
        Text(configured ? 'AI Online' : 'Offline',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
            color: configured ? AppColors.green : AppColors.red)),
      ]),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: AppColors.red, size: 48),
        const SizedBox(height: 12),
        const Text('Could not generate summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        const SizedBox(height: 8),
        Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.textLight), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton.icon(onPressed: _generate,
          icon: const Icon(Icons.refresh, size: 16), label: const Text('Retry'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white)),
      ]),
    );
  }

  Widget _buildResult(AISummaryResult r, ScrollController ctrl) {
    return ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [
      _card(color: AppColors.primaryLight, title: 'Quick Summary',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: r.quickSummary.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(margin: const EdgeInsets.only(top: 5), width: 6, height: 6,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(b, style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.4))),
            ]),
          )).toList())),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _miniCard('Status', StatusPill(status: r.suggestedStatus))),
        const SizedBox(width: 10),
        Expanded(child: _miniCard('Improvement', Text('${r.improvementPercent}%',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark)))),
      ]),
      const SizedBox(height: 12),
      _detailItem('Symptoms', r.detailedNotes['symptoms'] ?? ''),
      _detailItem('Medicines', r.detailedNotes['medicines'] ?? ''),
      _detailItem('Lifestyle', r.detailedNotes['lifestyle'] ?? ''),
      _detailItem('Mental State', r.detailedNotes['emotionalState'] ?? ''),
      _detailItem('Status', r.suggestedStatus),
      if (r.timelineEntry.isNotEmpty) ...[
        const SizedBox(height: 4),
        Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.greenBg.withOpacity(0.3))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.timeline, size: 16, color: AppColors.green), const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Timeline Entry', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green)),
              const SizedBox(height: 4),
              Text(r.timelineEntry, style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.4)),
            ])),
          ])),
      ],
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, height: 50,
        child: ElevatedButton.icon(onPressed: _saving ? null : _save,
          icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving...' : 'Save to Patient Profile'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
    ]);
  }

  Widget _card({required Color color, required String title, required Widget child}) {
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        const SizedBox(height: 10), child,
      ]));
  }

  Widget _miniCard(String label, Widget child) {
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6), child,
      ]));
  }

  Widget _detailItem(String label, String value) {
    return Padding(padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(label,
          style: const TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w600))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.4))),
      ]));
  }
}
