import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_design.dart';
import '../core/models/patient.dart';
import '../core/providers/patient_provider.dart';
import 'add_edit_patient_screen.dart';

class PatientTimelineScreen extends StatefulWidget {
  final Patient patient;
  final String initialTab;
  const PatientTimelineScreen({super.key, required this.patient, this.initialTab = 'Timeline'});
  @override
  State<PatientTimelineScreen> createState() => _PatientTimelineScreenState();
}

class _PatientTimelineScreenState extends State<PatientTimelineScreen> {
  late String _activeTab;
  final _tabs = ['Timeline', 'Prescriptions', 'Reports'];
  late Patient _p;

  @override
  void initState() {
    super.initState();
    _p = widget.patient;
    _activeTab = widget.initialTab == 'Notes' ? 'Timeline' : widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Consumer<PatientProvider>(
          builder: (context, provider, _) {
            // Update local patient instance from provider
            _p = provider.allPatients.firstWhere((p) => p.id == _p.id, orElse: () => _p);
            
            return Column(
              children: [
                _buildAppBar(context),
                _buildTabs(),
                const Divider(height: 1, color: AppColors.border),
                Expanded(
                  child: _buildContentForTab(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textDark), onPressed: () => Navigator.pop(context)),
          const Spacer(),
          Text(_p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          const Spacer(),
          _buildActionIcon(context),
        ],
      ),
    );
  }

  Widget _buildActionIcon(BuildContext context) {
    if (_activeTab == 'Reports') {
      return GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AddEditPatientScreen(patient: _p),
        )),
        child: const Icon(Icons.edit_outlined, color: AppColors.textDark),
      );
    }

    return GestureDetector(
      onTap: () {
        if (_activeTab == 'Timeline') _showAddEventDialog();
        if (_activeTab == 'Prescriptions') _showAddPrescriptionDialog();
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
        child: const Icon(Icons.add, color: Colors.white, size: 20),
      ),
    );
  }

  void _showAddEventDialog() {
    final descController = TextEditingController();
    final statusController = TextEditingController(text: 'improving');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Timeline Entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: descController, decoration: const InputDecoration(hintText: 'Describe update...')),
            const SizedBox(height: 12),
            const Text('Status:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: statusController.text,
              items: const [
                DropdownMenuItem(value: 'recovering', child: Text('Recovered')),
                DropdownMenuItem(value: 'improving', child: Text('Improving')),
                DropdownMenuItem(value: 'no_improvement', child: Text('No Improvement')),
              ],
              onChanged: (v) => setState(() => statusController.text = v!),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (descController.text.isEmpty) return;
              await context.read<PatientProvider>().addTimelineEvent(_p.phoneNumber, {
                'type': 'manual_update',
                'description': descController.text,
                'condition': statusController.text,
                'timestamp': DateTime.now(),
              });
              // Also update patient status
              await context.read<PatientProvider>().updatePatient(_p.copyWith(status: statusController.text));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddPrescriptionDialog() {
    final medController = TextEditingController();
    final doseController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Prescription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: medController, decoration: const InputDecoration(hintText: 'Medicine Name')),
            const SizedBox(height: 12),
            TextField(controller: doseController, decoration: const InputDecoration(hintText: 'Dosage (e.g. 1 dose weekly)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (medController.text.isEmpty) return;
              await context.read<PatientProvider>().addTimelineEvent(_p.phoneNumber, {
                'type': 'prescription',
                'title': medController.text,
                'description': 'Prescribed: ${medController.text}',
                'treatment': doseController.text,
                'timestamp': DateTime.now(),
              });
              // Update current medication in patient profile
              await context.read<PatientProvider>().updatePatient(_p.copyWith(medication: medController.text));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _tabs.map((t) {
          final selected = _activeTab == t;
          return GestureDetector(
            onTap: () => setState(() => _activeTab = t),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Text(t, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.greenBg : AppColors.textLight)),
                ),
                if (selected)
                  Container(height: 2.5, width: 40, color: AppColors.greenBg, margin: const EdgeInsets.only(bottom: 2))
                else
                  const SizedBox(height: 4.5),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimeline() {
    return Consumer<PatientProvider>(
      builder: (context, provider, _) {
        return StreamBuilder(
          stream: provider.getTimelineStream(widget.patient.phoneNumber),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || (snapshot.data as dynamic).docs.isEmpty) {
              return _buildEmptyTimeline();
            }

            final docs = (snapshot.data as dynamic).docs;
            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final eventWithId = {...data, 'id': docs[index].id};
                return _buildRealEvent(eventWithId, isLast: index == docs.length - 1);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyTimeline() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 48, color: AppColors.textHint.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('No timeline entries yet', style: TextStyle(color: AppColors.textLight)),
          const SizedBox(height: 4),
          const Text('Save AI notes to see updates here', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildRealEvent(Map<String, dynamic> data, {required bool isLast}) {
    final timestamp = data['timestamp'] as dynamic;
    DateTime date = DateTime.now();
    if (timestamp != null) {
      date = timestamp.toDate();
    }
    
    final status = data['condition']?.toString() ?? 'improving';
    final color = _getStatusColor(status);
    final dateStr = '${date.day} ${_getMonth(date.month)} ${date.year}';

    return GestureDetector(
      onLongPress: () => _confirmDeleteEvent(data['id']),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: AppColors.border)),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(dateStr, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                        const SizedBox(width: 6),
                        Text(data['type'] == 'ai_consultation' ? '(AI Consult)' : '', style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                        const Spacer(),
                        IconButton(
                          onPressed: () => _confirmDeleteEvent(data['id']),
                          icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.red),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(data['description'] ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textMid, height: 1.5)),
                    if (data['treatment'] != null && data['treatment'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8)),
                        child: Text('Plan: ${data['treatment']}', style: const TextStyle(fontSize: 12, color: AppColors.textDark)),
                      ),
                    ],
                    if (data['detailed_history'] != null) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => _showDetailedHistory(data['detailed_history']),
                        icon: const Icon(Icons.description_outlined, size: 16, color: AppColors.primary),
                        label: const Text('View Detailed Case Study', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteEvent(String eventId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: const Text('Are you sure you want to remove this record from the history?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await context.read<PatientProvider>().deleteTimelineEvent(_p.phoneNumber, eventId);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  void _showDetailedHistory(Map<String, dynamic> historyJson) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.primary),
                  const SizedBox(width: 12),
                  const Text('Detailed Clinical History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(height: 32),
              _renderHistorySection('Basic Info', historyJson['basic_info']),
              _renderHistorySection('Medical History', historyJson['medical_history']),
              _renderHistorySection('Lifestyle', historyJson['lifestyle']),
              _renderHistorySection('Mental & Emotional', historyJson['mental_emotional_state']),
              _renderHistorySection('Family History', historyJson['family_history']),
              _renderHistorySection('Physical Tendencies', historyJson['physical_tendencies']),
              if (historyJson['timeline'] != null && (historyJson['timeline'] as List).isNotEmpty)
                _renderHistorySection('Historical Timeline', {'Events': (historyJson['timeline'] as List).join('\n• ')}),
              _renderHistorySection('Risk & Follow-up', {
                'Risk Level': historyJson['risk_level']?.toString().toUpperCase(),
                'Follow-up Required': historyJson['follow_up_required'] == true ? 'Yes' : 'No',
              }),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _renderHistorySection(String title, dynamic data) {
    if (data == null) return const SizedBox();
    Map<String, dynamic> fields = {};
    if (data is Map) {
      fields = data.cast<String, dynamic>();
    } else {
      return const SizedBox();
    }

    final validFields = fields.entries.where((e) => e.value != null && e.value.toString().isNotEmpty && e.value.toString().toLowerCase() != 'null').toList();
    if (validFields.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
        const SizedBox(height: 12),
        ...validFields.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 130, child: Text(_formatKey(e.key), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textLight))),
              Expanded(child: Text(e.value is List ? (e.value as List).join(', ') : e.value.toString(), style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.4))),
            ],
          ),
        )),
        const Divider(height: 24, color: AppColors.borderLight),
      ],
    );
  }

  String _formatKey(String key) {
    return key.split('_').map((s) => s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1)).join(' ');
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'recovering': return AppColors.greenBg;
      case 'no_improvement': return AppColors.redBg;
      default: return const Color(0xFFF59E0B);
    }
  }

  String _getMonth(int m) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[m - 1];
  }

  Widget _buildEvent(_TimelineEvent e, {required bool isLast}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 14, height: 14,
                decoration: BoxDecoration(color: e.color, shape: BoxShape.circle),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: AppColors.border)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(e.dateLabel, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: e.color)),
                    const SizedBox(width: 6),
                    Text(e.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                  ]),
                  const SizedBox(height: 6),
                  Text(e.description, style: const TextStyle(fontSize: 13, color: AppColors.textMid, height: 1.5)),
                  if (e.medicine != null) ...[
                    const SizedBox(height: 6),
                    Text('Medicine: ${e.medicine!}', style: const TextStyle(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w600)),
                  ],
                  if (e.improvement != null) ...[
                    const SizedBox(height: 6),
                    Text('Improvement: ${e.improvement!}', style: const TextStyle(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_TimelineEvent> _sampleTimeline() {
    return [
      _TimelineEvent(
        dateLabel: '12 Apr 2024',
        subtitle: '(Last Visit)',
        description: 'Severe headache, sleep disturbance, irritability, nausea.',
        medicine: 'Natrum Mur 200\n1 dose weekly',
        color: AppColors.redBg,
      ),
      _TimelineEvent(
        dateLabel: '22 Apr 2024',
        subtitle: '(Follow-up Call)',
        description: 'Headache reduced. Sleep slightly better. Nausea reduced.\nContinue same medicine',
        color: const Color(0xFFF59E0B),
      ),
      _TimelineEvent(
        dateLabel: '28 Apr 2024',
        subtitle: '(Call Update)',
        description: 'Headache much better. Mild dizziness sometimes.',
        medicine: 'Natrum Mur 1M\nSingle dose',
        color: AppColors.greenBg,
      ),
      _TimelineEvent(
        dateLabel: '04 May 2024',
        subtitle: '(Call)',
        description: 'Headache very rare now. Feeling better overall.',
        improvement: '60%',
        color: AppColors.greenBg,
      ),
      _TimelineEvent(
        dateLabel: '10 May 2024',
        subtitle: '(Today)',
        description: 'Mild headache only in stress. Overall improvement.',
        improvement: '80%',
        color: AppColors.greenBg,
      ),
    ];
  }

  Widget _buildContentForTab() {
    switch (_activeTab) {
      case 'Timeline': return _buildTimeline();
      case 'Prescriptions': return _buildPrescriptions();
      case 'Reports': return _buildReports();
      default: return _buildComingSoon();
    }
  }

  Widget _buildNotes() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildNoteCard('General Observation', 'Patient seems to be responding well to the current dosage. Needs to follow up in 2 months. avoid cold water.'),
        _buildNoteCard('Dietary Restrictions', 'Advised to avoid coffee, raw onion, and strong smelling items during the course of medication.'),
      ],
    );
  }

  Widget _buildNoteCard(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark, fontSize: 14)),
              const Icon(Icons.edit_note, color: AppColors.textLight, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(color: AppColors.textMid, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildPrescriptions() {
    return Consumer<PatientProvider>(
      builder: (context, provider, _) {
        return StreamBuilder(
          stream: provider.getTimelineStream(_p.phoneNumber),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData) return const SizedBox();

            final docs = (snapshot.data as dynamic).docs;
            final prescriptions = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['type'] == 'prescription' || (data['treatment'] != null && data['treatment'].toString().isNotEmpty);
            }).toList();

            if (prescriptions.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long, size: 48, color: AppColors.textHint.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    const Text('No prescriptions found', style: TextStyle(color: AppColors.textLight)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: prescriptions.length,
              itemBuilder: (context, index) {
                final doc = prescriptions[index];
                final data = doc.data() as Map<String, dynamic>;
                final timestamp = data['timestamp'] as dynamic;
                DateTime date = DateTime.now();
                if (timestamp != null) date = timestamp.toDate();
                final dateStr = '${date.day} ${_getMonth(date.month)} ${date.year}';

                return _buildPrescriptionCard(
                  dateStr, 
                  data['title'] ?? data['description'] ?? 'Medicine', 
                  data['treatment'] ?? 'No dosage info',
                  doc.id,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPrescriptionCard(String date, String med, String dosage, String eventId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4), 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long, color: AppColors.greenBg, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(med, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.greenBg, fontSize: 15)),
                const SizedBox(height: 4),
                Text(dosage, style: const TextStyle(color: AppColors.textDark, fontSize: 13)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(date, style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
              IconButton(
                onPressed: () => _confirmDeleteEvent(eventId),
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.red),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReports() {
    if (_p.reports.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.folder_open, size: 48, color: AppColors.textHint),
          const SizedBox(height: 12),
          const Text('No reports uploaded yet', style: TextStyle(color: AppColors.textLight, fontSize: 14)),
          const SizedBox(height: 16),
          _uploadButton(),
        ]),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_p.reports.length} Reports Found', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textLight)),
              _uploadButton(mini: true),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _p.reports.length,
            itemBuilder: (context, index) {
              final report = _p.reports[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, color: AppColors.red, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(report['name'] ?? 'Medical Report', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark)),
                          const SizedBox(height: 4),
                          Text(report['date'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                        ],
                      ),
                    ),
                    const Icon(Icons.download_outlined, color: AppColors.primary),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _uploadButton({bool mini = false}) {
    return ElevatedButton.icon(
      onPressed: _showUploadDialog,
      icon: Icon(Icons.upload_file, size: mini ? 14 : 16),
      label: Text(mini ? 'Add' : 'Upload Report'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary, 
        foregroundColor: Colors.white,
        padding: mini ? const EdgeInsets.symmetric(horizontal: 12, vertical: 0) : null,
      ),
    );
  }

  void _showUploadDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Medical Report'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Report Name (e.g. Blood Test)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              final newReports = List<Map<String, String>>.from(_p.reports);
              newReports.add({
                'name': nameController.text,
                'date': '${DateTime.now().day} ${_getMonth(DateTime.now().month)} ${DateTime.now().year}',
                'url': 'mock_url',
              });
              final updated = _p.copyWith(reports: newReports);
              await context.read<PatientProvider>().updatePatient(updated);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add Report'),
          ),
        ],
      ),
    );
  }

  Widget _buildComingSoon() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.construction, size: 48, color: AppColors.textHint),
        const SizedBox(height: 12),
        Text('$_activeTab coming soon', style: AppTextStyles.cardSubtitle),
      ]),
    );
  }
}

class _TimelineEvent {
  final String dateLabel;
  final String subtitle;
  final String description;
  final String? medicine;
  final String? improvement;
  final Color color;
  const _TimelineEvent({required this.dateLabel, required this.subtitle, required this.description, this.medicine, this.improvement, required this.color});
}
