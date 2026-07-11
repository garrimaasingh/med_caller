import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_design.dart';
import '../core/models/patient.dart';
import '../core/providers/patient_provider.dart';

class AddEditPatientScreen extends StatefulWidget {
  final Patient? patient;
  final String? initialPhoneNumber;
  const AddEditPatientScreen({super.key, this.patient, this.initialPhoneNumber});

  @override
  State<AddEditPatientScreen> createState() => _AddEditPatientScreenState();
}

class _AddEditPatientScreenState extends State<AddEditPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _issueCtrl;
  late TextEditingController _sinceCtrl;
  late TextEditingController _symptomsCtrl;
  late TextEditingController _medsCtrl;
  late TextEditingController _allergiesCtrl;
  late TextEditingController _notesCtrl;
  String _gender = 'Male';
  String _status = 'improving';
  DateTime? _consultationValidTill;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.patient;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _phoneCtrl = TextEditingController(text: p?.phoneNumber ?? widget.initialPhoneNumber ?? '');
    _ageCtrl = TextEditingController(text: p?.age != null && p!.age > 0 ? p.age.toString() : '');
    _issueCtrl = TextEditingController(text: p?.healthIssue ?? '');
    _sinceCtrl = TextEditingController(text: p?.sinceWhen ?? '');
    _symptomsCtrl = TextEditingController(text: p?.symptoms ?? '');
    _medsCtrl = TextEditingController(text: p?.medication ?? '');
    _allergiesCtrl = TextEditingController(text: p?.allergies ?? 'None');
    _notesCtrl = TextEditingController(text: p?.notes ?? '');
    _gender = p?.gender ?? 'Male';
    _status = p?.status ?? 'improving';
    _consultationValidTill = p?.consultationValidTill;
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _ageCtrl.dispose();
    _issueCtrl.dispose(); _sinceCtrl.dispose(); _symptomsCtrl.dispose();
    _medsCtrl.dispose(); _allergiesCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final newPatient = Patient(
      id: widget.patient?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
      age: int.tryParse(_ageCtrl.text.trim()) ?? 0,
      gender: _gender,
      lastVisitDate: widget.patient?.lastVisitDate ?? DateTime.now(),
      healthIssue: _issueCtrl.text.trim(),
      sinceWhen: _sinceCtrl.text.trim(),
      symptoms: _symptomsCtrl.text.trim(),
      medication: _medsCtrl.text.trim(),
      allergies: _allergiesCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      isHighRisk: widget.patient?.isHighRisk ?? false,
      status: _status,
      consultationValidTill: _consultationValidTill,
    );

    try {
      final pp = context.read<PatientProvider>();
      if (widget.patient == null) {
        await pp.addPatient(newPatient);
      } else {
        await pp.updatePatient(newPatient);
      }
      if (mounted) {
        Navigator.pop(context, newPatient);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _pickConsultationDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _consultationValidTill ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date != null) setState(() => _consultationValidTill = date);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.patient != null;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isEdit ? 'Edit Patient' : 'Add / Update Record',
            style: const TextStyle(color: AppColors.textDark, fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [
          if (_isSaving)
            const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            IconButton(
              icon: const Icon(Icons.check, color: AppColors.primary),
              onPressed: _save,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('General Information'),
              const SizedBox(height: 12),
              _field(label: 'R. ${isEdit ? widget.patient!.name : 'Full Name'}', ctrl: _nameCtrl,
                hint: 'e.g. Rohit Sharma', validator: (v) => v!.isEmpty ? 'Enter name' : null),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _field(label: 'Age', ctrl: _ageCtrl, hint: '32', keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _genderField()),
              ]),
              const SizedBox(height: 12),
              _field(label: 'Phone Number', ctrl: _phoneCtrl, hint: '+91 98765 43210',
                keyboardType: TextInputType.phone, validator: (v) => v!.isEmpty ? 'Enter phone' : null),
              const SizedBox(height: 20),

              _sectionLabel('Health / Complaint'),
              const SizedBox(height: 12),
              _field(label: 'Health Issue / Complaint', ctrl: _issueCtrl, hint: 'Chronic Migraine',
                validator: (v) => v!.isEmpty ? 'Enter issue' : null),
              const SizedBox(height: 12),
              _field(label: 'Since When?', ctrl: _sinceCtrl, hint: '6 Months'),
              const SizedBox(height: 12),
              _field(label: 'Symptoms', ctrl: _symptomsCtrl,
                hint: 'Headache, Nausea, Irritability, Sleep disturbance', maxLines: 3),
              const SizedBox(height: 20),

              _sectionLabel('Medicine & Allergies'),
              const SizedBox(height: 12),
              _field(label: 'Medicine Currently Taking', ctrl: _medsCtrl, hint: 'Natrum Mur 200'),
              const SizedBox(height: 12),
              _field(label: 'Allergies (if any)', ctrl: _allergiesCtrl, hint: 'None'),
              const SizedBox(height: 20),

              _sectionLabel('Status & Consultation'),
              const SizedBox(height: 12),
              _statusSelector(),
              const SizedBox(height: 12),
              _consultationDateField(),
              const SizedBox(height: 20),

              _sectionLabel('Notes'),
              const SizedBox(height: 12),
              _field(label: 'Notes', ctrl: _notesCtrl,
                hint: 'Patient is sensitive to noise.', maxLines: 4),
              const SizedBox(height: 32),

              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textLight,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Edit & Save'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save to Record', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.3));

  Widget _field({
    required String label, required TextEditingController ctrl, String hint = '',
    int maxLines = 1, TextInputType? keyboardType, String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
          ),
        ),
      ],
    );
  }

  Widget _genderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Gender', style: TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: _gender,
          style: const TextStyle(fontSize: 14, color: AppColors.textDark),
          decoration: InputDecoration(
            filled: true, fillColor: AppColors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
          ),
          items: ['Male', 'Female', 'Other']
              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
              .toList(),
          onChanged: (v) => setState(() => _gender = v ?? 'Male'),
        ),
      ],
    );
  }

  Widget _statusSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Patient Status', style: TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [
            _statusOption('no_improvement', '🔴 No Improvement', AppColors.red),
            const SizedBox(width: 8),
            _statusOption('improving', '🟡 Improving', AppColors.yellow),
            const SizedBox(width: 8),
            _statusOption('recovering', '🟢 Recovered', AppColors.green),
          ],
        ),
      ],
    );
  }

  Widget _statusOption(String value, String label, Color color) {
    final selected = _status == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _status = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.1) : AppColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? color : AppColors.border, width: selected ? 1.5 : 1),
          ),
          child: Center(child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? color : AppColors.textLight), textAlign: TextAlign.center)),
        ),
      ),
    );
  }

  Widget _consultationDateField() {
    String display = _consultationValidTill != null
        ? '${_consultationValidTill!.day} / ${_consultationValidTill!.month} / ${_consultationValidTill!.year}'
        : 'Tap to set validity date';
    return GestureDetector(
      onTap: _pickConsultationDate,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Consultation Valid Till', style: TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.event, size: 18, color: AppColors.textLight),
                const SizedBox(width: 10),
                Text(display, style: TextStyle(
                  fontSize: 14,
                  color: _consultationValidTill != null ? AppColors.textDark : AppColors.textHint,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
